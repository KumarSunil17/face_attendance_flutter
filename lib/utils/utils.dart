import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

imglib.Image convertToImage(CameraImage image) {
  if (image.format.group == ImageFormatGroup.yuv420) {
    // if (image.planes.length == 2) {
    //   return convertYUV420ToImage(image);
    // }
    return _convertYUV420(image);
  } else if (image.format.group == ImageFormatGroup.bgra8888) {
    return _convertBGRA8888(image);
  } else if (image.format.group == ImageFormatGroup.jpeg) {
    return imglib.decodeJpg(image.planes.first.bytes)!;
  }
  throw Exception('Image format not supported ${image.format.group}');
}

imglib.Image _convertBGRA8888(CameraImage image) {
  return imglib.Image.fromBytes(
    bytes: image.planes[0].bytes.buffer,
    width: image.width,
    height: image.height,
    order: imglib.ChannelOrder.bgra,
    bytesOffset: 28,
    rowStride: image.planes[0].bytesPerRow,
  );
}

typedef HandleDetection = Future<List<Face>> Function(InputImage image);

enum Choice { view, delete }

Future<CameraDescription> getCamera(CameraLensDirection dir) async {
  return await availableCameras().then(
    (List<CameraDescription> cameras) => cameras.firstWhere(
      (CameraDescription camera) => camera.lensDirection == dir,
    ),
  );
}

InputImageMetadata buildMetaData(
  CameraImage image,
  InputImageRotation rotation,
) {
  return InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    format: InputImageFormat.yuv420,
    bytesPerRow: image.planes.first.bytesPerRow,

    // planeData: image.planes.map(
    //   (Plane plane) {
    //     return InputImagePlaneMetadata(
    //       bytesPerRow: plane.bytesPerRow,
    //       height: plane.height,
    //       width: plane.width,
    //     );
    //   },
    // ).toList(),
  );
}

Future<List<Face>> detect(
  CameraImage image,
  HandleDetection handleDetection,
  InputImageRotation rotation,
) async {
  return handleDetection(
    InputImage.fromBytes(
      // bytes: image.planes[0].bytes,
      bytes: Uint8List.fromList(
        image.planes.fold(
          <int>[],
          (List<int> previousValue, element) =>
              previousValue..addAll(element.bytes),
        ),
      ),
      metadata: buildMetaData(image, rotation),
    ),
  );
}

InputImageRotation rotationIntToImageRotation(int rotation) {
  switch (rotation) {
    case 0:
      return InputImageRotation.rotation0deg;
    case 90:
      return InputImageRotation.rotation90deg;
    case 180:
      return InputImageRotation.rotation180deg;
    default:
      assert(rotation == 270);
      return InputImageRotation.rotation270deg;
  }
}

imglib.Image convertYUV420ToImage(CameraImage cameraImage) {
  final height = cameraImage.height;
  final width = cameraImage.height;
  final image = imglib.Image(width: width, height: height);
  Uint8List yPlane = cameraImage.planes[0].bytes;
  Uint8List uvPlane = cameraImage.planes[1].bytes;

  // Iterate over each pixel
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Get the Y value
      int yIndex = y * width + x;
      int Y = yPlane[yIndex];

      // Get the UV values (subsampled by 2)
      int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2) * 2;
      int U = uvPlane[uvIndex] - 128; // U component
      int V = uvPlane[uvIndex + 1] - 128; // V component

      // Convert YUV to RGB
      int R = (Y + 1.402 * V).clamp(0, 255).toInt();
      int G = (Y - 0.344136 * U - 0.714136 * V).clamp(0, 255).toInt();
      int B = (Y + 1.772 * U).clamp(0, 255).toInt();

      // Set the pixel in the image
      image.setPixel(x, y, imglib.ColorRgb8(R, G, B));
    }
  }

  return image;
}

imglib.Image _convertYUV420(CameraImage image) {
  final uvRowStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel ?? 0;
  final img = imglib.Image(width: image.width, height: image.height);
  for (final p in img) {
    final x = p.x;
    final y = p.y;
    final uvIndex =
        uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
    final index =
        y * uvRowStride +
        x; // Use the row stride instead of the image width as some devices pad the image data, and in those cases the image width != bytesPerRow. Using width will give you a distored image.
    final yp = image.planes[0].bytes[index];
    final up = image.planes[1].bytes[uvIndex];
    final vp =
        image.planes.length > 2
            ? image.planes[2].bytes[uvIndex]
            : image.planes[1].bytes[uvIndex];
    p.r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255).toInt();
    p.g =
        (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255)
            .toInt();
    p.b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255).toInt();
  }

  return img;
}
