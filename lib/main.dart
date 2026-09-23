import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ResortBookApp());
}

class ResortBookApp extends StatelessWidget {
  const ResortBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResortBook',
      theme: AppTheme.lightTheme,
      // Replace this when its phase 3
      home: const PlaceholderDashboard(), 
      debugShowCheckedModeBanner: false,
    );
  }
}

// Temporary widget just to verify the theme is working
class PlaceholderDashboard extends StatelessWidget {
  const PlaceholderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResortBook'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: Text(
          'Ready for Phase 2',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
