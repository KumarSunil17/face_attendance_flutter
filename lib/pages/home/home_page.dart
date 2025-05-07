import 'dart:io';

import 'package:face_attendance_flutter/pages/attendance/attendance_page.dart';
import 'package:flutter/material.dart';

import '../../utils/local_face_processor.dart';

class HomePage extends StatefulWidget {
  static const routeName = "/";

  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List? avatarBytes;

  final String imageUrl =
      "https://smartters-erp.s3.ap-south-1.amazonaws.com/HRMS/2024/0604/1717497819019_upload-1717497817433.png";
  final String userName = "Sunil Kumar";
  final String userId = "01";

  String? localImagePath;

  @override
  void initState() {
    super.initState();
    initLocalImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        spacing: 12,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (avatarBytes == null) ...[
            Center(child: CircularProgressIndicator()),
            Text("Initializing image..."),
          ] else ...[
            Center(
              child: Image.file(
                File(localImagePath!),
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            ),
            Text("Setup done"),
            Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => launchAttendance(context),
                  child: Text("Clock In"),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void initLocalImage() {
    LocalFaceProcessor.downloadImageToCache(imageUrl, id: "sunil_kumar").then((
      value,
    ) async {
      localImagePath = value;
      avatarBytes = await LocalFaceProcessor.extractFaceFromImage(value);
      setState(() {});
    });
  }

  void launchAttendance(BuildContext context) async {
    final foundUserId = await Navigator.pushNamed(
      context,
      AttendancePage.routeName,
      arguments: {
        'initialUsers': [
          {
            "user_id": userId,
            "avatarBytes": avatarBytes ?? [],
            "name": userName,
          },
        ],
      },
    );
    if (foundUserId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text("Clock In successful!!!"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
