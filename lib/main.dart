import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview_screenshot/device_preview_screenshot.dart';
import 'dart:io';
import 'theme/app_theme.dart';
import 'services/pocketbase_service.dart';
import 'widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restores the saved PocketBase login (if any) before the first screen.
  await PocketBaseService.init();
  runApp(
    DevicePreview(
      // The device frame and its screenshot tool are only for the Windows
      // debug build. Release builds and every web build (including the live
      // demo) show ResortBook directly in the full browser/app window.
      enabled: !kReleaseMode && !kIsWeb,
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
      // Login first; once signed in, the responsive AppShell (phone/tablet
      // flow below 1024 px, desktop sidebar layout from 1024 px).
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
