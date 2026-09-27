import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart'; // Added this import

void main() {
  runApp(
    DevicePreview(enabled: true, builder: (context) => const ResortBookApp()),
  );
}

class ResortBookApp extends StatelessWidget {
  const ResortBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResortBook',
      theme: AppTheme.lightTheme,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      home: const DashboardScreen(), // Updated this line
      debugShowCheckedModeBanner: false,
    );
  }
}
