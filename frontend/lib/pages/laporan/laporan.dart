import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/laporan_constants.dart';
import '../../services/connectivity_service.dart';
import '../../services/laporan_service.dart';
import '../../services/monitoring_calculator.dart';
import '../../services/offline_database.dart';
import '../../services/sync_service.dart';
import '../../widgets/laporan/create_report_card.dart';
import '../../widgets/laporan/empty_state.dart';
import '../../widgets/laporan/laporan_header.dart';
import '../../widgets/laporan/laporan_tab_bar.dart';
import '../../widgets/laporan/report_card.dart';
import '../../widgets/laporan/report_dialogs.dart';
import '../../widgets/laporan/report_templates.dart';

/// Main page for managing field reports (User) and report templates + monitoring (Admin).
class LaporanPage extends StatefulWidget {
  final bool? isAdminMode;
  final String? initialReportId;
  final String? initialReportTitle;

  const LaporanPage({
    super.key,
    this.isAdminMode,
    this.initialReportId,
    this.initialReportTitle,
  });

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  static const String _storageKey = 'phonebook_laporan_drafts_v1';
  static const String _archiveStorageKey = 'phonebook_folder_archives_v1';

  int _selectedTab = 0;
  bool _isAdmin = false;
  bool _isLoadingReports = true;
  String? _loadErrorMessage;
  int _loadRequestToken = 0;
  bool _hasOpenedInitialReport = false;

  final ScrollController _userScrollController = ScrollController();
  final GlobalKey _arsipSectionKey = GlobalKey();
  bool _highlightLatestCard = false;

  final List<Map<String, dynamic>> _laporanList = [];
  final List<Map<String, dynamic>> _templatesList = [];

