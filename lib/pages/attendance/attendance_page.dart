import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_attendance_flutter/pages/attendance/widgets/detector_painters.dart';
import 'package:face_attendance_flutter/utils/local_face_processor.dart';
import 'package:face_attendance_flutter/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as imglib;
import 'dart:async';

class AttendancePage extends StatefulWidget {
  static const routeName = "/attendance";

  final Map<String, dynamic> args;

  const AttendancePage(this.args, {super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Map<String, dynamic>> initialUsers = [];

  /// Camera controller to manage Camera view
  CameraController? camera;

  /// Current camera direction
  CameraLensDirection _direction = CameraLensDirection.front;

  /// TFLite interpreter to run tflite file for face detection process
  tfl.Interpreter? interpreter;

  /// Controls if the face detection is processing from current camera image frame
  bool _isDetecting = false;

  /// Face matching threshold
  double threshold = 1.0;

  /// Message to show in UI if face found or unknown
  String promptMessage = "";

  /// User found from face detection
  Map<String, dynamic>? selectedUser;

  /// Face data from face detection
  Face? selectedFace;

  /// blink count
  int countbling = 0;

  /// is eye open or closed
  bool isopen = false;
  Uint8List? memoryImage;
  FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> args = widget.args;
    initialUsers = args["initialUsers"];
    initialize();
  }

  void initialize() async {
    try {
      interpreter = await tfl.Interpreter.fromAsset(
        'assets/tf_models/mobilefacenet.tflite',
      );
      initializeCamera();
    } on Exception {
      print('Failed to load model.');
    }
  }

  @override
  void dispose() {
    // camera?.stopImageStream();
    camera?.dispose();
    initialUsers = [];
    faceDetector.close();
    // interpreter?.close();
    super.dispose();
  }

  Map<String, dynamic>? _recog(imglib.Image img) {
    List input = LocalFaceProcessor.imageToByteListFloat32(img, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);
    List output = List.filled(1 * 192, null, growable: true).reshape([1, 192]);

    interpreter?.run(input, output);
    output = output.reshape([192]);

    return compare(List.from(output));
  }

  Map<String, dynamic>? compare(List currEmb) {
    double minDist = 999;
    double currDist = 0.0;

    int index = -1;
    for (int i = 0; i < initialUsers.length; i++) {
      currDist = LocalFaceProcessor.euclideanDistance(
        initialUsers[i]["avatarBytes"],
        currEmb,
      );
      log(
        "MATCHING ${initialUsers[i]["avatarBytes"].length} ${currEmb.length} $currDist",
      );
      if (currDist < threshold) {
        minDist = currDist;
        index = i;
      }
    }
    if (index != -1) {
      return initialUsers[index];
    }

    return null;
  }

  imglib.Image _convertCameraImage(CameraImage image, CameraLensDirection dir) {
    int width = image.width;
    int height = image.height;
    var img = convertToImage(image);
    if (Platform.isAndroid) {
      return (dir == CameraLensDirection.front)
          ? imglib.copyRotate(img, angle: -90)
          : imglib.copyRotate(img, angle: 90);
    }
    memoryImage = imglib.encodePng(img) as Uint8List?;

    return img;
  }

  void initializeCamera() async {
    CameraDescription description = await getCamera(_direction);

    InputImageRotation rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );

    camera = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await camera?.initialize();
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});

    camera?.startImageStream((CameraImage image) {
      if (camera != null) {
        if (_isDetecting) return;
        _isDetecting = true;
        detect(image, faceDetector.processImage, rotation)
            .then((List<Face> result) async {
              if (result.isNotEmpty) {
                Face face = result[0];
                selectedFace = face;
                double x, y, w, h;
                x = (face.boundingBox.left - 10);
                y = (face.boundingBox.top - 10);
                w = (face.boundingBox.width + 10);
                h = (face.boundingBox.height + 10);
                double? leftEyeOpenProbability = face.leftEyeOpenProbability;
                double? rightEyeOpenProbability = face.rightEyeOpenProbability;
                if (leftEyeOpenProbability != null &&
                    rightEyeOpenProbability != null) {
                  if (leftEyeOpenProbability < 0.5 &&
                      rightEyeOpenProbability < 0.5) {
                    if (isopen) {
                      countbling++;
                      isopen = false;
                    }
                  } else {
                    if (!isopen) {
                      countbling++;
                      isopen = true;
                    }
                  }
                }
                if (countbling > 1) {
                  promptMessage = "Processing...";
                  if (mounted) setState(() {});
                  imglib.Image convertedImage = _convertCameraImage(
                    image,
                    _direction,
                  );
                  imglib.Image croppedImage = imglib.copyCrop(
                    convertedImage,
                    x: x.round(),
                    y: y.round(),
                    width: w.round(),
                    height: h.round(),
                  );
                  croppedImage = imglib.copyResizeCropSquare(
                    croppedImage,
                    size: 112,
                  );
                  selectedUser = _recog(croppedImage);
                  if (selectedUser != null) {
                    promptMessage = selectedUser!["name"] ?? "user";
                    setState(() {});
                    camera?.stopImageStream();
                    Future.delayed(Duration(seconds: 2)).then(
                      (_) => Navigator.pop(context, selectedUser?["user_id"]),
                    );
                  } else {
                    promptMessage = "Unknown";
                    if (mounted) setState(() {});
                    camera?.stopImageStream();
                  }
                } else {
                  promptMessage = "Blink your eyes";
                  if (mounted) setState(() {});
                }
                if (mounted) setState(() {});
              }
            })
            .catchError((e, s) {
              log("DETECTING_ERROR", error: e, stackTrace: s);
            })
            .whenComplete(() {
              _isDetecting = false;
              if (mounted) setState(() {});
            });
      }
    });
  }

  void toggleCameraDirection() async {
    if (_direction == CameraLensDirection.back) {
      _direction = CameraLensDirection.front;
    } else {
      _direction = CameraLensDirection.back;
    }
    await camera?.stopImageStream();
    // await camera?.dispose();
    camera = null;

    initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    // setStatusBarColor(Colors.white, Brightness.light);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: BackButton(),
        title: const Text(
          'Taking Attendance',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body:
          camera == null || camera?.value.isInitialized == false
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: <Widget>[
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            constraints: const BoxConstraints.expand(),
                            child:
                                camera == null
                                    ? const Center(child: null)
                                    : Stack(
                                      fit: StackFit.expand,
                                      children: <Widget>[
                                        CameraPreview(camera!),
                                        Builder(
                                          builder: (context) {
                                            Text noResultsText = const Text('');
                                            if (selectedFace == null ||
                                                camera == null ||
                                                camera?.value.isInitialized ==
                                                    false) {
                                              return noResultsText;
                                            }
                                            CustomPainter painter;

                                            final Size imageSize = Size(
                                              camera!.value.previewSize!.height,
                                              camera!.value.previewSize!.width,
                                            );
                                            painter = FaceDetectorPainter(
                                              imageSize,
                                              selectedFace!.boundingBox,
                                              promptMessage,
                                            );
                                            return CustomPaint(
                                              painter: painter,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        // Positioned(
                        //   bottom: 10,
                        //   right: 16,
                        //   child: GestureDetector(
                        //     onTap: () {
                        //       toggleCameraDirection();
                        //     },
                        //     child: Container(
                        //       padding: const EdgeInsets.all(8),
                        //       decoration: BoxDecoration(
                        //         color: Colors.white.withOpacity(0.14),
                        //         borderRadius: BorderRadius.circular(5),
                        //         border: Border.all(
                        //           color: Colors.white,
                        //           width: 1,
                        //         ),
                        //       ),
                        //       child: Text(
                        //         "Switch camera",
                        //         style: TextStyle(
                        //           color: Colors.white,
                        //           fontWeight: FontWeight.w500,
                        //           fontSize: 12,
                        //         ),
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
