import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true, // Enables the viewport toggler UI
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
      home: const ResponsivePlaceholder(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Temporary widget to verify responsive logic before building Phase 3
class ResponsivePlaceholder extends StatelessWidget {
  const ResponsivePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResortBook'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // If width > 800, we apply desktop rules. Otherwise, mobile.
          final isDesktop = constraints.maxWidth > 800;

          return Center(
            child: Text(
              isDesktop
                  ? 'Desktop Viewpoint Active (> 800px)'
                  : 'Mobile Viewport Active',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          );
        },
      ),
    );
  }
}
