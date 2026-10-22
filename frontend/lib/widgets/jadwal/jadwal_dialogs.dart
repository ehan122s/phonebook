// ============================================================================
// [FILE WIDGET 4 - POP-UP DETAIL & FORM TAMBAH/EDIT JADWAL]
// Simpan file ini di: widgets/jadwal/jadwal_dialogs.dart
// ============================================================================

import 'package:flutter/material.dart';
import '../../constants/jadwal_constants.dart';

/// Shows the detail modal for a selected schedule item.
void showJadwalDetail(
  BuildContext context, {
  required Map<String, dynamic> jadwal,
  required VoidCallback onToggleComplete,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final date = JadwalDateUtils.parseIsoDate(jadwal['tanggalIso'] ?? '');
  final isCompleted = jadwal['isCompleted'] ?? false;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: JadwalColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: JadwalColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              jadwal['judul'] ?? 'Detail Jadwal',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailItem(
            icon: Icons.category_outlined,
            label: 'Kategori',
            value: jadwal['kategori'] ?? 'Kegiatan Lapangan',
          ),
          const SizedBox(height: 10),
          _DetailItem(
            icon: Icons.calendar_today_outlined,
            label: 'Hari & Tanggal',
            value: JadwalDateUtils.formatHariTanggal(date),
          ),
          const SizedBox(height: 10),
          _DetailItem(
            icon: Icons.access_time_rounded,
            label: 'Waktu',
            value: '${jadwal['waktu'] ?? '08:00'} WIB',
          ),
          const SizedBox(height: 10),
          _DetailItem(
            icon: Icons.location_on_outlined,
            label: 'Lokasi',
            value: jadwal['lokasi'] ?? '-',
          ),
          const SizedBox(height: 10),
          _DetailItem(
            icon: Icons.info_outline_rounded,
            label: 'Status',
            value: isCompleted ? 'Selesai (Riwayat)' : 'Aktif / Akan Datang',
          ),
          if ((jadwal['catatan'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            const Text(
              'Catatan Kegiatan:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: JadwalColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              jadwal['catatan'],
              style: const TextStyle(
                fontSize: 14,
                color: JadwalColors.textDark,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onDelete();
          },
          child: Text(
            'Hapus',
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onEdit();
          },
          child: const Text('Edit'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JadwalColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.of(ctx).pop();
            onToggleComplete();
          },
          child: Text(isCompleted ? 'Tandai Belum Selesai' : 'Tandai Selesai'),
        ),
      ],
    ),
  );
}

/// Shows a form dialog to create or edit a schedule item.
void showJadwalForm(
  BuildContext context, {
  required DateTime initialDate,
  Map<String, dynamic>? existing,
  required ValueChanged<Map<String, dynamic>> onSaved,
}) {
  final isEditing = existing != null;
  final judulCtrl = TextEditingController(text: existing?['judul'] ?? '');
  final kategoriCtrl = TextEditingController(
    text: existing?['kategori'] ?? 'Penyuluhan',
  );
  final waktuCtrl = TextEditingController(text: existing?['waktu'] ?? '08:00');
  final lokasiCtrl = TextEditingController(text: existing?['lokasi'] ?? '');
  final catatanCtrl = TextEditingController(text: existing?['catatan'] ?? '');

  DateTime pickedDate = existing != null
      ? JadwalDateUtils.parseIsoDate(existing['tanggalIso'])
      : initialDate;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isEditing ? 'Edit Jadwal Kegiatan' : 'Tambah Jadwal Baru',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: judulCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Kegiatan',
                  hintText: 'Contoh: Penyuluhan Kehutanan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kategoriCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  hintText: 'Penyuluhan / Monitoring / Patroli',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final chosen = await showDatePicker(
                    context: ctx,
                    initialDate: pickedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (chosen != null) {
                    setModalState(() => pickedDate = chosen);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Kegiatan',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(JadwalDateUtils.formatHariTanggal(pickedDate)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waktuCtrl,
                decoration: const InputDecoration(
                  labelText: 'Jam (HH:MM)',
                  hintText: '08:00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lokasiCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lokasi',
                  hintText: 'Contoh: Kecamatan Garut',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catatanCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan / Rincian',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JadwalColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (judulCtrl.text.trim().isEmpty) return;

              final item = <String, dynamic>{
                'id': existing?['id'] ??
                    'jadwal_${DateTime.now().millisecondsSinceEpoch}',
                'judul': judulCtrl.text.trim(),
                'kategori': kategoriCtrl.text.trim().isEmpty
                    ? 'Kegiatan'
                    : kategoriCtrl.text.trim(),
                'tanggalIso': JadwalDateUtils.toIsoDate(pickedDate),
                'waktu': waktuCtrl.text.trim().isEmpty
                    ? '08:00'
                    : waktuCtrl.text.trim(),
                'lokasi': lokasiCtrl.text.trim().isEmpty
                    ? 'Lokasi belum diisi'
                    : lokasiCtrl.text.trim(),
                'catatan': catatanCtrl.text.trim(),
                'isCompleted': existing?['isCompleted'] ?? false,
              };

              Navigator.of(ctx).pop();
              onSaved(item);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: JadwalColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: JadwalColors.textDark,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: JadwalColors.textMuted,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}