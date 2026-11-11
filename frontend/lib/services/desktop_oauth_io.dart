import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';

/// Melakukan alur otentikasi resmi Google OAuth 2.0 Loopback di Desktop.
/// Membuka browser default sistem ke halaman pemilihan akun Google resmi,
/// lalu menerima token otentikasi dan mengambil data profil pengguna dari Google API.
Future<Map<String, dynamic>?> performDesktopGoogleOAuth(
  BuildContext context,
) async {
  HttpServer? server;
  try {
    // 1. Jalankan server lokal loopback untuk menerima callback redirect dari Google
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8085);
    } catch (_) {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }

    final port = server.port;
    final redirectUri = 'http://localhost:$port';

    // 2. Susun URL Google OAuth 2.0 resmi
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': ApiConstants.googleClientIdWeb,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'email profile openid',
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    // 3. Buka browser default (xdg-open di Linux, start di Windows, open di macOS)
    bool opened = false;
    if (Platform.isLinux) {
      try {
        final res = await Process.run('xdg-open', [authUrl.toString()]);
        if (res.exitCode == 0) opened = true;
      } catch (_) {}
    } else if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', authUrl.toString()]);
        opened = true;
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', [authUrl.toString()]);
        opened = true;
      } catch (_) {}
    }

    if (!opened) {
      try {
        opened = await launchUrl(authUrl);
      } catch (e) {
        debugPrint('launchUrl error: $e');
      }
    }

    if (!opened) {
      throw Exception('Tidak dapat membuka browser sistem untuk otentikasi Google.');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membuka browser untuk login dengan Akun Google...'),
          duration: Duration(seconds: 4),
          backgroundColor: Color(0xFF1E88E5),
        ),
      );
    }

    // 4. Tunggu respons dari Google OAuth callback
    final request = await server.first.timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw Exception('Waktu login habis atau dibatalkan.'),
    );

    final code = request.uri.queryParameters['code'];
    final error = request.uri.queryParameters['error'];

    request.response.headers.contentType = ContentType.html;
    if (code != null) {
      request.response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Login Berhasil - Phonebook Kehutanan</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f0fdf4; }
    .card { background: white; padding: 36px 48px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.06); text-align: center; border: 1px solid #dcfce7; max-width: 420px; }
    h2 { color: #15803d; margin: 0 0 10px 0; font-size: 22px; }
    p { color: #4b5563; font-size: 14.5px; line-height: 1.5; margin: 0; }
  </style>
</head>
<body>
  <div class="card">
    <h2>✓ Berhasil Masuk</h2>
    <p>Akun Google berhasil terhubung. Anda dapat menutup tab ini dan kembali ke aplikasi <strong>Phonebook Kehutanan</strong>.</p>
  </div>
</body>
</html>
''');
    } else {
      request.response.write('''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Login Gagal</title></head>
<body style="font-family: sans-serif; padding: 30px;">
  <h3 style="color: #b91c1c;">Gagal Login: ${error ?? 'Dibatalkan'}</h3>
  <p>Silakan kembali ke aplikasi.</p>
</body>
</html>
''');
    }
    await request.response.close();

    if (code == null) {
      throw Exception(error ?? 'Kode otorisasi Google tidak ditemukan');
    }

    // 5. Tukar kode otorisasi dengan Access Token ke endpoint resmi Google
    final tokenResponse = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'client_id': ApiConstants.googleClientIdWeb,
        'client_secret': ApiConstants.googleClientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );

    final tokenData = jsonDecode(tokenResponse.body);
    final accessToken = tokenData['access_token'];

    if (accessToken == null) {
      final errDesc =
          tokenData['error_description'] ??
          tokenData['error'] ??
          'Gagal otentikasi Google Token';
      throw Exception(errDesc);
    }

    // 6. Ambil profil pengguna resmi dari Google UserInfo API
    final userinfoResponse = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final userInfo = jsonDecode(userinfoResponse.body);
    final email = (userInfo['email'] ?? '').toString().trim().toLowerCase();
    final name = (userInfo['name'] ?? email.split('@').first).toString().trim();
    final id = (userInfo['id'] ?? '').toString();
    final picture = (userInfo['picture'] ?? '').toString();

    return {
      'email': email,
      'name': name,
      'google_id': id,
      'avatar': picture,
      'id_token': (tokenData['id_token'] ?? '').toString(),
    };
  } catch (e) {
    debugPrint('Desktop Google OAuth error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login Google Desktop: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    return null;
  } finally {
    await server?.close(force: true);
  }
}
