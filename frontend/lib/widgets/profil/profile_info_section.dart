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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: Color(0xFF285C2E),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Berkas Kepegawaian',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2923),
                              ),
                            ),
                            Text(
                              'Arsip Data Resmi CDK Wilayah V Garut',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  _buildDetailRow('Nama Lengkap', nama, Icons.person_outline),
                  _buildDetailRow('NIP Pegawai', nip.isNotEmpty ? nip : '-', Icons.badge_outlined),
                  _buildDetailRow('Jabatan Fungsional', jabatan.isNotEmpty ? jabatan : 'Penyuluh Kehutanan', Icons.work_outline),
                  _buildDetailRow('Pangkat / Golongan', pangkat, Icons.stars_outlined),
                  _buildDetailRow('Instansi Induk', instansi, Icons.account_balance_outlined),
                  _buildDetailRow('Unit Kerja Pelaksana', unitKerja, Icons.domain_outlined),
                  _buildDetailRow('Wilayah Kerja / Binaan', wilayah.isNotEmpty ? wilayah : 'CDK Wilayah Garut', Icons.map_outlined),
                  _buildDetailRow('Email Kedinasan', email, Icons.alternate_email_rounded),
                  _buildDetailRow('Nomor WhatsApp', whatsapp.isNotEmpty ? whatsapp : '-', Icons.phone_android_rounded),

                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF2E7D32)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Data kepegawaian resmi tersinkronisasi dengan database SIMPEG Kehutanan. Perubahan data NIP dan Golongan harus melalui bagian kepegawaian CDK V.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1B5E20),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF285C2E)),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2923),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF285C2E)),
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
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2923),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  size: 20,
                  color: Color(0xFF285C2E),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Informasi Kepegawaian',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2923),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showDetailBottomSheet(context),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rincian',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF285C2E),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF285C2E),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEDF2EE)),
          const SizedBox(height: 8),

          _buildInfoTile(
            label: 'Nomor Induk Pegawai (NIP)',
            value: nip.isNotEmpty ? nip : 'Belum diisi / Non-PNS',
            icon: Icons.pin_outlined,
          ),
          _buildInfoTile(
            label: 'Jabatan Resmi',
            value: jabatan.isNotEmpty ? jabatan : 'Penyuluh Kehutanan',
            icon: Icons.work_outline_rounded,
          ),
          _buildInfoTile(
            label: 'Pangkat / Golongan',
            value: pangkat,
            icon: Icons.military_tech_outlined,
          ),
          _buildInfoTile(
            label: 'Unit Kerja Pelaksana',
            value: unitKerja,
            icon: Icons.business_outlined,
          ),
          _buildInfoTile(
            label: 'Wilayah Tugas / Binaan',
            value: wilayah.isNotEmpty ? wilayah : 'CDK Wilayah Garut',
            icon: Icons.location_on_outlined,
          ),

          const SizedBox(height: 12),

          // Banner Proteksi Data Resmi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBF9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5ECE5)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data resmi (NIP, Jabatan, Pangkat) diverifikasi oleh Administrator CDK V.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
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
