import 'package:flutter/material.dart';
import '../../constants/laporan_constants.dart';

/// List of available report templates/types.
class ReportTemplates extends StatelessWidget {
  const ReportTemplates({super.key, required this.onSelectTemplate});

  final ValueChanged<String> onSelectTemplate;

  static const List<Map<String, dynamic>> _templates = [
    {
      'icon': Icons.groups_outlined,
      'title': 'Laporan Penyuluhan',
      'description':
          'Digunakan untuk melaporkan kegiatan penyuluhan kehutanan.',
    },
    {
      'icon': Icons.forest_outlined,
      'title': 'Laporan Monitoring',
      'description':
          'Digunakan untuk melaporkan hasil monitoring kawasan hutan.',
    },
    {
      'icon': Icons.event_note_outlined,
      'title': 'Laporan Kegiatan',
      'description':
          'Digunakan untuk berbagai kegiatan lapangan lainnya.',
    },
    {
      'icon': Icons.warning_amber_rounded,
      'title': 'Laporan Kejadian',
      'description':
          'Digunakan untuk melaporkan kejadian atau kondisi khusus '
          'di lapangan.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _templates.map(_buildTemplateCard).toList(),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: LaporanColors.cardBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: LaporanColors.borderTemplate),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: LaporanColors.greenBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              template['icon'] as IconData,
              color: LaporanColors.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template['title'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  template['description'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              onSelectTemplate(template['title'] as String);
            },
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
            ),
            color: LaporanColors.primary,
          ),
        ],
      ),
    );
  }
}
