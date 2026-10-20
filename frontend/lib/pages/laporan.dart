import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/laporan_constants.dart';
import '../services/connectivity_service.dart';
import '../services/laporan_service.dart';
import '../services/offline_database.dart';
import '../services/sync_service.dart';
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

  bool _isOffline = false;
  int _pendingSyncCount = 0;
  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySub;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadSavedReports();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Connectivity
  // ---------------------------------------------------------------------------

  Future<void> _initConnectivity() async {
    // Check initial state
    final online = await ConnectivityService.instance.isOnline();
    if (mounted) {
      setState(() => _isOffline = !online);
    }

    // Listen for changes
    _connectivitySub =
        ConnectivityService.instance.onConnectivityChanged.listen(
      (isOnline) async {
        if (!mounted) return;
        final wasOffline = _isOffline;
        setState(() => _isOffline = !isOnline);

        // Auto-sync when coming back online
        if (wasOffline && isOnline) {
          await _autoSync();
        }
      },
    );

    // Update pending count
    await _updatePendingCount();
  }

  Future<void> _updatePendingCount() async {
    final count = await OfflineDatabase.instance.getPendingCount();
    if (mounted) {
      setState(() => _pendingSyncCount = count);
    }
  }

  Future<void> _autoSync() async {
    if (_isSyncing) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) return;

    final pendingCount = await OfflineDatabase.instance.getPendingCount();
    if (pendingCount == 0) return;

    setState(() => _isSyncing = true);

    try {
      final result = await SyncService.syncAll(token);

      if (!mounted) return;

      if (result.synced > 0) {
        // Clean up synced reports from local DB
        await OfflineDatabase.instance.clearSyncedReports();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.synced} laporan berhasil disinkronkan ke server.',
            ),
            backgroundColor: LaporanColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (result.failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.failed} laporan gagal disinkronkan. '
              'Akan dicoba lagi nanti.',
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Reload all reports
      await _loadSavedReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal sinkronisasi: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
      await _updatePendingCount();
    }
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

      final List<Map<String, dynamic>> allReports = [];

      // Load offline/pending reports from local DB
      final localReports = await OfflineDatabase.instance.getPendingReports();
      for (final local in localReports) {
        final String activityDate =
            local['activity_date']?.toString() ?? '';
        final String rawStatus =
            local['status']?.toString() ?? 'draft';

        allReports.add({
          'id': 'local_${local['id']}',
          'judul': local['title'] ?? 'Laporan tanpa judul',
          'jenis': local['jenis_laporan'] ?? 'Laporan Kegiatan',
          'tanggal': LaporanDateUtils.formatApiDate(activityDate),
          'tanggalApi': activityDate,
          'lokasi': local['location'] ?? 'Belum diisi',
          'isi': local['description'] ?? '',
          'latitude': local['latitude']?.toString() ?? '',
          'longitude': local['longitude']?.toString() ?? '',
          'foto': '',
          'photos': <dynamic>[],
          'status': LaporanDateUtils.displayStatus(rawStatus),
          'statusApi': rawStatus,
          'isOffline': true,
          'syncStatus': local['sync_status'],
          'localId': local['id'],
        });
      }

      // Load server reports if online
      final online = await ConnectivityService.instance.isOnline();
      if (online) {
        try {
          final serverReports =
              await LaporanService.fetchReports(token);
          allReports.addAll(serverReports);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal mengambil data server: $e'),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _laporanList
          ..clear()
          ..addAll(allReports);
      });

      await _updatePendingCount();
    } catch (e) {
      if (!mounted) return;

      // If offline, load only from local DB
      try {
        final localReports =
            await OfflineDatabase.instance.getAllLocalReports();
        final List<Map<String, dynamic>> offlineList = [];

        for (final local in localReports) {
          final String activityDate =
              local['activity_date']?.toString() ?? '';
          final String rawStatus =
              local['status']?.toString() ?? 'draft';

          offlineList.add({
            'id': 'local_${local['id']}',
            'judul': local['title'] ?? 'Laporan tanpa judul',
            'jenis': local['jenis_laporan'] ?? 'Laporan Kegiatan',
            'tanggal': LaporanDateUtils.formatApiDate(activityDate),
            'tanggalApi': activityDate,
            'lokasi': local['location'] ?? 'Belum diisi',
            'isi': local['description'] ?? '',
            'latitude': local['latitude']?.toString() ?? '',
            'longitude': local['longitude']?.toString() ?? '',
            'foto': '',
            'photos': <dynamic>[],
            'status': LaporanDateUtils.displayStatus(rawStatus),
            'statusApi': rawStatus,
            'isOffline': true,
            'syncStatus': local['sync_status'],
            'localId': local['id'],
          });
        }

        if (!mounted) return;
        setState(() {
          _laporanList
            ..clear()
            ..addAll(offlineList);
        });
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mode offline — menampilkan data lokal.')),
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

  Future<void> _deleteReport(Map<String, dynamic> laporan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Hapus Laporan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus laporan "${laporan['judul'] ?? 'ini'}"? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Check if it's an offline report
    final isOffline = laporan['isOffline'] == true;

    if (isOffline) {
      try {
        final localId = laporan['localId'] as int;
        await OfflineDatabase.instance.deleteLocalReport(localId);

        if (!mounted) return;
        setState(() {
          _laporanList.removeWhere(
            (item) => item['id'] == laporan['id'],
          );
        });
        await _updatePendingCount();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Laporan offline "${laporan['judul']}" berhasil dihapus.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus laporan: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Online report — delete from server
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

      await LaporanService.deleteReport(token, laporan['id']);

      if (!mounted) return;
      setState(() {
        _laporanList.removeWhere((item) => item['id'] == laporan['id']);
      });
      await _persistReports();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan "${laporan['judul']}" berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus laporan: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        actions: [
          if (_pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _isSyncing || _isOffline ? null : _autoSync,
                tooltip: _isOffline
                    ? 'Tidak ada koneksi'
                    : 'Sinkronkan $_pendingSyncCount laporan',
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LaporanColors.primary,
                        ),
                      )
                    : Badge(
                        label: Text('$_pendingSyncCount'),
                        child: const Icon(
                          Icons.sync_rounded,
                          color: LaporanColors.primary,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offline banner
              if (_isOffline) _buildOfflineBanner(),

              // Pending sync banner
              if (!_isOffline && _pendingSyncCount > 0)
                _buildPendingSyncBanner(),

              const SizedBox(height: 20),

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
  // Offline / Sync banners
  // ---------------------------------------------------------------------------

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tidak ada koneksi internet. Laporan akan '
                  'disimpan di perangkat dan otomatis dikirim '
                  'saat koneksi kembali.',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSyncBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: Colors.blue.shade700,
              size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$_pendingSyncCount laporan menunggu sinkronisasi.',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: _isSyncing ? null : _autoSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Sinkronkan', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
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
          onDelete: () => _deleteReport(laporan),
        );
      }).toList(),
    );
  }
}
