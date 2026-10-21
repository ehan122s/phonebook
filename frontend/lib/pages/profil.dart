
import 'package:flutter/material.dart';

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(
                Icons.person,
                size: 48,
                color: Color(0xFF2E7D32),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Profil Pengguna',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Informasi akun akan ditampilkan di sini.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}