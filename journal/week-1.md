**Week 1:** Finals, September 23, 2026

**My goal this week**
Set up the Flutter development environment on Linux, establish the core project architecture for the ResortBook application, and complete the visual foundation (Phase 1) and database connection (Phase 2).

**What I did**
Corrected the project scope to be strictly mobile-only, bypassing unnecessary cross-platform optimizations. I wrote the initial offline Flutter codebase, establishing the `lib/` directory structure. I implemented the Material 3 design system locally by creating `app_theme.dart` with the primary #1E3A8A seed color and mapping the typography to the `TextTheme`. I also created `app_spacing.dart` to enforce the 8px base spacing scale. Finally, I drafted the `README.md` and `SECURITY-CHECKLIST.md` documentation based on this progress.

**What blocked me**
Severe local network instability. My Wi-Fi connection kept dropping at around 85 kbps, which caused Git `early EOF` and `curl 56` timeout errors when attempting to clone the Flutter SDK. Because I could not successfully run `flutter doctor` to pull the Dart SDK or download the PocketBase executable, I was entirely blocked from compiling the code, running the Android emulator, or testing the database.

**What I learned**
I learned how to centralize a Flutter application's visual system using `ThemeData` and spacing constants so that individual screens do not require hardcoded values. I also learned that the Flutter installation process relies on uninterrupted, large single-stream downloads for the Dart SDK, and I learned specific Git commands (like increasing `http.postBuffer` and using `--depth 1` for shallow clones) to attempt to bypass network timeouts.
