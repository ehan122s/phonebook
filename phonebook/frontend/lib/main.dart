// ============================================================================
// [FILE UTAMA - MAIN.DART (ANTI-STUCK SAAT HOT RESTART)]
// Simpan langsung di: lib/main.dart
// Perbaikan:
// - Menggunakan Timer (Future.delayed) sebagai pemicu pindah halaman dari
//   SplashScreen (bukan await _mainCtrl.forward()), sehingga tidak akan pernah
//   nyangkut/stuck saat di-Hot Restart di Flutter Web!
// - Bisa juga di-klik layarnya kalau mau langsung skip Splash Screen.
// - Menginisialisasi NotificationService global untuk pengelolaan notifikasi
//   dan penjadwalan reminder otomatis (Asia/Jakarta).
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'services/app_settings_service.dart';
import 'services/notification_service.dart';
import 'pages/admin/admin_page.dart';
import 'pages/home/home.dart';
import 'pages/login/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi driver SQLite FFI saat aplikasi dijalankan di Desktop (Linux, Windows, macOS)
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Inisialisasi pengaturan tema dan ukuran font global
  await AppSettingsService.instance.init();

  // Inisialisasi sistem notifikasi & penjadwalan reminder otomatis (Asia/Jakarta)
  await NotificationService.instance.init();

  runApp(const PhonebookApp());
}

class PhonebookApp extends StatelessWidget {
  const PhonebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final settings = AppSettingsService.instance;

        return MaterialApp(
          title: 'Phonebook',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey:
              NotificationService.instance.scaffoldMessengerKey,
          themeMode: settings.themeMode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.textScaleFactor),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Arial',
      scaffoldBackgroundColor: const Color(0xFFF8FAF8),
      cardColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D32),
        brightness: Brightness.light,
        primary: const Color(0xFF285C2E),
        secondary: const Color(0xFF3B7A42),
        surface: Colors.white,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.iOS: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.windows: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.macOS: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.linux: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.fuchsia: _SmoothCihuyPageTransitionBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E3F24),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const darkBg = Color(0xFF121814);
    const darkCard = Color(0xFF1E2822);
    const darkSurface = Color(0xFF18211B);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Arial',
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      dialogTheme: const DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF81C784),
        brightness: Brightness.dark,
        primary: const Color(0xFF81C784),
        secondary: const Color(0xFFA5D6A7),
        surface: darkSurface,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.iOS: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.windows: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.macOS: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.linux: _SmoothCihuyPageTransitionBuilder(),
          TargetPlatform.fuchsia: _SmoothCihuyPageTransitionBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF26332A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _SmoothCihuyPageTransitionBuilder extends PageTransitionsBuilder {
  const _SmoothCihuyPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedIn = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curvedIn,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.03, 0.01),
          end: Offset.zero,
        ).animate(curvedIn),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curvedIn),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// SPLASH SCREEN (ANTI-STUCK HOT RESTART)
// ============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _progressValue;

  Timer? _navTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.45, 0.80, curve: Curves.easeOut),
      ),
    );

    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.20, 0.95, curve: Curves.easeInOut),
      ),
    );

    // Jalankan animasi setelah frame pertama siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mainCtrl.forward();
      }
    });

    // Timer independen: dijamin tidak pernah stuck walaupun tab browser tidak fokus saat Hot Restart
    _navTimer = Timer(const Duration(milliseconds: 2400), _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _navTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = (prefs.getString('role') ?? '').trim().toLowerCase();
    final email = (prefs.getString('email') ?? '').trim().toLowerCase();

    final bool isLoggedIn = token != null && token.isNotEmpty;
    final bool isAdmin = role == 'admin' ||
        email == 'admin@kehutanan.go.id' ||
        email == 'admin@phonebook.com' ||
        email == 'admin@gmail.com' ||
        email.startsWith('admin@');

    final Widget targetPage = isLoggedIn
        ? (isAdmin ? const AdminPage() : const HomePage())
        : const LoginPage();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _mainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _navigateNext,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF16381A),
                Color(0xFF285C2E),
                Color(0xFF3A7D42),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: -90,
                right: -70,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -110,
                left: -80,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  blurRadius: 28,
                                  spreadRadius: 6,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.forest_rounded,
                              size: 68,
                              color: Color(0xFF285C2E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: Column(
                            children: [
                              const Text(
                                'PHONEBOOK',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: const Text(
                                  'Aplikasi Pelaporan & Penyuluhan Kehutanan',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(flex: 3),
                      FadeTransition(
                        opacity: _subtitleFade,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 230),
                          child: AnimatedBuilder(
                            animation: _progressValue,
                            builder: (context, _) {
                              return Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: _progressValue.value,
                                      minHeight: 5,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.18),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFA5D6A7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Menyiapkan ruang kerja penyuluh...',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}