  // Filter untuk Monitoring Laporan (Mode Admin)
  String _adminSearchQuery = '';
  String _adminFilterJenis = 'Semua';
  String _adminFilterStatus = 'Semua';

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
    _isAdmin = widget.isAdminMode ?? false;
    _initRoleAndTemplates();
    _initConnectivity();
    _loadSavedReports();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _userScrollController.dispose();
    super.dispose();
  }

  Future<void> _initRoleAndTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('role') ?? '').trim().toLowerCase();
    final email = (prefs.getString('email') ?? '').trim().toLowerCase();

    final detectedAdmin =
        widget.isAdminMode ??
        (role == 'admin' ||
            email == 'admin@kehutanan.go.id' ||
            email == 'admin@phonebook.com' ||
            email == 'admin@gmail.com' ||
            email.startsWith('admin@'));

    final loadedTemplates = await ReportTemplateManager.loadTemplates();

    if (!mounted) return;
    setState(() {
      _isAdmin = detectedAdmin;
      _templatesList
        ..clear()
        ..addAll(loadedTemplates);
    });
  }

  Future<void> _reloadTemplates() async {
    final loadedTemplates = await ReportTemplateManager.loadTemplates();
    if (!mounted) return;
    setState(() {
      _templatesList
        ..clear()
        ..addAll(loadedTemplates);
    });
  }

  // ---------------------------------------------------------------------------
  // Connectivity
  // ---------------------------------------------------------------------------

  Future<void> _initConnectivity() async {
    final online = await ConnectivityService.instance.isOnline();
    if (mounted) {
      setState(() => _isOffline = !online);
    }

    _connectivitySub = ConnectivityService.instance.onConnectivityChanged
        .listen((isOnline) async {
          if (!mounted) return;
          final wasOffline = _isOffline;
          setState(() => _isOffline = !isOnline);

          if (wasOffline && isOnline) {
            await _autoSync();
          }
        });

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
        await OfflineDatabase.instance.clearSyncedReports();
        if (!mounted) return;

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
  // Data loading (User & Admin Monitoring - Tanpa Data Dummy)
  // ---------------------------------------------------------------------------

  Future<void> _loadSavedReports({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final int myToken = ++_loadRequestToken;
    final hasExisting = _laporanList.isNotEmpty;
    if ((!hasExisting || forceRefresh) && !silent && mounted) {
      setState(() {
        if (!hasExisting) _isLoadingReports = true;
        _loadErrorMessage = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final email = prefs.getString('email');
      final defaultUserName =
          prefs.getString('profil_nama') ??
          prefs.getString('name') ??
          (email != null && email.isNotEmpty
              ? email.split('@').first
              : 'Pengguna');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoadingReports = false);
        return;
      }

      final List<Map<String, dynamic>> allReports = [];
      final Set<String> seenKeys = {};

      void addUniqueReport(Map<String, dynamic> item) {
        final key =
            '${item['id']}_${item['judul']?.toString().toLowerCase() ?? ''}';
        if (seenKeys.contains(key)) return;
        seenKeys.add(key);
        final rawIsi = (item['isi'] ?? '').toString();
        if (ReportTemplateManager.isCorruptedBinaryText(rawIsi)) {
          item['isi'] = ReportTemplateManager.sanitizeReportIsi(
            rawIsi: '',
            jenis: (item['jenis'] ?? 'Laporan Kegiatan').toString(),
            judul: (item['judul'] ?? 'Kegiatan Lapangan').toString(),
            lokasi: (item['lokasi'] ?? 'Kawasan Hutan Garut').toString(),
          );
        }
        allReports.add(item);
      }

      final isOfflineToken =
          token.startsWith('offline_') || token.startsWith('google_session_');

      // Ambil cache lokal untuk mencocokkan foto/geolokasi jika server belum mengembalikannya
      final Map<String, Map<String, dynamic>> cachedDraftMap = {};
      final rawDrafts = prefs.getString(_storageKey);
      if (rawDrafts != null && rawDrafts.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(rawDrafts);
          for (final item in decoded) {
            final map = Map<String, dynamic>.from(item);
            final idKey = (map['id'] ?? '').toString();
            final titleKey = (map['judul'] ?? '').toString().toLowerCase();
            if (idKey.isNotEmpty) cachedDraftMap[idKey] = map;
            if (titleKey.isNotEmpty) cachedDraftMap[titleKey] = map;
          }
        } catch (_) {}
      }

      // 1. Load offline/local reports from local SQLite DB
      final localReports = isOfflineToken
          ? await OfflineDatabase.instance.getAllLocalReports()
          : await OfflineDatabase.instance.getPendingReports();
      for (final local in localReports) {
        final String activityDate = local['activity_date']?.toString() ?? '';
        final String rawStatus = local['status']?.toString() ?? 'draft';
        final String photoVal =
            (local['photo_base64'] ?? local['photo_path'] ?? '').toString();
        final monData = MonitoringCalculator.extractMonitoringMap(local);
        final bool isMon = MonitoringCalculator.isMonitoringReportType(
          local['jenis_laporan']?.toString(),
          local['report_type']?.toString(),
        );

        addUniqueReport({
          'id': 'local_${local['id']}',
          'judul': local['title'] ?? 'Laporan tanpa judul',
          'jenis': isMon
              ? 'Laporan Monitoring'
              : (local['jenis_laporan'] ?? 'Laporan Kegiatan'),
          'report_type': isMon ? 'monitoring' : (local['report_type'] ?? 'standard'),
          'pelapor': defaultUserName,
          'tanggal': LaporanDateUtils.formatApiDate(activityDate),
          'tanggalApi': activityDate,
          'lokasi': local['location'] ?? 'Belum diisi',
          'alamatGeolokasi': (local['address'] ?? local['location'] ?? '')
              .toString(),
          'isi': local['description'] ?? '',
          'latitude': local['latitude']?.toString() ?? '',
          'longitude': local['longitude']?.toString() ?? '',
          'foto': photoVal,
          'photo_base64': local['photo_base64'] ?? '',
          'photos': photoVal.isNotEmpty
              ? [
                  {
                    'local_path': local['photo_path'],
                    'photo_base64': local['photo_base64'],
                    'latitude': local['latitude'],
                    'longitude': local['longitude'],
                    'address': local['address'],
                  },
                ]
              : <dynamic>[],
          'localPhotoPath': local['photo_path'],
          'status': LaporanDateUtils.displayStatus(rawStatus),
          'statusApi': rawStatus,
          'isOffline': true,
          'syncStatus': local['sync_status'],
          'localId': local['id'],
          ...monData,
          if (monData.isNotEmpty) 'monitoring_data': monData,
        });
      }

      // RENDER CEPAT: Tampilkan laporan lokal/drafts segera (<10ms) tanpa menunggu request jaringan
      if (mounted && allReports.isNotEmpty && _laporanList.isEmpty) {
        setState(() {
          _laporanList
            ..clear()
            ..addAll(allReports);
          _isLoadingReports = false;
        });
      }

      // 2. Load server reports if online and using a real authenticated server token
      final online = await ConnectivityService.instance.isOnline();
      if (online && !isOfflineToken) {
        try {
          final serverReports = await LaporanService.fetchReports(
            token,
            forceRefresh: forceRefresh,
          );
          if (!mounted || myToken != _loadRequestToken) return;
          for (final sr in serverReports) {
            final idStr = (sr['id'] ?? '').toString();
            final titleLower = (sr['judul'] ?? '').toString().toLowerCase();
            final localMatch =
                cachedDraftMap[idStr] ?? cachedDraftMap[titleLower];

            String resolvedFoto = (sr['foto'] ?? '').toString();
            if (resolvedFoto.isEmpty && localMatch != null) {
              resolvedFoto =
                  (localMatch['foto'] ??
                          localMatch['photo_base64'] ??
                          localMatch['localPhotoPath'] ??
                          '')
                      .toString();
            }

            addUniqueReport({
              ...sr,
              'pelapor': sr['pelapor'] ?? sr['userName'] ?? defaultUserName,
              'foto': resolvedFoto,
              'photo_base64':
                  (sr['photo_base64']?.toString().isNotEmpty == true)
                  ? sr['photo_base64']
                  : (localMatch?['photo_base64'] ?? ''),
              'localPhotoPath': localMatch?['localPhotoPath'],
              'alamatGeolokasi':
                  (sr['alamatGeolokasi']?.toString().isNotEmpty == true)
                  ? sr['alamatGeolokasi']
                  : (localMatch?['alamatGeolokasi'] ?? sr['lokasi'] ?? ''),
            });
          }
        } on UnauthorizedException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message),
                action: SnackBarAction(
                  label: 'Login Ulang',
                  textColor: Colors.amberAccent,
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('LaporanService fetch reports warning: $e');
          _loadErrorMessage = LaporanService.friendlyErrorMessage(e);

          // Offline-First Fallback: muat semua laporan lokal dari SQLite jika server timeout/gagal
          try {
            final fallbackLocals = await OfflineDatabase.instance.getAllLocalReports();
            for (final local in fallbackLocals) {
              final String activityDate = local['activity_date']?.toString() ?? '';
              final String rawStatus = local['status']?.toString() ?? 'draft';
              final String photoVal =
                  (local['photo_base64'] ?? local['photo_path'] ?? '').toString();
              final monData = MonitoringCalculator.extractMonitoringMap(local);
              final bool isMon = MonitoringCalculator.isMonitoringReportType(
                local['jenis_laporan']?.toString(),
                local['report_type']?.toString(),
              );
              addUniqueReport({
                'id': 'local_${local['id']}',
                'judul': local['title'] ?? 'Laporan tanpa judul',
                'jenis': isMon
                    ? 'Laporan Monitoring'
                    : (local['jenis_laporan'] ?? 'Laporan Kegiatan'),
                'report_type': isMon ? 'monitoring' : (local['report_type'] ?? 'standard'),
                'pelapor': defaultUserName,
                'tanggal': LaporanDateUtils.formatApiDate(activityDate),
                'tanggalApi': activityDate,
                'lokasi': local['location'] ?? 'Belum diisi',
                'alamatGeolokasi': (local['address'] ?? local['location'] ?? '').toString(),
                'isi': local['description'] ?? '',
                'latitude': local['latitude']?.toString() ?? '',
                'longitude': local['longitude']?.toString() ?? '',
                'foto': photoVal,
                'photo_base64': local['photo_base64'] ?? '',
                'localPhotoPath': local['photo_path'],
                'photos': <dynamic>[],
                'status': LaporanDateUtils.displayStatus(rawStatus),
                'statusApi': rawStatus,
                'isOffline': true,
                'syncStatus': local['sync_status'],
                'localId': local['id'],
                ...monData,
                if (monData.isNotEmpty) 'monitoring_data': monData,
              });
            }
          } catch (_) {}
        }
      }

      // 3. Load cached drafts & user reports from SharedPreferences
      if (rawDrafts != null && rawDrafts.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(rawDrafts);
          for (final item in decoded) {
            final map = Map<String, dynamic>.from(item);
            if (!allReports.any(
              (r) =>
                  r['id'].toString() == map['id'].toString() ||
                  (r['judul'] == map['judul'] &&
                      r['tanggal'] == map['tanggal']),
            )) {
              addUniqueReport({
                'id': map['id'] ?? 'draft_${allReports.length}',
                'judul': map['judul'] ?? 'Laporan Kegiatan',
                'jenis': map['jenis'] ?? 'Laporan Penyuluhan',
                'pelapor': map['pelapor'] ?? map['userName'] ?? defaultUserName,
                'tanggal': map['tanggal'] ?? '-',
                'tanggalApi': map['tanggalApi'] ?? '',
                'lokasi': map['lokasi'] ?? '-',
                'alamatGeolokasi':
                    map['alamatGeolokasi'] ?? map['lokasi'] ?? '',
                'isi': map['isi'] ?? '',
                'latitude': map['latitude']?.toString() ?? '',
                'longitude': map['longitude']?.toString() ?? '',
                'foto': map['foto'] ?? map['photo_base64'] ?? '',
                'photo_base64': map['photo_base64'] ?? '',
                'localPhotoPath': map['localPhotoPath'],
                'photos': map['photos'] ?? <dynamic>[],
                'status': map['status'] ?? 'Draft',
                'isOffline': map['isOffline'] ?? false,
                'localId': map['localId'],
              });
            }
          }
        } catch (_) {}
      }

      // 4. Jika dalam mode Admin, muat juga laporan pegawai dari arsip bersama (tanpa koordinat hardcode)
      if (_isAdmin) {
        final rawArchives = prefs.getString(_archiveStorageKey);
        if (rawArchives != null && rawArchives.isNotEmpty) {
          try {
            final List<dynamic> arcList = jsonDecode(rawArchives);
            for (final a in arcList) {
              final map = Map<String, dynamic>.from(a);
              if (map['tipe'] == 'Laporan') {
                final judul = (map['judul'] ?? 'Laporan Kegiatan').toString();
                if (!allReports.any((r) => r['judul'] == judul)) {
                  addUniqueReport({
                    'id': map['id'] ?? 'arc_${allReports.length}',
                    'judul': judul,
                    'jenis': _normalizeReportTypeName(
                      (map['kategori'] ?? 'Laporan Penyuluhan').toString(),
                    ),
                    'pelapor': (map['userName'] ?? 'Penyuluh Kehutanan')
                        .toString(),
                    'tanggal': (map['tanggal'] ?? '-').toString(),
                    'tanggalApi': '',
                    'lokasi': (map['wilayah'] ?? '-').toString(),
                    'alamatGeolokasi':
                        (map['alamatGeolokasi'] ?? map['wilayah'] ?? '')
                            .toString(),
                    'isi': (map['deskripsi'] ?? '').toString(),
                    'latitude': (map['latitude'] ?? '').toString(),
                    'longitude': (map['longitude'] ?? '').toString(),
                    'foto': (map['foto'] ?? map['photo_base64'] ?? '')
                        .toString(),
                    'photo_base64': (map['photo_base64'] ?? '').toString(),
                    'photos': map['photos'] ?? <dynamic>[],
                    'status': (map['status'] ?? 'Selesai').toString(),
                    'isOffline': false,
                  });
                }
              }
            }
          } catch (_) {}
        }
      }

      if (!mounted || myToken != _loadRequestToken) return;
      setState(() {
        _laporanList
          ..clear()
          ..addAll(allReports);
        _isLoadingReports = false;
      });

      await _updatePendingCount();
      _checkAndOpenInitialReport();
    } catch (e) {
      if (!mounted) return;

      try {
        final localReports = await OfflineDatabase.instance
            .getAllLocalReports();
        final List<Map<String, dynamic>> offlineList = [];

        for (final local in localReports) {
          final String activityDate = local['activity_date']?.toString() ?? '';
          final String rawStatus = local['status']?.toString() ?? 'draft';
          final String photoVal =
              (local['photo_base64'] ?? local['photo_path'] ?? '').toString();
          final monData = MonitoringCalculator.extractMonitoringMap(local);
          final bool isMon = MonitoringCalculator.isMonitoringReportType(
            local['jenis_laporan']?.toString(),
            local['report_type']?.toString(),
          );

          offlineList.add({
            'id': 'local_${local['id']}',
            'judul': local['title'] ?? 'Laporan tanpa judul',
            'jenis': isMon
                ? 'Laporan Monitoring'
                : (local['jenis_laporan'] ?? 'Laporan Kegiatan'),
            'report_type': isMon ? 'monitoring' : (local['report_type'] ?? 'standard'),
            'pelapor': 'Penyuluh Kehutanan',
            'tanggal': LaporanDateUtils.formatApiDate(activityDate),
            'tanggalApi': activityDate,
            'lokasi': local['location'] ?? 'Belum diisi',
            'alamatGeolokasi': (local['address'] ?? local['location'] ?? '')
                .toString(),
            'isi': local['description'] ?? '',
            'latitude': local['latitude']?.toString() ?? '',
            'longitude': local['longitude']?.toString() ?? '',
            'foto': photoVal,
            'photo_base64': local['photo_base64'] ?? '',
            'localPhotoPath': local['photo_path'],
            'photos': <dynamic>[],
            'status': LaporanDateUtils.displayStatus(rawStatus),
            'statusApi': rawStatus,
            'isOffline': true,
            'syncStatus': local['sync_status'],
            'localId': local['id'],
            ...monData,
            if (monData.isNotEmpty) 'monitoring_data': monData,
          });
        }

        if (!mounted) return;
        setState(() {
          _laporanList
            ..clear()
            ..addAll(offlineList);
          _isLoadingReports = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() => _isLoadingReports = false);
        }
      }
    }
  }

  /// Jika halaman Laporan dibuka melalui klik Notifikasi dengan ID laporan tertentu,
  /// otomatis tampilkan detail laporan yang bersangkutan.
  void _checkAndOpenInitialReport() {
    if (_hasOpenedInitialReport) return;
    final targetId = widget.initialReportId?.trim() ?? '';
    final targetTitle = widget.initialReportTitle?.trim().toLowerCase() ?? '';
    if (targetId.isEmpty && targetTitle.isEmpty) return;

    final cleanTargetId = targetId.replaceFirst('report_', '');

    Map<String, dynamic>? matched;
    for (final item in _laporanList) {
      final itemId = (item['id'] ?? '').toString();
      final itemTitle = (item['judul'] ?? '').toString().toLowerCase();
      if ((cleanTargetId.isNotEmpty &&
              (itemId == cleanTargetId ||
                  itemId == targetId ||
                  itemId == 'local_$cleanTargetId')) ||
          (targetTitle.isNotEmpty && itemTitle == targetTitle)) {
        matched = item;
        break;
      }
    }

    if (matched != null) {
      _hasOpenedInitialReport = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showReportDetail(
            context,
            laporan: matched!,
            onEdit: _openReportForm,
            onDownload: _downloadReport,
            isAdmin: _isAdmin,
            onUpdateStatus: _isAdmin ? _updateMonitoredReportStatus : null,
          );
        }
      });
    }
  }

  String _normalizeReportTypeName(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('trk') || lower.contains('rehab')) {
      return 'Laporan TRK';
    }
    if (lower.contains('monitor') || lower.contains('patroli')) {
      return 'Laporan Monitoring';
    }
    if (lower.contains('kejadian') || lower.contains('darurat')) {
      return 'Laporan Kejadian';
    }
    if (lower.contains('kegiatan')) {
      return 'Laporan Kegiatan';
    }
    return 'Laporan Penyuluhan';
  }

  Future<void> _persistReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_laporanList));
  }

  // ---------------------------------------------------------------------------
  // Actions (User & Admin)
  // ---------------------------------------------------------------------------

  Future<void> _handleReportSavedFromForm() async {
    await _loadSavedReports();
    if (!mounted) return;
    setState(() {
      _selectedTab = 0;
      _highlightLatestCard = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final arsipCtx = _arsipSectionKey.currentContext;
      if (arsipCtx != null) {
        Scrollable.ensureVisible(
          arsipCtx,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      } else if (_userScrollController.hasClients) {
        _userScrollController.animateTo(
          _userScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
        );
      }
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _highlightLatestCard = false);
      }
    });
  }

  void _openReportForm(
    String jenisLaporan, {
    Map<String, dynamic>? existing,
    bool isPreviewOnly = false,
  }) {
    showReportForm(
      context,
      jenisLaporan: jenisLaporan,
      existing: existing,
      onReportSaved: _handleReportSavedFromForm,
      isPreviewOnly: isPreviewOnly,
    );
  }

  Future<void> _openAdminTemplateEditor({
    Map<String, dynamic>? existingTemplate,
  }) async {
    await showAdminTemplateEditor(
      context,
      existingTemplate: existingTemplate,
      onSaved: (savedTemplate) async {
        final current = await ReportTemplateManager.loadTemplates();
        final idx = current.indexWhere((t) => t['id'] == savedTemplate['id']);
        if (idx >= 0) {
          current[idx] = savedTemplate;
        } else {
          current.add(savedTemplate);
        }
        await ReportTemplateManager.saveTemplates(current);
        await _reloadTemplates();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Template "${savedTemplate['title']}" berhasil disimpan untuk pegawai.',
            ),
            backgroundColor: const Color(0xFF245C3A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _deleteTemplate(Map<String, dynamic> template) async {
    if (_templatesList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus terdapat 1 template laporan aktif.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus Template Laporan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus template "${template['title']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final updated = _templatesList
        .where((t) => t['id'] != template['id'])
        .toList();
    await ReportTemplateManager.saveTemplates(updated);
    await _reloadTemplates();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template "${template['title']}" telah dihapus.')),
    );
  }

  Future<void> _updateMonitoredReportStatus(
    Map<String, dynamic> laporan,
    String newStatus,
  ) async {
    setState(() {
      final idx = _laporanList.indexWhere((r) => r['id'] == laporan['id']);
      if (idx >= 0) {
        _laporanList[idx]['status'] = newStatus;
      }
    });
    await _persistReports();

    final prefs = await SharedPreferences.getInstance();
    final rawArc = prefs.getString(_archiveStorageKey);
    if (rawArc != null && rawArc.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawArc);
        final updatedArc = list.map((e) {
          final map = Map<String, dynamic>.from(e);
          if (map['id'] == laporan['id'] || map['judul'] == laporan['judul']) {
            map['status'] = newStatus;
          }
          return map;
        }).toList();
        await prefs.setString(_archiveStorageKey, jsonEncode(updatedArc));
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status laporan "${laporan['judul']}" diperbarui menjadi $newStatus.',
        ),
        backgroundColor: const Color(0xFF245C3A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadReport(Map<String, dynamic> laporan) {
    showReportDownloadSheet(context, laporan: laporan);
  }

  Future<void> _deleteReport(Map<String, dynamic> laporan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
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

    final isOffline = laporan['isOffline'] == true;

    if (isOffline && laporan['localId'] is int) {
      try {
        final localId = laporan['localId'] as int;
        await OfflineDatabase.instance.deleteLocalReport(localId);

        if (!mounted) return;
        setState(() {
          _laporanList.removeWhere((item) => item['id'] == laporan['id']);
        });
        await _persistReports();
        await _updatePendingCount();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Laporan offline "${laporan['judul']}" berhasil dihapus.',
            ),
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null &&
          token.isNotEmpty &&
          !token.startsWith('offline_') &&
          !token.startsWith('google_session_') &&
          int.tryParse(laporan['id'].toString()) != null) {
        await LaporanService.deleteReport(token, laporan['id']);
      }

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
      setState(() {
        _laporanList.removeWhere((item) => item['id'] == laporan['id']);
      });
      await _persistReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan "${laporan['judul']}" dihapus dari daftar.'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? const Color(0xFF18221B) : Colors.white;
    final titleColor = isDark ? Colors.white : LaporanColors.textDark;
    final primaryGreen = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF245C3A);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          _isAdmin ? 'Template & Monitoring Laporan' : 'Laporan',
          style: TextStyle(
            color: titleColor,
            fontSize: _isAdmin ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: primaryGreen),
        actions: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _openAdminTemplateEditor(),
                icon: Icon(
                  Icons.upload_file_rounded,
                  size: 18,
                  color: primaryGreen,
                ),
                label: Text(
                  'Upload Contoh / Template',
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          if (_pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _isSyncing || _isOffline ? null : _autoSync,
                tooltip: _isOffline
                    ? 'Tidak ada koneksi'
                    : 'Sinkronkan $_pendingSyncCount laporan',
                icon: _isSyncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryGreen,
                        ),
                      )
                    : Badge(
                        label: Text('$_pendingSyncCount'),
                        child: Icon(Icons.sync_rounded, color: primaryGreen),
                      ),
              ),
            ),
          IconButton(
            onPressed: () => _loadSavedReports(forceRefresh: true),
            tooltip: 'Segarkan Laporan',
            icon: Icon(Icons.refresh_rounded, color: primaryGreen),
          ),
        ],
      ),
      body: SafeArea(
        child: _isAdmin
            ? _buildAdminLaporanBody(isDark, titleColor, primaryGreen)
            : _buildUserLaporanBody(isDark, titleColor),
      ),
    );
  }

  // ===========================================================================
  // TAMPILAN KHUSUS ADMIN: KELOLA TEMPLATE LAPORAN & MONITORING LAPORAN USER
  // ===========================================================================

  Widget _buildAdminLaporanBody(
    bool isDark,
    Color titleColor,
    Color primaryGreen,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPad = screenWidth >= 760 ? 28.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B462B),
                  Color(0xFF245C3A),
                  Color(0xFF4F8A5B),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF245C3A).withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.edit_document,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Template & Monitoring Laporan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Unggah file contoh laporan untuk dikonversi otomatis menjadi template, atur bagian isian pegawai, dan pantau seluruh laporan masuk.',
                        style: TextStyle(
                          color: Color(0xFFE8F2E8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openAdminTemplateEditor(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2822) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2E3D34)
                      : LaporanColors.borderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF26352B)
                          : const Color(0xFFE8F2E8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.upload_file_rounded,
                      color: primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kirim File Contoh Laporan & Buat Template',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Masukkan file contoh laporan (.docx / .pdf / .txt) untuk diekstrak menjadi template dan sesuaikan form yang harus diisi user.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: primaryGreen,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E2822)
                  : LaporanColors.tabBackground,
              borderRadius: BorderRadius.circular(14),
              border: isDark
                  ? Border.all(color: const Color(0xFF2E3D34))
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AdminTabSwitchItem(
                    title: 'Template Laporan (${_templatesList.length})',
                    icon: Icons.edit_document,
                    isActive: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                Expanded(
                  child: _AdminTabSwitchItem(
                    title: 'Monitoring Laporan (${_laporanList.length})',
                    icon: Icons.assignment_turned_in_outlined,
                    isActive: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedTab == 0)
            _buildAdminTemplatesSection(isDark, titleColor, primaryGreen)
          else
            _buildAdminMonitoringSection(isDark, titleColor, primaryGreen),
        ],
      ),
    );
  }

  Widget _buildAdminTemplatesSection(
    bool isDark,
    Color titleColor,
    Color primaryGreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Template per Jenis Laporan',
          style: TextStyle(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih jenis laporan untuk mengunggah file contoh laporan atau menyesuaikan bagian form yang wajib diisi pegawai.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 14),
        ReportTemplates(
          isAdmin: true,
          templates: _templatesList,
          onSelectTemplate: (jenis) =>
              _openReportForm(jenis, isPreviewOnly: true),
          onEditTemplate: (tpl) =>
              _openAdminTemplateEditor(existingTemplate: tpl),
          onPreviewTemplate: (tpl) => _openReportForm(
            (tpl['title'] ?? 'Laporan Kegiatan').toString(),
            isPreviewOnly: true,
          ),
          onDeleteTemplate: _deleteTemplate,
        ),
      ],
    );
  }

  Widget _buildAdminMonitoringSection(
    bool isDark,
    Color titleColor,
    Color primaryGreen,
  ) {
    final totalCount = _laporanList.length;
    final selesaiCount = _laporanList
        .where((r) => r['status'] == 'Selesai')
        .length;
    final diprosesCount = _laporanList
        .where((r) => r['status'] == 'Diproses')
        .length;
    final draftCount = _laporanList.where((r) => r['status'] == 'Draft').length;

    final jenisFilters = <String>[
      'Semua',
      ..._templatesList
          .map((t) => (t['title'] ?? '').toString())
          .where((s) => s.isNotEmpty),
    ];

    final filtered = _laporanList.where((item) {
      if (_adminFilterJenis != 'Semua') {
        final itemJenis = (item['jenis'] ?? '').toString().toLowerCase();
        if (!itemJenis.contains(_adminFilterJenis.toLowerCase()) &&
            !_adminFilterJenis.toLowerCase().contains(itemJenis)) {
          return false;
        }
      }
      if (_adminFilterStatus != 'Semua') {
        if ((item['status'] ?? '').toString().toLowerCase() !=
            _adminFilterStatus.toLowerCase()) {
          return false;
        }
      }
      if (_adminSearchQuery.trim().isEmpty) return true;
      final q = _adminSearchQuery.toLowerCase();
      return (item['judul'] ?? '').toString().toLowerCase().contains(q) ||
          (item['pelapor'] ?? '').toString().toLowerCase().contains(q) ||
          (item['lokasi'] ?? '').toString().toLowerCase().contains(q) ||
          (item['jenis'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MonitoringStatMiniCard(
                label: 'Total',
                count: '$totalCount',
                color: const Color(0xFF245C3A),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MonitoringStatMiniCard(
                label: 'Selesai',
                count: '$selesaiCount',
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MonitoringStatMiniCard(
                label: 'Diproses',
                count: '$diprosesCount',
                color: const Color(0xFFB26A00),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MonitoringStatMiniCard(
                label: 'Draft',
                count: '$draftCount',
                color: const Color(0xFF546E7A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (val) => setState(() => _adminSearchQuery = val),
          style: TextStyle(color: titleColor, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Cari judul laporan, nama pegawai, jenis laporan, atau lokasi...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: primaryGreen),
            suffixIcon: _adminSearchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () => setState(() => _adminSearchQuery = ''),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E2822) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2E3D34)
                    : LaporanColors.borderCard,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2E3D34)
                    : LaporanColors.borderCard,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: jenisFilters.map((jf) {
              final selected = _adminFilterJenis == jf;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(jf),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF245C3A),
                  backgroundColor: isDark
                      ? const Color(0xFF1E2822)
                      : Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : titleColor,
                  ),
                  onSelected: (_) => setState(() => _adminFilterJenis = jf),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Semua', 'Selesai', 'Diproses', 'Draft'].map((sf) {
              final selected = _adminFilterStatus == sf;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Status: $sf'),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF4F8A5B),
                  backgroundColor: isDark
                      ? const Color(0xFF1E2822)
                      : Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : titleColor,
                  ),
                  onSelected: (_) => setState(() => _adminFilterStatus = sf),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingReports)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF245C3A)),
            ),
          )
        else if (filtered.isEmpty)
          const LaporanEmptyState()
        else
          ...filtered.map(
            (laporan) => _buildAdminMonitoredReportCard(
              laporan,
              isDark: isDark,
              titleColor: titleColor,
              primaryGreen: primaryGreen,
            ),
          ),
      ],
    );
  }

  Widget _buildAdminMonitoredReportCard(
    Map<String, dynamic> laporan, {
    required bool isDark,
    required Color titleColor,
    required Color primaryGreen,
  }) {
    final pelapor =
        (laporan['pelapor'] ?? laporan['userName'] ?? 'Penyuluh Kehutanan')
            .toString();
    final jenis = (laporan['jenis'] ?? 'Laporan Kegiatan').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 6, left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF233829) : const Color(0xFFE8F2E8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_pin_circle_outlined,
                size: 15,
                color: primaryGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'Pegawai: $pelapor • $jenis',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
        ),
        ReportCard(
          laporan: laporan,
          onView: () => showReportDetail(
            context,
            laporan: laporan,
            onEdit: _openReportForm,
            onDownload: _downloadReport,
            isAdmin: true,
            onUpdateStatus: _updateMonitoredReportStatus,
          ),
          onEdit: () => showReportDetail(
            context,
            laporan: laporan,
            onEdit: _openReportForm,
            onDownload: _downloadReport,
            isAdmin: true,
            onUpdateStatus: _updateMonitoredReportStatus,
          ),
          onDownload: () => _downloadReport(laporan),
          onDelete: () => _deleteReport(laporan),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAMPILAN USER (PEGAWAI): BUAT LAPORAN BERDASARKAN TEMPLATE & UNDUH PDF
  // ===========================================================================

  Widget _buildUserLaporanBody(bool isDark, Color titleColor) {
    return SingleChildScrollView(
      controller: _userScrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOffline) _buildOfflineBanner(),
          if (!_isOffline && _pendingSyncCount > 0) _buildPendingSyncBanner(),
          const SizedBox(height: 20),
          const LaporanHeader(),
          const SizedBox(height: 24),
          CreateReportCard(
            onTap: () =>
                showReportTypeDialog(context, onSelectType: _openReportForm),
          ),
          const SizedBox(height: 28),
          Column(
            key: _arsipSectionKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arsip Laporan',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Draft yang masih bisa diedit dan laporan selesai beserta foto geolokasi yang siap diunduh (PDF/Word).',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey,
                  fontSize: 13.5,
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
              templates: _templatesList,
              onSelectTemplate: _openReportForm,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Offline / Sync banners
  // ---------------------------------------------------------------------------

  Widget _buildOfflineBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF332005) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF66440A) : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: isDark ? const Color(0xFFFFB74D) : Colors.orange.shade700,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFFB74D)
                        : Colors.orange.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tidak ada koneksi internet. Laporan & foto geolokasi akan '
                  'disimpan di perangkat dan otomatis dikirim '
                  'saat koneksi kembali.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.orange.shade700,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2537) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E496D) : const Color(0xFF90CAF9),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            color: isDark ? const Color(0xFF64B5F6) : Colors.blue.shade700,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$_pendingSyncCount laporan menunggu sinkronisasi.',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.blue.shade800,
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
                backgroundColor: isDark
                    ? const Color(0xFF1976D2)
                    : Colors.blue.shade700,
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
  // Report history list (User)
  // ---------------------------------------------------------------------------

  Widget _buildReportHistory() {
    if (_isLoadingReports) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF245C3A)),
        ),
      );
    }

    if (_laporanList.isEmpty && _loadErrorMessage != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2822) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3D34) : LaporanColors.borderCard,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 46,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal Memuat Laporan dari Server',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : LaporanColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loadErrorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _loadSavedReports(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_laporanList.isEmpty) {
      return const LaporanEmptyState();
    }

    return Column(
      children: [
        if (_loadErrorMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Menampilkan data lokal. $_loadErrorMessage',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _loadSavedReports(forceRefresh: true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Coba Lagi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ..._laporanList.asMap().entries.map((entry) {
        final index = entry.key;
        final laporan = entry.value;
        final isHighlighted = index == 0 && _highlightLatestCard;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(bottom: isHighlighted ? 6 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: const Color(0xFF245C3A).withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ReportCard(
            laporan: laporan,
            onView: () => showReportDetail(
              context,
              laporan: laporan,
              onEdit: _openReportForm,
              onDownload: _downloadReport,
            ),
            onEdit: () => _openReportForm(
              (laporan['jenis'] ?? 'Laporan Kegiatan').toString(),
              existing: laporan,
            ),
            onDownload: () => _downloadReport(laporan),
            onDelete: () => _deleteReport(laporan),
          ),
        );
      }),
      ],
    );
  }
}

class _AdminTabSwitchItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _AdminTabSwitchItem({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF26352B) : Colors.white;
    final activeColor = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF245C3A);
    final inactiveColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? activeColor : inactiveColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitoringStatMiniCard extends StatelessWidget {
  final String label;
  final String count;
  final Color color;

  const _MonitoringStatMiniCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D34) : LaporanColors.borderCard,
        ),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
