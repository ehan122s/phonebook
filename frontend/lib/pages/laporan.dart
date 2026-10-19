import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/laporan_constants.dart';
import '../services/laporan_service.dart';
import '../widgets/laporan/create_report_card.dart';
import '../widgets/laporan/empty_state.dart';
import '../widgets/laporan/laporan_header.dart';
import '../widgets/laporan/laporan_tab_bar.dart';
import '../widgets/laporan/report_card.dart';
import '../widgets/laporan/report_dialogs.dart';
import '../widgets/laporan/report_templates.dart';

/// Main page for managing field reports (laporan kegiatan).
class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  static const String _storageKey = 'phonebook_laporan_drafts_v1';

  int _selectedTab = 0;
  final List<Map<String, dynamic>> _laporanList = [];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadSavedReports();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadSavedReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sesi login tidak ditemukan. Silakan login kembali.',
            ),
          ),
        );
        return;
      }

      final reports = await LaporanService.fetchReports(token);

      if (!mounted) return;
      setState(() {
        _laporanList
          ..clear()
          ..addAll(reports);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal terhubung ke Laravel: $e')),
      );
    }
  }

  Future<void> _persistReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_laporanList));
  }

  Future<void> _saveReport(Map<String, dynamic> report) async {
    final id = report['id'];
    final index = _laporanList.indexWhere((item) => item['id'] == id);
    setState(() {
      if (index >= 0) {
        _laporanList[index] = report;
      } else {
        _laporanList.insert(0, report);
      }
    });
    await _persistReports();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openReportForm(
    String jenisLaporan, {
    Map<String, dynamic>? existing,
  }) {
    showReportForm(
      context,
      jenisLaporan: jenisLaporan,
      existing: existing,
      onReportSaved: _loadSavedReports,
    );
  }

  void _downloadReport(Map<String, dynamic> laporan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menyiapkan file "${laporan['judul']}"...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LaporanColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Laporan',
          style: TextStyle(
            color: LaporanColors.textDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF285C2E),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LaporanHeader(),

              const SizedBox(height: 24),

              CreateReportCard(
                onTap: () => showReportTypeDialog(
                  context,
                  onSelectType: _openReportForm,
                ),
              ),

              const SizedBox(height: 28),

              // Section title
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arsip Laporan',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: LaporanColors.textDark,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Draft yang masih bisa diedit dan arsip '
                    'laporan yang sudah selesai.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              LaporanTabBar(
                selectedTab: _selectedTab,
                onTabChanged: (index) {
                  setState(() => _selectedTab = index);
                },
              ),

              const SizedBox(height: 18),

              if (_selectedTab == 0)
                _buildReportHistory()
              else
                ReportTemplates(
                  onSelectTemplate: _openReportForm,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Report history list
  // ---------------------------------------------------------------------------

  Widget _buildReportHistory() {
    if (_laporanList.isEmpty) {
      return const LaporanEmptyState();
    }

    return Column(
      children: _laporanList.map((laporan) {
        return ReportCard(
          laporan: laporan,
          onView: () => showReportDetail(
            context,
            laporan: laporan,
            onEdit: _openReportForm,
            onDownload: _downloadReport,
          ),
          onEdit: () => _openReportForm(
            laporan['jenis'],
            existing: laporan,
          ),
          onDownload: () => _downloadReport(laporan),
        );
      }).toList(),
    );
  }
}