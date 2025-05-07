import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as imglib;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class LocalFaceProcessor {
  static Future<List> extractFaceFromImage(String filePath) async {
    final tfl.Interpreter interpreter = await tfl.Interpreter.fromAsset(
      'assets/tf_models/mobilefacenet.tflite',
    );
    try {
      if (filePath.isNotEmpty &&
          (filePath.endsWith('png') ||
              filePath.endsWith('jpg') ||
              filePath.endsWith('jpeg'))) {
        // if(file.lengthSync()<=2048) {

        FaceDetector faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: true,
            enableClassification: true,
            enableTracking: true,
            enableLandmarks: true,
            performanceMode: FaceDetectorMode.fast,
          ),
        );
        final res = await faceDetector.processImage(
          InputImage.fromFilePath(filePath),
        );
        if (res.isNotEmpty) {
          Face _face = res[0];
          double x, y, w, h;
          x = (_face.boundingBox.left - 10);
          y = (_face.boundingBox.top - 10);
          w = (_face.boundingBox.width + 10);
          h = (_face.boundingBox.height + 10);

          imglib.Image? img =
              (filePath).endsWith('png') == true
                  ? await imglib.decodePngFile(filePath)
                  : await imglib.decodeJpgFile(filePath);

          if (img == null) return [];
          imglib.Image croppedImage = imglib.copyCrop(
            img!,
            x: x.round(),
            y: y.round(),
            width: w.round(),
            height: h.round(),
          );
          croppedImage = imglib.copyResizeCropSquare(croppedImage, size: 112);

          List input = imageToByteListFloat32(croppedImage, 112, 128, 128);
          input = input.reshape([1, 112, 112, 3]);
          List output = List.filled(
            1 * 192,
            null,
            growable: true,
          ).reshape([1, 192]);
          interpreter.run(input, output);
          return output.reshape([192]);
        }
        // }
      }
      return [];
    } catch (e) {
      print("EXTRACT_ERROR $e");
      return [];
    } finally {
      interpreter.close();
    }
  }

  static Float32List imageToByteListFloat32(
    imglib.Image image,
    int inputSize,
    double mean,
    double std,
  ) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - mean) / std;
        buffer[pixelIndex++] = (pixel.g - mean) / std;
        buffer[pixelIndex++] = (pixel.b - mean) / std;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  static double euclideanDistance(List e1, List e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += math.pow((e1[i] - e2[i]), 2);
    }
    return math.sqrt(sum);
  }

  static Future<String> downloadImageToCache(String url, {String? id}) async {
    final ext = url.split(".").last;
    final dir = await getApplicationCacheDirectory();
    final userImageDir = Directory(
      "${dir.path}${Platform.pathSeparator}userImages",
    );
    if (!(await userImageDir.exists())) {
      await userImageDir.create(recursive: true);
    }
    final imageName =
        id == null
            ? "${DateTime.now().microsecondsSinceEpoch}.$ext"
            : "$id.$ext";
    final imageFile = File(
      userImageDir.path + Platform.pathSeparator + imageName,
    );

    final response = await http.get(Uri.parse(url));
    await imageFile.writeAsBytes(response.bodyBytes);
    return imageFile.path;
  }
}
