import 'package:face_attendance_flutter/pages/attendance/attendance_page.dart';
import 'package:face_attendance_flutter/pages/home/home_page.dart'
    show HomePage;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case HomePage.routeName:
            return MaterialPageRoute(builder: (_) => HomePage());
          case AttendancePage.routeName:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => AttendancePage(args));
          default:
            return MaterialPageRoute(builder: (_) => HomePage());
        }
      },
      initialRoute: "/",
      home: const HomePage(),
    );
  }
}
