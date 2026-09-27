import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:device_preview_screenshot/device_preview_screenshot.dart';
import 'dart:io';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      tools: [
        ...DevicePreview.defaultTools,
        DevicePreviewScreenshot(
          onScreenshot: (context, screenshot) async {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final file = File('docs/assets/screenshot_$timestamp.png');

            await file.create(recursive: true);
            await file.writeAsBytes(screenshot.bytes);

            print('✅ Screenshot successfully saved to: ${file.path}');
          },
        ),
      ],
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
