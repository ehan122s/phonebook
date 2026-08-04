import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/tema/tema_apk.dart';
import 'src/widgets/glashmorp.dart';
import 'src/halaman/auth/halaman_login.dart';
import 'src/halaman/dashboard/dahsboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class SipenyuluhApp extends StatelessWidget {
  const SipenyuluhApp({super.key, required this.isSupabaseConfigured});
  final bool isSupabaseConfigured;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIPENYULUH',
        theme: TemaAplikasi.modeTerang,
        home: isSupabaseConfigured ? const AuthGate() : const HalamanSetup(),
      );
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Ambil data state dan event saat ini
        final authState = snapshot.data;
        final hasSession = authState?.session != null;
        final authEvent = authState?.event;

        if (snapshot.connectionState == ConnectionState.waiting && !hasSession) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // --- TAMBAHAN LOGIKA PENCEGAHAN ---
        // Jika user sedang mereset password (kode OTP berhasil),
        // Supabase mengirimkan event passwordRecovery.
        // Kita TAHAN agar tetap di HalamanLogin() supaya bisa memasukkan password baru.
        if (authEvent == AuthChangeEvent.passwordRecovery) {
          return const HalamanLogin();
        }

        // Jika event bukan pemulihan password, jalan seperti biasa:
        return hasSession ? const HalamanDashboard() : const HalamanLogin();
      },
    );
  }
}