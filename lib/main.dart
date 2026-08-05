import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/tema/tema_apk.dart';
import 'src/widgets/glashmorp.dart';
import 'src/halaman/auth/halaman_login.dart';
import 'src/halaman/dashboard/dahsboard.dart';
import 'src/halaman/kegiatan/halaman_detail_kegiatan.dart';
import 'src/halaman/kegiatan/halaman_detail_kegiatan_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hilangkan '#' dari URL (pakai path murni: /kegiatan/id, bukan /#/kegiatan/id).
  // Catatan: kalau di-deploy ke hosting statis, pastikan server dikonfigurasi
  // untuk selalu mengarahkan semua path ke index.html (rewrite rule), supaya
  // refresh di URL selain '/' tidak menghasilkan 404 dari server.
  usePathUrlStrategy();

  // TAMBAHKAN BARIS INI UNTUK MENGATASI LAYAR MERAH
  await initializeDateFormatting('id_ID', null);

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final isSupabaseConfigured = supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT');

  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  runApp(SipenyuluhApp(isSupabaseConfigured: isSupabaseConfigured));
}

/// Bungkus konten yang butuh login. Dipakai oleh setiap route yang
/// memerlukan session aktif, supaya semua route (bukan cuma '/') konsisten
/// menampilkan HalamanLogin kalau belum login / session hilang.
class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final authState = snapshot.data;
        final hasSession = authState?.session != null ||
            Supabase.instance.client.auth.currentSession != null;
        final authEvent = authState?.event;

        if (snapshot.connectionState == ConnectionState.waiting && !hasSession) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Jika user sedang mereset password (kode OTP berhasil),
        // Supabase mengirimkan event passwordRecovery.
        // Kita TAHAN agar tetap di HalamanLogin() supaya bisa memasukkan password baru.
        if (authEvent == AuthChangeEvent.passwordRecovery) {
          return const HalamanLogin();
        }

        return hasSession ? builder(context) : const HalamanLogin();
      },
    );
  }
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGuard(
        builder: _dashboardBuilder,
      ),
    ),
    GoRoute(
      path: '/kegiatan/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AuthGuard(
          builder: (context) => HalamanDetailKegiatanLoader(activityId: id),
        );
      },
    ),
  ],
);

Widget _dashboardBuilder(BuildContext context) => const HalamanDashboard();

class SipenyuluhApp extends StatelessWidget {
  const SipenyuluhApp({super.key, required this.isSupabaseConfigured});
  final bool isSupabaseConfigured;

  @override
  Widget build(BuildContext context) {
    if (!isSupabaseConfigured) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIPENYULUH',
        theme: TemaAplikasi.modeTerang,
        home: const HalamanSetup(),
      );
    }
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SIPENYULUH',
      theme: TemaAplikasi.modeTerang,
      routerConfig: _router,
    );
  }
}

class HalamanSetup extends StatelessWidget {
  const HalamanSetup({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: LatarBelakangGradien(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: KartuKaca(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.forest, size: 72, color: Color(0xFF2E7D32)),
                    SizedBox(height: 24),
                    Text(
                      'SIPENYULUH',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Tambahkan SUPABASE_URL dan SUPABASE_ANON_KEY\nuntuk mengaktifkan aplikasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}