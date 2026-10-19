import 'package:flutter/material.dart';

/// Displayed when there are no reports in the history.
class LaporanEmptyState extends StatelessWidget {
  const LaporanEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 55,
            color: Color(0xFF9EAA9E),
          ),
          SizedBox(height: 15),
          Text(
            'Belum ada laporan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Laporan yang Anda buat akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
