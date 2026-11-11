import 'dart:io';
import 'package:flutter/material.dart';

class ProfileIdentityCard extends StatelessWidget {
  final String nama;
  final String jabatan;
  final String nip;
  final String wilayah;
  final String avatar;
  final String role;
  final String status;
  final VoidCallback onEditProfile;
  final VoidCallback onChangeAvatar;

  const ProfileIdentityCard({
    super.key,
    required this.nama,
    required this.jabatan,
    required this.nip,
    required this.wilayah,
    required this.avatar,
    required this.role,
    this.status = 'Aktif',
    required this.onEditProfile,
    required this.onChangeAvatar,
  });

  Widget _buildAvatar() {
    ImageProvider? imageProvider;
    if (avatar.isNotEmpty) {
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        imageProvider = NetworkImage(avatar);
      } else {
        final file = File(avatar);
        if (file.existsSync()) {
          imageProvider = FileImage(file);
        }
      }
    }

    // Ekstraksi 2 huruf inisial dari nama
    String initials = 'P';
    final parts = nama.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials = parts[0][0].toUpperCase();
    }

    return GestureDetector(
      onTap: onChangeAvatar,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFFE8F5E9),
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF285C2E),
                        letterSpacing: 1.0,
                      ),
                    )
                  : null,
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF285C2E),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.toLowerCase() == 'admin';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Foto Profil & Avatar
          _buildAvatar(),
          const SizedBox(height: 14),

          // Nama Lengkap (Ukuran jelas untuk usia 40-60 tahun)
          Text(
            nama,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2923),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 5),

          // Jabatan & Instansi
          Text(
            jabatan.isNotEmpty ? jabatan : 'Penyuluh Kehutanan',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF285C2E),
            ),
          ),
          const SizedBox(height: 2),

          Text(
            wilayah.isNotEmpty ? wilayah : 'CDK Wilayah V Garut',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),

          // Chips Baris: Status Akun & Role
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              // Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Status: $status',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),

              // Role Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAdmin ? const Color(0xFFFFCC80) : const Color(0xFFBBDEFB),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_outline_rounded,
                      size: 13,
                      color: isAdmin ? const Color(0xFFE65100) : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAdmin ? 'Administrator' : 'Pegawai / Penyuluh',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isAdmin ? const Color(0xFFE65100) : const Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tombol Edit Profil
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text(
                'Edit Profil Saya',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF285C2E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
