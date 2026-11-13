import 'package:flutter/material.dart';

class ProfileInfoSection extends StatelessWidget {
  final String nama;
  final String nip;
  final String jabatan;
  final String pangkat;
  final String instansi;
  final String unitKerja;
  final String wilayah;
  final String email;
  final String whatsapp;

  const ProfileInfoSection({
    super.key,
    required this.nama,
    required this.nip,
    required this.jabatan,
    this.pangkat = 'Penata Muda / III/a',
    this.instansi = 'Dinas Kehutanan Provinsi Jawa Barat',
    this.unitKerja = 'Cabang Dinas Kehutanan Wilayah V Garut',
    required this.wilayah,
    required this.email,
    required this.whatsapp,
  });

  void _showDetailBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final iconBg = isDark ? const Color(0xFF26352B) : const Color(0xFFE8F5E9);
    final dividerColor = isDark ? const Color(0xFF2E3D34) : const Color(0xFFEDF2EE);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.badge_rounded,
                          color: iconColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Berkas Kepegawaian',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                            Text(
                              'Arsip Data Resmi CDK Wilayah V Garut',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white60 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: dividerColor),
                  const SizedBox(height: 12),

                  _buildDetailRow(context, 'Nama Lengkap', nama, Icons.person_outline),
                  _buildDetailRow(context, 'NIP Pegawai', nip.isNotEmpty ? nip : '-', Icons.badge_outlined),
                  _buildDetailRow(context, 'Jabatan Fungsional', jabatan.isNotEmpty ? jabatan : 'Penyuluh Kehutanan', Icons.work_outline),
                  _buildDetailRow(context, 'Pangkat / Golongan', pangkat, Icons.stars_outlined),
                  _buildDetailRow(context, 'Instansi Induk', instansi, Icons.account_balance_outlined),
                  _buildDetailRow(context, 'Unit Kerja Pelaksana', unitKerja, Icons.domain_outlined),
                  _buildDetailRow(context, 'Wilayah Kerja / Binaan', wilayah.isNotEmpty ? wilayah : 'CDK Wilayah Garut', Icons.map_outlined),
                  _buildDetailRow(context, 'Email Kedinasan', email, Icons.alternate_email_rounded),
                  _buildDetailRow(context, 'Nomor WhatsApp', whatsapp.isNotEmpty ? whatsapp : '-', Icons.phone_android_rounded),

                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C2B21) : const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2D4433) : const Color(0xFFC8E6C9),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Data kepegawaian resmi tersinkronisasi dengan database SIMPEG Kehutanan. Perubahan data NIP dan Golongan harus melalui bagian kepegawaian CDK V.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final labelColor = isDark ? Colors.white60 : Colors.grey.shade700;
    final valColor = isDark ? Colors.white : const Color(0xFF1E2923);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: valColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF26352B) : const Color(0xFFF1F8E9);
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final valColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final labelColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : const Color(0xFFE0E7E1);
    final headerBg = isDark ? const Color(0xFF26352B) : const Color(0xFFE8F5E9);
    final headerIconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2923);
    final linkColor = isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E);
    final dividerColor = isDark ? const Color(0xFF2E3D34) : const Color(0xFFEDF2EE);
    final noteBg = isDark ? const Color(0xFF18221B) : const Color(0xFFF9FBF9);
    final noteBorder = isDark ? const Color(0xFF26352B) : const Color(0xFFE5ECE5);
    final noteText = isDark ? Colors.white70 : Colors.grey.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.badge_rounded,
                  size: 20,
                  color: headerIconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Informasi Kepegawaian',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showDetailBottomSheet(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rincian',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: linkColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: linkColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 8),

          _buildInfoTile(
            context,
            label: 'Nomor Induk Pegawai (NIP)',
            value: nip.isNotEmpty ? nip : 'Belum diisi / Non-PNS',
            icon: Icons.pin_outlined,
          ),
          _buildInfoTile(
            context,
            label: 'Jabatan Resmi',
            value: jabatan.isNotEmpty ? jabatan : 'Penyuluh Kehutanan',
            icon: Icons.work_outline_rounded,
          ),
          _buildInfoTile(
            context,
            label: 'Pangkat / Golongan',
            value: pangkat,
            icon: Icons.military_tech_outlined,
          ),
          _buildInfoTile(
            context,
            label: 'Unit Kerja Pelaksana',
            value: unitKerja,
            icon: Icons.business_outlined,
          ),
          _buildInfoTile(
            context,
            label: 'Wilayah Tugas / Binaan',
            value: wilayah.isNotEmpty ? wilayah : 'CDK Wilayah Garut',
            icon: Icons.location_on_outlined,
          ),

          const SizedBox(height: 12),

          // Banner Proteksi Data Resmi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: noteBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: noteBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: isDark ? Colors.white60 : Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data resmi (NIP, Jabatan, Pangkat) diverifikasi oleh Administrator CDK V.',
                    style: TextStyle(
                      fontSize: 11,
                      color: noteText,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
