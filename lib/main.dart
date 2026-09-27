// Location: lib/main.dart
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:device_preview_screenshot/device_preview_screenshot.dart'; // Added for screenshot
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart'; // added this import

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      // The tools array is added right here, inside DevicePreview
      tools: const [...DevicePreview.defaultTools, DevicePreviewScreenshot()],
      builder: (context) => const ResortBookApp(),
    ),
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
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
