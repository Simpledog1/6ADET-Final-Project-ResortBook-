import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:device_preview_screenshot/device_preview_screenshot.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      tools: [
        ...DevicePreview.defaultTools,
        DevicePreviewScreenshot(
          onScreenshot: (context, screenshot) async {
            try {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final file = File(
                'G:/ADET FINALS/6ADET-Final-Project-ResortBook-/docs/assets/Documentation Screenshots/screenshot_$timestamp.png',
              );

              await file.create(recursive: true);
              await file.writeAsBytes(screenshot.bytes);

              debugPrint('✅ SUCCESS! Saved to: ${file.path}');
            } catch (e) {
              debugPrint('❌ ERROR SAVING FILE: $e');
            }
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
      // Responsive root: mobile/tablet flow or the desktop sidebar shell.
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
