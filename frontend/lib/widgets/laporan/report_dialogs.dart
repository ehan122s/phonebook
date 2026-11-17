import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/api_constants.dart';
import '../../constants/laporan_constants.dart';
import '../../services/connectivity_service.dart';
import '../../services/laporan_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import 'report_templates.dart';

// ---------------------------------------------------------------------------
// 0. Notifikasi Overlay di Bagian Depan (Tampil di Atas Modal Bottom Sheet)
// ---------------------------------------------------------------------------

OverlayEntry? _activeTopNotificationEntry;

void showTopFrontNotification(
  BuildContext context, {
  required String message,
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  try {
    _activeTopNotificationEntry?.remove();
    _activeTopNotificationEntry = null;
  } catch (_) {}

  final overlay =
      Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
  if (overlay == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade700
            : const Color(0xFF245C3A),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _TopFrontNotificationBanner(
      message: message,
      isError: isError,
      duration: duration,
      onDismissed: () {
        if (_activeTopNotificationEntry == entry) {
          try {
            entry.remove();
          } catch (_) {}
          _activeTopNotificationEntry = null;
        }
      },
    ),
  );

  _activeTopNotificationEntry = entry;
  overlay.insert(entry);
}

class _TopFrontNotificationBanner extends StatefulWidget {
  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback onDismissed;

  const _TopFrontNotificationBanner({
    required this.message,
    required this.isError,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_TopFrontNotificationBanner> createState() =>
      _TopFrontNotificationBannerState();
}

class _TopFrontNotificationBannerState
    extends State<_TopFrontNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scaleAnim = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing || !mounted) return;
    _closing = true;
    try {
      await _controller.reverse();
    } catch (_) {}
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 14;
    final bgColor = widget.isError
        ? const Color(0xFFC62828)
        : const Color(0xFF1E5631);

    return Positioned(
      top: topPad,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Dismissible(
                    key: const ValueKey('top_front_notif'),
                    direction: DismissDirection.up,
                    onDismissed: (_) => widget.onDismissed(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isError
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _dismiss,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Bottom Sheet Pemilihan Jenis Laporan
// ---------------------------------------------------------------------------

Future<void> showReportTypeDialog(
  BuildContext context, {
  required void Function(String jenisLaporan, {Map<String, dynamic>? existing})
  onSelectType,
}) async {
  final templates = await ReportTemplateManager.loadTemplates();
  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final textColor = isDark ? Colors.white : const Color(0xFF24352A);
      final subColor = isDark ? Colors.white70 : Colors.grey.shade600;

      return SafeArea(
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DragHandle(),
                    const SizedBox(height: 18),
                    Text(
                      'Pilih Jenis Laporan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih template laporan yang telah disiapkan sesuai kegiatan Anda.',
                      style: TextStyle(color: subColor, fontSize: 13.5),
                    ),
                    const SizedBox(height: 18),
                    ...templates.map((tpl) {
                      final title = (tpl['title'] ?? 'Laporan Kegiatan')
                          .toString();
                      final desc = (tpl['description'] ?? '').toString();
                      final icon = ReportTemplateManager.iconFromKey(
                        tpl['iconKey']?.toString(),
                      );
                      return _TypeOption(
                        icon: icon,
                        title: title,
                        subtitle: desc,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelectType(title);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 2. Formulir Pengisian Laporan (Integrasi Kamera, GPS, Reverse Geocoding & Foto Lokasi)
// ---------------------------------------------------------------------------

Future<void> showReportForm(
  BuildContext context, {
  required String jenisLaporan,
  Map<String, dynamic>? existing,
  required Future<void> Function() onReportSaved,
  bool isPreviewOnly = false,
}) async {
  final template = await ReportTemplateManager.findByTitle(jenisLaporan);
  if (!context.mounted) return;

  final List<String> templateFields =
      (template['fields'] as List?)?.map((e) => e.toString()).toList() ?? [];
  final String defaultTitle = (template['defaultTitle'] ?? '').toString();
  final String templateDescription =
      (template['description'] ??
              'Lengkapi bagian-bagian laporan sesuai kegiatan di lapangan.')
          .toString();
  final bool requirePhoto = template['requirePhoto'] != false;

  final now = DateTime.now();
  final initialDateIso =
      (existing?['tanggalApi']?.toString().isNotEmpty ?? false)
      ? existing!['tanggalApi'].toString()
      : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  DateTime selectedDate = DateTime.tryParse(initialDateIso) ?? now;

  final judulCtrl = TextEditingController(
    text:
        existing?['judul']?.toString() ??
        (defaultTitle.isNotEmpty ? defaultTitle : ''),
  );
  final lokasiCtrl = TextEditingController(
    text: existing?['lokasi']?.toString() ?? '',
  );
  final latCtrl = TextEditingController(
    text: existing?['latitude']?.toString() ?? '',
  );
  final lngCtrl = TextEditingController(
    text: existing?['longitude']?.toString() ?? '',
  );
  String reverseGeocodedAddress = (existing?['alamatGeolokasi'] ?? '')
      .toString();

  final Map<String, TextEditingController> fieldControllers = {
    for (final field in templateFields) field: TextEditingController(),
  };

  final rawExistingIsi = existing?['isi']?.toString() ?? '';
  final existingIsi =
      ReportTemplateManager.isCorruptedBinaryText(rawExistingIsi)
      ? ''
      : rawExistingIsi;
  final isiCtrl = TextEditingController(
    text: existingIsi.isNotEmpty
        ? existingIsi
        : ReportTemplateManager.buildFormattedBody(
            template: template,
            fieldValues: const {},
          ),
  );

  void syncTemplateFieldsToIsi() {
    final values = <String, String>{
      for (final entry in fieldControllers.entries) entry.key: entry.value.text,
    };
    isiCtrl.text = ReportTemplateManager.buildFormattedBody(
      template: template,
      fieldValues: values,
    );
  }

  XFile? pickedPhotoFile;
  Uint8List? pickedPhotoBytes;
  String? existingPhotoUrl;
  if (existing != null) {
    final rawFoto = (existing['foto'] ?? existing['photo_base64'] ?? '')
        .toString()
        .trim();
    if (rawFoto.isNotEmpty) {
      existingPhotoUrl =
          rawFoto.startsWith('http') ||
              rawFoto.startsWith('data:') ||
              rawFoto.startsWith('/')
          ? rawFoto
          : '${ApiConstants.baseUrl}/storage/$rawFoto';
    } else if (existing['photos'] is List &&
        (existing['photos'] as List).isNotEmpty) {
      final first = (existing['photos'] as List).first;
      if (first is Map) {
        final b64 = (first['photo_base64'] ?? '').toString().trim();
        final raw =
            (first['url'] ?? first['photo'] ?? first['local_path'] ?? '')
                .toString()
                .trim();
        if (b64.isNotEmpty) {
          existingPhotoUrl = b64.startsWith('data:')
              ? b64
              : 'data:image/jpeg;base64,$b64';
        } else if (first['id'] != null) {
          existingPhotoUrl = ApiConstants.reportPhotoFileUrl(first['id']);
        } else if (raw.isNotEmpty) {
          existingPhotoUrl = raw.startsWith('http') || raw.startsWith('/')
              ? raw
              : '${ApiConstants.baseUrl}/storage/$raw';
        }
      }
    } else if (existing['localPhotoPath'] != null &&
        existing['localPhotoPath'].toString().trim().isNotEmpty) {
      existingPhotoUrl = existing['localPhotoPath'].toString().trim();
    }
  }

  bool isGettingLocation = false;
  bool isProcessingPhoto = false;
  bool isSubmittingForm = false;
  String? locationWarningMessage;
  bool showCoordinateInputs =
      latCtrl.text.isNotEmpty || lngCtrl.text.isNotEmpty;
  final ScrollController formScrollCtrl = ScrollController();
  String? inlineStatusMessage;
  bool inlineStatusIsError = false;

  void scrollFormToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (formScrollCtrl.hasClients) {
        formScrollCtrl.animateTo(
          formScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
          final sheetBg = isDark
              ? const Color(0xFF141C17)
              : const Color(0xFFF6F8F5);
          final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
          final borderCol = isDark
              ? const Color(0xFF2E3D34)
              : const Color(0xFFE2EAE3);
          final primaryGreen = isDark
              ? const Color(0xFF81C784)
              : const Color(0xFF245C3A);
          final textPrimary = isDark ? Colors.white : const Color(0xFF24352A);
          final textSecondary = isDark
              ? Colors.white70
              : const Color(0xFF6E7A72);

          Future<void> pickReportDate() async {
            final picked = await showDatePicker(
              context: sheetContext,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              setModalState(() => selectedDate = picked);
            }
          }

          /// Mengambil titik koordinat GPS perangkat secara nyata + reverse geocoding alamat
          /// tanpa menggunakan koordinat dummy atau statis.
          Future<UserLocationData?> fetchRealGpsLocation({
            bool showSnackBar = true,
          }) async {
            setModalState(() {
              isGettingLocation = true;
              locationWarningMessage = null;
              showCoordinateInputs = true;
            });

            try {
              final loc = await LocationService.instance.refreshLocation();
              if (!sheetContext.mounted) return null;

              if (loc == null) {
                final err =
                    LocationService.instance.errorMessage ??
                    'Layanan lokasi GPS atau izin lokasi belum tersedia di perangkat Anda.';
                setModalState(() {
                  isGettingLocation = false;
                  locationWarningMessage = err;
                });

                if (showSnackBar) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(err),
                      backgroundColor: Colors.orange.shade800,
                      action:
                          (LocationService.instance.status ==
                                  LocationStatus.permissionDeniedForever ||
                              LocationService.instance.status ==
                                  LocationStatus.serviceDisabled)
                          ? SnackBarAction(
                              label: 'Pengaturan',
                              textColor: Colors.white,
                              onPressed: () {
                                if (LocationService.instance.status ==
                                    LocationStatus.serviceDisabled) {
                                  LocationService.instance
                                      .openLocationSettings();
                                } else {
                                  LocationService.instance.openAppSettings();
                                }
                              },
                            )
                          : null,
                    ),
                  );
                }
                return null;
              }

              setModalState(() {
                latCtrl.text = loc.latitude.toStringAsFixed(6);
                lngCtrl.text = loc.longitude.toStringAsFixed(6);
                reverseGeocodedAddress = loc.fullAddress;
                if (lokasiCtrl.text.trim().isEmpty) {
                  lokasiCtrl.text = loc.shortLocationName;
                }
              });

              if (showSnackBar) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Titik GPS berhasil diperoleh: ${loc.shortLocationName} (${loc.coordinatesText})',
                    ),
                    backgroundColor: const Color(0xFF245C3A),
                  ),
                );
              }
              return loc;
            } catch (e) {
              if (sheetContext.mounted) {
                final message = 'Gagal mendapatkan lokasi GPS: $e';
                setModalState(() {
                  locationWarningMessage = message;
                });
                if (showSnackBar) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                }
              }
              return null;
            } finally {
              if (sheetContext.mounted) {
                setModalState(() => isGettingLocation = false);
              }
            }
          }

          /// Mengambil foto langsung dari Kamera atau Galeri, otomatis mengambil koordinat
          /// GPS perangkat ketika foto diambil, serta membubuhkan informasi lokasi pada foto.
          Future<void> captureOrPickPhotoWithGeolocation({
            ImageSource? explicitSource,
          }) async {
            ImageSource? source = explicitSource;
            source ??= await showModalBottomSheet<ImageSource>(
              context: sheetContext,
              backgroundColor: cardBg,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              builder: (pickerCtx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _DragHandle(),
                      const SizedBox(height: 18),
                      Text(
                        'Ambil Foto Lokasi (Geolocator)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Foto akan otomatis dilengkapi koordinat GPS (Latitude & Longitude) serta alamat lokasi saat diambil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: LaporanColors.primary.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: primaryGreen,
                          ),
                        ),
                        title: Text(
                          'Ambil Foto Kamera + GPS Lokasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Ambil foto langsung di lapangan & rekam titik GPS otomatis',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        onTap: () =>
                            Navigator.pop(pickerCtx, ImageSource.camera),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.photo_library_rounded,
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(
                          'Pilih Foto dari Galeri Perangkat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Pilih foto dokumentasi dari galeri & sertakan titik lokasi saat ini',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        onTap: () =>
                            Navigator.pop(pickerCtx, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (source == null) return;

            try {
              final picker = ImagePicker();
              XFile? picked;

              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.linux &&
                  source == ImageSource.camera) {
                picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
              } else {
                try {
                  picked = await picker.pickImage(
                    source: source,
                    imageQuality: 85,
                    maxWidth: 1600,
                  );
                } on PlatformException {
                  if (source == ImageSource.camera) {
                    picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                  } else {
                    rethrow;
                  }
                }
              }

              if (picked == null) return;
              final selectedPhoto = picked;

              setModalState(() => isProcessingPhoto = true);

              final rawBytes = await picked.readAsBytes();

              // Ambil koordinat GPS nyata saat foto diambil
              UserLocationData? gpsData = await fetchRealGpsLocation(
                showSnackBar: false,
              );
              gpsData ??= LocationService.instance.currentLocation;

              final double? lat =
                  gpsData?.latitude ?? double.tryParse(latCtrl.text.trim());
              final double? lng =
                  gpsData?.longitude ?? double.tryParse(lngCtrl.text.trim());

              if (lat != null && lng != null && gpsData == null) {
                final rev = await LocationService.instance.reverseGeocode(
                  lat,
                  lng,
                );
                reverseGeocodedAddress = rev.fullAddress;
                if (lokasiCtrl.text.trim().isEmpty) {
                  lokasiCtrl.text = rev.shortName;
                }
              }

              // Bubuhkan stamp geolokasi (koordinat, lokasi, alamat, waktu WIB) pada foto
              final stampedBytes = LocationService.stampPhotoWithGeolocation(
                rawBytes,
                latitude: lat,
                longitude: lng,
                locationName: lokasiCtrl.text.trim().isNotEmpty
                    ? lokasiCtrl.text.trim()
                    : gpsData?.shortLocationName,
                address: reverseGeocodedAddress.isNotEmpty
                    ? reverseGeocodedAddress
                    : gpsData?.fullAddress,
              );

              if (!sheetContext.mounted) return;
              setModalState(() {
                pickedPhotoFile = picked;
                pickedPhotoBytes = stampedBytes;
                isProcessingPhoto = false;
                inlineStatusMessage =
                    'Foto dokumentasi "${selectedPhoto.name}" berhasil dilampirkan. Silakan simpan atau selesaikan laporan di bawah.';
                inlineStatusIsError = false;
              });
              scrollFormToBottom();

              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF245C3A),
                  content: Text(
                    lat != null && lng != null
                        ? 'Foto dokumentasi beserta titik geolokasi (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}) berhasil dilampirkan!'
                        : 'Foto berhasil dilampirkan. Aktifkan GPS bila ingin menyertakan koordinat otomatis.',
                  ),
                ),
              );
              showTopFrontNotification(
                sheetContext,
                message: lat != null && lng != null
                    ? 'Foto dokumentasi dan koordinat berhasil dilampirkan.'
                    : 'Foto dokumentasi berhasil dilampirkan.',
              );
            } catch (e) {
              if (sheetContext.mounted) {
                setModalState(() => isProcessingPhoto = false);
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text('Gagal mengambil foto: $e')),
                );
              }
            }
          }

          final formattedDateDisplay =
              '${selectedDate.day} ${LaporanDateUtils.monthName(selectedDate.month)} ${selectedDate.year}';
          final formattedDateApi =
              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

          return Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 700,
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── HEADER MODAL TETAP ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 16, 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border(bottom: BorderSide(color: borderCol)),
                      ),
                      child: Column(
                        children: [
                          const _DragHandle(),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF26352B)
                                      : LaporanColors.greenBackground,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  ReportTemplateManager.iconFromKey(
                                    template['iconKey']?.toString(),
                                  ),
                                  color: primaryGreen,
                                  size: 25,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      jenisLaporan,
                                      style: TextStyle(
                                        fontSize: 18.5,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPreviewOnly
                                          ? 'Pratinjau Form Pengisian Pegawai'
                                          : templateDescription,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── ISI FORM DALAM KARTU SEKSI YANG LEGA & RESPONSIF ──
                    Flexible(
                      child: SingleChildScrollView(
                        controller: formScrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 500;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // KARTU SEKSI 1: INFORMASI UTAMA & GEOLOKASI GPS
                                _SectionContainerCard(
                                  stepNumber: '1',
                                  title: 'Informasi Utama & Geolokasi',
                                  subtitle: 'Isi judul, tanggal pelaksanaan, dan titik lokasi GPS kegiatan.',
                                  cardBg: cardBg,
                                  borderCol: borderCol,
                                  primaryGreen: primaryGreen,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isWide)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _SpaciousLabeledField(
                                                controller: judulCtrl,
                                                label: 'Judul Laporan',
                                                hint: defaultTitle.isNotEmpty
                                                    ? defaultTitle
                                                    : 'Contoh: Penyuluhan KTH',
                                                icon: Icons.title_rounded,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              flex: 2,
                                              child: _DateSelectorField(
                                                label: 'Tanggal Laporan',
                                                valueText: formattedDateDisplay,
                                                onTap: pickReportDate,
                                              ),
                                            ),
                                          ],
                                        )
                                      else ...[
                                        _SpaciousLabeledField(
                                          controller: judulCtrl,
                                          label: 'Judul Laporan',
                                          hint: defaultTitle.isNotEmpty
                                              ? defaultTitle
                                              : 'Contoh: Penyuluhan KTH',
                                          icon: Icons.title_rounded,
                                        ),
                                        const SizedBox(height: 14),
                                        _DateSelectorField(
                                          label: 'Tanggal Laporan',
                                          valueText: formattedDateDisplay,
                                          onTap: pickReportDate,
                                        ),
                                      ],
                                      const SizedBox(height: 14),
                                      _SpaciousLabeledField(
                                        controller: lokasiCtrl,
                                        label: 'Nama Lokasi / Wilayah Kegiatan',
                                        hint: 'Ketuk "Ambil GPS" atau ketik nama lokasi...',
                                        icon: Icons.location_on_outlined,
                                        suffixWidget: TextButton.icon(
                                          onPressed: isGettingLocation
                                              ? null
                                              : () => fetchRealGpsLocation(
                                                  showSnackBar: true,
                                                ),
                                          icon: isGettingLocation
                                              ? SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: primaryGreen,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.my_location_rounded,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            isGettingLocation
                                                ? 'Mencari GPS...'
                                                : 'Ambil GPS',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: primaryGreen,
                                          ),
                                        ),
                                      ),
                                      if (locationWarningMessage != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF332005)
                                                : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF66440A)
                                                  : Colors.orange.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.location_disabled_rounded,
                                                size: 18,
                                                color: Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  locationWarningMessage!,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFFFCC80,
                                                          )
                                                        : Colors
                                                              .orange
                                                              .shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (reverseGeocodedAddress
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF18221B)
                                                : const Color(0xFFF2F7F0),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: borderCol,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.place_rounded,
                                                size: 16,
                                                color: primaryGreen,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Alamat GPS: $reverseGeocodedAddress',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: textPrimary,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (latCtrl.text.isNotEmpty &&
                                              lngCtrl.text.isNotEmpty)
                                            Flexible(
                                              child: Text(
                                                'Koordinat GPS: ${latCtrl.text}, ${lngCtrl.text}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: primaryGreen,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              'Koordinat GPS otomatis terisi saat Ambil GPS / Ambil Foto',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: textSecondary,
                                              ),
                                            ),
                                          TextButton(
                                            onPressed: () {
                                              setModalState(() {
                                                showCoordinateInputs =
                                                    !showCoordinateInputs;
                                              });
                                            },
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              showCoordinateInputs
                                                  ? 'Sembunyikan Koordinat'
                                                  : 'Detail Koordinat',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: primaryGreen,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (showCoordinateInputs) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _SpaciousLabeledField(
                                                controller: latCtrl,
                                                label: 'Latitude',
                                                hint: 'Otomatis dari GPS',
                                                icon:
                                                    Icons.my_location_outlined,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _SpaciousLabeledField(
                                                controller: lngCtrl,
                                                label: 'Longitude',
                                                hint: 'Otomatis dari GPS',
                                                icon: Icons.explore_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // KARTU SEKSI 2: BAGIAN ISIAN KEGIATAN SESUAI TEMPLATE ADMIN
                                _SectionContainerCard(
                                  stepNumber: '2',
                                  title: 'Isian Kegiatan ($jenisLaporan)',
                                  subtitle: 'Bagian ini otomatis disusun sesuai template yang diatur oleh Admin.',
                                  cardBg: cardBg,
                                  borderCol: borderCol,
                                  primaryGreen: primaryGreen,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (existing == null &&
                                          templateFields.isNotEmpty) ...[
                                        ...List.generate(templateFields.length, (
                                          index,
                                        ) {
                                          final fieldLabel =
                                              templateFields[index];
                                          final ctrl =
                                              fieldControllers[fieldLabel]!;
                                          final isLongField =
                                              fieldLabel.toLowerCase().contains(
                                                'hasil',
                                              ) ||
                                              fieldLabel.toLowerCase().contains(
                                                'uraian',
                                              ) ||
                                              fieldLabel.toLowerCase().contains(
                                                'kondisi',
                                              ) ||
                                              fieldLabel.toLowerCase().contains(
                                                'temuan',
                                              ) ||
                                              fieldLabel.toLowerCase().contains(
                                                'tindakan',
                                              ) ||
                                              fieldLabel.toLowerCase().contains(
                                                'ringkasan',
                                              );

                                          return Padding(
                                            padding: EdgeInsets.only(
                                              bottom:
                                                  index ==
                                                      templateFields.length - 1
                                                  ? 8
                                                  : 14,
                                            ),
                                            child: _SpaciousLabeledField(
                                              controller: ctrl,
                                              label:
                                                  '${index + 1}. $fieldLabel',
                                              hint:
                                                  'Tuliskan ${fieldLabel.toLowerCase()}...',
                                              icon: isLongField
                                                  ? Icons.notes_rounded
                                                  : Icons.edit_note_rounded,
                                              maxLines: isLongField ? 3 : 1,
                                              onChanged: (_) =>
                                                  syncTemplateFieldsToIsi(),
                                            ),
                                          );
                                        }),
                                        Theme(
                                          data: Theme.of(sheetContext).copyWith(
                                            dividerColor: Colors.transparent,
                                          ),
                                          child: ExpansionTile(
                                            tilePadding: EdgeInsets.zero,
                                            childrenPadding:
                                                const EdgeInsets.only(top: 8),
                                            title: Text(
                                              'Lihat / Sesuaikan Naskah Lengkap Laporan',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: primaryGreen,
                                              ),
                                            ),
                                            children: [
                                              _SpaciousLabeledField(
                                                controller: isiCtrl,
                                                label:
                                                    'Naskah Laporan Terformat',
                                                hint: 'Naskah laporan otomatis terisi dari bagian di atas...',
                                                icon: Icons.article_outlined,
                                                maxLines: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else
                                        _SpaciousLabeledField(
                                          controller: isiCtrl,
                                          label: 'Isi / Uraian Laporan',
                                          hint: 'Tuliskan hasil kegiatan lapangan...',
                                          icon: Icons.notes_rounded,
                                          maxLines: 6,
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // KARTU SEKSI 3: LAMPIRAN FOTO LOKASI & GEOTAGGING
                                _SectionContainerCard(
                                  stepNumber: '3',
                                  title: 'Foto Dokumentasi & Geolokasi (Geolocator)',
                                  subtitle: requirePhoto
                                      ? 'Ambil foto langsung dari kamera atau pilih dari galeri. Koordinat GPS & alamat otomatis direkam pada foto.'
                                      : 'Opsional — tambahkan foto lokasi dokumentasi kegiatan.',
                                  cardBg: cardBg,
                                  borderCol: borderCol,
                                  primaryGreen: primaryGreen,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isProcessingPhoto)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 28,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF18221B)
                                                : LaporanColors.fieldFill,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: borderCol,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              CircularProgressIndicator(
                                                color: primaryGreen,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Mengambil titik koordinat GPS & menyematkan informasi lokasi pada foto...',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (pickedPhotoBytes != null)
                                        Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF18221B)
                                                : LaporanColors.fieldFill,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: borderCol,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(14),
                                                    ),
                                                child: Image.memory(
                                                  pickedPhotoBytes!,
                                                  height: 220,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              // Informasi Geolokasi yang terhubung dengan foto
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      14,
                                                      10,
                                                      14,
                                                      6,
                                                    ),
                                                color: isDark
                                                    ? const Color(0xFF1E2D23)
                                                    : const Color(0xFFE8F5E9),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .gps_fixed_rounded,
                                                          size: 15,
                                                          color: primaryGreen,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            (latCtrl
                                                                        .text
                                                                        .isNotEmpty &&
                                                                    lngCtrl
                                                                        .text
                                                                        .isNotEmpty)
                                                                ? 'Koordinat Foto: ${latCtrl.text}, ${lngCtrl.text}'
                                                                : 'Koordinat GPS belum tersedia pada foto ini',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  primaryGreen,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (reverseGeocodedAddress
                                                            .isNotEmpty ||
                                                        lokasiCtrl.text
                                                            .trim()
                                                            .isNotEmpty) ...[
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        reverseGeocodedAddress
                                                                .isNotEmpty
                                                            ? reverseGeocodedAddress
                                                            : lokasiCtrl.text
                                                                  .trim(),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          color: textPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        pickedPhotoFile?.name ?? 'Foto_Lokasi_Kegiatan.jpg',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 12.5,
                                                          color: textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          captureOrPickPhotoWithGeolocation(),
                                                      icon: const Icon(
                                                        Icons.refresh_rounded,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        'Ganti',
                                                      ),
                                                      style:
                                                          TextButton.styleFrom(
                                                            foregroundColor:
                                                                primaryGreen,
                                                          ),
                                                    ),
                                                    TextButton.icon(
                                                      onPressed: () {
                                                        setModalState(() {
                                                          pickedPhotoBytes =
                                                              null;
                                                          pickedPhotoFile =
                                                              null;
                                                        });
                                                      },
                                                      icon: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 16,
                                                        color: Colors.red,
                                                      ),
                                                      label: const Text(
                                                        'Hapus',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (existingPhotoUrl != null &&
                                          existingPhotoUrl!.isNotEmpty)
                                        Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF18221B)
                                                : LaporanColors.fieldFill,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: borderCol,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(14),
                                                    ),
                                                child: _buildPhotoImageWidget(
                                                  existingPhotoUrl!,
                                                  height: 200,
                                                  isDark: isDark,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Foto Lampiran Tersimpan',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                          color: textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          captureOrPickPhotoWithGeolocation(),
                                                      icon: const Icon(
                                                        Icons.refresh_rounded,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        'Ganti',
                                                      ),
                                                      style:
                                                          TextButton.styleFrom(
                                                            foregroundColor:
                                                                primaryGreen,
                                                          ),
                                                    ),
                                                    TextButton.icon(
                                                      onPressed: () {
                                                        setModalState(() {
                                                          existingPhotoUrl =
                                                              null;
                                                        });
                                                      },
                                                      icon: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 16,
                                                        color: Colors.red,
                                                      ),
                                                      label: const Text(
                                                        'Hapus',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Column(
                                          children: [
                                            _PhotoButton(
                                              onTap: () =>
                                                  captureOrPickPhotoWithGeolocation(),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        captureOrPickPhotoWithGeolocation(
                                                          explicitSource:
                                                              ImageSource
                                                                  .camera,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.camera_alt_rounded,
                                                      size: 17,
                                                    ),
                                                    label: const Text(
                                                      'Kamera + GPS',
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          primaryGreen,
                                                      side: BorderSide(
                                                        color: primaryGreen,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 11,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        captureOrPickPhotoWithGeolocation(
                                                          explicitSource:
                                                              ImageSource
                                                                  .gallery,
                                                        ),
                                                    icon: const Icon(
                                                      Icons
                                                          .photo_library_outlined,
                                                      size: 17,
                                                    ),
                                                    label: const Text(
                                                      'Pilih Galeri',
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          primaryGreen,
                                                      side: BorderSide(
                                                        color: borderCol,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 11,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),

                                // Banner Status / Notifikasi Transisi di Bawah Kartu Form
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  child: inlineStatusMessage == null
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(
                                            top: 14,
                                          ),
                                          child: TweenAnimationBuilder<double>(
                                            key: ValueKey(inlineStatusMessage),
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            duration: const Duration(
                                              milliseconds: 320,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, value, child) {
                                              return Opacity(
                                                opacity: value,
                                                child: Transform.translate(
                                                  offset: Offset(
                                                    0,
                                                    12 * (1 - value),
                                                  ),
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: inlineStatusIsError
                                                    ? Colors.red.withValues(
                                                        alpha: 0.12,
                                                      )
                                                    : LaporanColors.primary
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: inlineStatusIsError
                                                      ? Colors.red.withValues(
                                                          alpha: 0.45,
                                                        )
                                                      : LaporanColors.primary
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    inlineStatusIsError
                                                        ? Icons
                                                              .error_outline_rounded
                                                        : Icons
                                                              .check_circle_rounded,
                                                    color: inlineStatusIsError
                                                        ? Colors.red.shade700
                                                        : primaryGreen,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      inlineStatusMessage!,
                                                      style: TextStyle(
                                                        fontSize: 12.8,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            inlineStatusIsError
                                                            ? Colors
                                                                  .red
                                                                  .shade700
                                                            : primaryGreen,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // ── FOOTER TOMBOL AKSI TETAP DI BAWAH ──
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        MediaQuery.of(sheetContext).viewInsets.bottom + 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(top: BorderSide(color: borderCol)),
                      ),
                      child: isPreviewOnly
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Tutup Pratinjau Form User'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF245C3A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isSubmittingForm
                                        ? null
                                        : () async {
                                            if (existing == null &&
                                                templateFields.isNotEmpty) {
                                              syncTemplateFieldsToIsi();
                                            }
                                            if (judulCtrl.text.trim().isEmpty ||
                                                lokasiCtrl.text
                                                    .trim()
                                                    .isEmpty) {
                                              const msg =
                                                  'Judul dan lokasi kegiatan wajib diisi terlebih dahulu.';
                                              setModalState(() {
                                                inlineStatusMessage = msg;
                                                inlineStatusIsError = true;
                                              });
                                              scrollFormToBottom();
                                              showTopFrontNotification(
                                                sheetContext,
                                                message: msg,
                                                isError: true,
                                              );
                                              return;
                                            }
                                            setModalState(() {
                                              isSubmittingForm = true;
                                              inlineStatusMessage =
                                                  'Menyimpan draft laporan...';
                                              inlineStatusIsError = false;
                                            });
                                            scrollFormToBottom();
                                            try {
                                              await _handleSubmit(
                                                context: sheetContext,
                                                parentContext: context,
                                                jenisLaporan: jenisLaporan,
                                                existing: existing,
                                                judulCtrl: judulCtrl,
                                                isiCtrl: isiCtrl,
                                                lokasiCtrl: lokasiCtrl,
                                                latCtrl: latCtrl,
                                                lngCtrl: lngCtrl,
                                                addressGeolokasi:
                                                    reverseGeocodedAddress,
                                                customActivityDate:
                                                    formattedDateApi,
                                                status: 'Draft',
                                                onReportSaved: onReportSaved,
                                                closeOnSuccess: true,
                                                photoBytes: pickedPhotoBytes,
                                                photoFilename:
                                                    pickedPhotoFile?.name,
                                                existingPhotoUrl:
                                                    existingPhotoUrl,
                                                onStatusFeedback: (msg, isErr) {
                                                  if (sheetContext.mounted) {
                                                    setModalState(() {
                                                      inlineStatusMessage = msg;
                                                      inlineStatusIsError =
                                                          isErr;
                                                    });
                                                    scrollFormToBottom();
                                                  }
                                                },
                                              );
                                            } finally {
                                              if (sheetContext.mounted) {
                                                setModalState(() {
                                                  isSubmittingForm = false;
                                                });
                                              }
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.save_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Simpan Draft'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryGreen,
                                      side: BorderSide(color: primaryGreen),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: isSubmittingForm
                                        ? null
                                        : () async {
                                            if (existing == null &&
                                                templateFields.isNotEmpty) {
                                              syncTemplateFieldsToIsi();
                                            }
                                            if (judulCtrl.text.trim().isEmpty ||
                                                lokasiCtrl.text
                                                    .trim()
                                                    .isEmpty ||
                                                isiCtrl.text.trim().isEmpty) {
                                              const msg =
                                                  'Lengkapi judul, lokasi, dan isi laporan sebelum menyelesaikan laporan.';
                                              setModalState(() {
                                                inlineStatusMessage = msg;
                                                inlineStatusIsError = true;
                                              });
                                              scrollFormToBottom();
                                              showTopFrontNotification(
                                                sheetContext,
                                                message: msg,
                                                isError: true,
                                              );
                                              return;
                                            }
                                            setModalState(() {
                                              isSubmittingForm = true;
                                              inlineStatusMessage = 'Mengirim dan menyelesaikan laporan...';
                                              inlineStatusIsError = false;
                                            });
                                            scrollFormToBottom();
                                            await _handleSubmit(
                                              context: sheetContext,
                                              parentContext: context,
                                              jenisLaporan: jenisLaporan,
                                              existing: existing,
                                              judulCtrl: judulCtrl,
                                              isiCtrl: isiCtrl,
                                              lokasiCtrl: lokasiCtrl,
                                              latCtrl: latCtrl,
                                              lngCtrl: lngCtrl,
                                              customActivityDate:
                                                  formattedDateApi,
                                              status: 'Selesai',
                                              onReportSaved: onReportSaved,
                                              closeOnSuccess: true,
                                              photoBytes: pickedPhotoBytes,
                                              photoFilename:
                                                  pickedPhotoFile?.name,
                                              onStatusFeedback: (msg, isErr) {
                                                if (sheetContext.mounted) {
                                                  setModalState(() {
                                                    inlineStatusMessage = msg;
                                                    inlineStatusIsError = isErr;
                                                    isSubmittingForm = false;
                                                  });
                                                  scrollFormToBottom();
                                                }
                                              },
                                            );
                                          },
                                    icon: isSubmittingForm
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_circle_outline,
                                            size: 18,
                                          ),
                                    label: Text(
                                      isSubmittingForm
                                          ? 'Memproses...'
                                          : 'Selesaikan Laporan',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF245C3A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 3. Editor Template Laporan Admin (3 Tab Rapi + Upload & Konversi File Contoh)
// ---------------------------------------------------------------------------

Future<void> showAdminTemplateEditor(
  BuildContext context, {
  Map<String, dynamic>? existingTemplate,
  required Future<void> Function(Map<String, dynamic> savedTemplate) onSaved,
}) async {
  final isEditing = existingTemplate != null;

  final titleCtrl = TextEditingController(
    text: existingTemplate?['title']?.toString() ?? '',
  );
  final categoryCtrl = TextEditingController(
    text: existingTemplate?['category']?.toString() ?? 'Penyuluhan',
  );
  final descCtrl = TextEditingController(
    text: existingTemplate?['description']?.toString() ?? '',
  );
  final defaultTitleCtrl = TextEditingController(
    text: existingTemplate?['defaultTitle']?.toString() ?? '',
  );
  final bodyCtrl = TextEditingController(
    text: existingTemplate?['templateBody']?.toString() ?? '',
  );
  final newFieldCtrl = TextEditingController();

  String selectedIconKey = existingTemplate?['iconKey']?.toString() ?? 'groups';
  String sampleFileName = existingTemplate?['sampleFileName']?.toString() ?? '';
  bool requirePhoto = existingTemplate?['requirePhoto'] != false;
  bool requireLocation = existingTemplate?['requireLocation'] != false;
  bool isExtractingFile = false;

  int activeStepTab = 0;

  final List<String> fields =
      (existingTemplate?['fields'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      <String>[
        'Kelompok Tani Hutan (KTH) / Sasaran',
        'Materi / Pokok Kegiatan',
        'Jumlah Peserta (Orang)',
        'Hasil & Tindak Lanjut',
      ];

  void regenerateTemplateBodyFromFields() {
    final titleText = titleCtrl.text.trim().isEmpty
        ? 'LAPORAN KEGIATAN LAPANGAN'
        : titleCtrl.text.trim().toUpperCase();
    final buffer = StringBuffer();
    buffer.writeln(titleText);
    buffer.writeln('Cabang Dinas Kehutanan Wilayah V\n');
    for (int i = 0; i < fields.length; i++) {
      buffer.writeln('${i + 1}. ${fields[i]} : {{${fields[i]}}}');
    }
    bodyCtrl.text = buffer.toString().trim();
  }

  if (!isEditing && bodyCtrl.text.trim().isEmpty) {
    regenerateTemplateBodyFromFields();
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetCtx, setModalState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final sheetBg = isDark
              ? const Color(0xFF141C17)
              : const Color(0xFFF6F8F5);
          final cardBg = isDark ? const Color(0xFF1E2822) : Colors.white;
          final softBg = isDark
              ? const Color(0xFF18221B)
              : const Color(0xFFF2F7F0);
          final borderCol = isDark
              ? const Color(0xFF2E3D34)
              : const Color(0xFFE2EAE3);
          final primaryGreen = isDark
              ? const Color(0xFF81C784)
              : const Color(0xFF245C3A);
          final textPrimary = isDark ? Colors.white : const Color(0xFF24352A);
          final textSecondary = isDark
              ? Colors.white70
              : const Color(0xFF6E7A72);

          Future<void> pickAndExtractSampleFile() async {
            setModalState(() => isExtractingFile = true);
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['docx', 'doc', 'pdf', 'txt'],
                withData: true,
              );

              if (result != null && result.files.isNotEmpty) {
                final picked = result.files.single;
                Uint8List? fileBytes = picked.bytes;

                if (fileBytes == null &&
                    !kIsWeb &&
                    picked.path != null &&
                    picked.path!.isNotEmpty) {
                  try {
                    fileBytes = await File(picked.path!).readAsBytes();
                  } catch (_) {}
                }

                final extracted =
                    ReportTemplateManager.extractTemplateFromSampleFile(
                      fileName: picked.name,
                      bytes: fileBytes,
                    );

                setModalState(() {
                  sampleFileName = picked.name;
                  if (titleCtrl.text.trim().isEmpty || !isEditing) {
                    titleCtrl.text = (extracted['title'] ?? '').toString();
                  }
                  categoryCtrl.text = (extracted['category'] ?? 'Penyuluhan')
                      .toString();
                  selectedIconKey = (extracted['iconKey'] ?? 'groups')
                      .toString();
                  defaultTitleCtrl.text = (extracted['defaultTitle'] ?? '')
                      .toString();
                  descCtrl.text = (extracted['description'] ?? '').toString();

                  final extFields =
                      (extracted['fields'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];
                  if (extFields.isNotEmpty) {
                    fields
                      ..clear()
                      ..addAll(extFields);
                  }
                  bodyCtrl.text = (extracted['templateBody'] ?? '').toString();
                });

                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'File contoh "${picked.name}" berhasil dikonversi menjadi template (${fields.length} bagian isian).',
                      ),
                      backgroundColor: const Color(0xFF245C3A),
                    ),
                  );
                }
              }
            } catch (e) {
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(content: Text('Gagal membaca file contoh: $e')),
                );
              }
            } finally {
              if (sheetCtx.mounted) {
                setModalState(() => isExtractingFile = false);
              }
            }
          }

          final iconOptions = [
            ('groups', Icons.groups_outlined, 'Penyuluhan'),
            ('park', Icons.park_outlined, 'TRK / Rehab'),
            ('forest', Icons.forest_outlined, 'Monitoring'),
            ('event_note', Icons.event_note_outlined, 'Kegiatan'),
            ('warning', Icons.warning_amber_rounded, 'Kejadian'),
            ('eco', Icons.eco_outlined, 'Konservasi'),
          ];

          return Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 720,
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border(bottom: BorderSide(color: borderCol)),
                      ),
                      child: Column(
                        children: [
                          const _DragHandle(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF26352B)
                                      : const Color(0xFFE8F2E8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.edit_document,
                                  color: primaryGreen,
                                  size: 25,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEditing
                                          ? 'Atur Template: ${existingTemplate['title']}'
                                          : 'Buat Template Jenis Laporan Baru',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Unggah file contoh laporan atau sesuaikan bagian form yang wajib diisi pegawai.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: softBg,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: borderCol),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StepTabButton(
                                    label: '1. Contoh & Info',
                                    icon: Icons.upload_file_rounded,
                                    isSelected: activeStepTab == 0,
                                    onTap: () =>
                                        setModalState(() => activeStepTab = 0),
                                  ),
                                ),
                                Expanded(
                                  child: _StepTabButton(
                                    label: '2. Form User (${fields.length})',
                                    icon: Icons.fact_check_outlined,
                                    isSelected: activeStepTab == 1,
                                    onTap: () =>
                                        setModalState(() => activeStepTab = 1),
                                  ),
                                ),
                                Expanded(
                                  child: _StepTabButton(
                                    label: '3. Naskah Template',
                                    icon: Icons.article_outlined,
                                    isSelected: activeStepTab == 2,
                                    onTap: () =>
                                        setModalState(() => activeStepTab = 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 500;

                            if (activeStepTab == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: primaryGreen.withValues(
                                          alpha: 0.4,
                                        ),
                                        width: 1.3,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: primaryGreen.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              ),
                                              child: Icon(
                                                Icons.auto_fix_high_rounded,
                                                color: primaryGreen,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Konversi dari File Contoh Laporan',
                                                    style: TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Unggah file contoh (.docx, .doc, .pdf, atau .txt) untuk diekstrak otomatis menjadi template & form user.',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        if (sampleFileName.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: softBg,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: borderCol,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .check_circle_outline_rounded,
                                                  size: 18,
                                                  color: primaryGreen,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'File Contoh Terpasang: $sampleFileName',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      setModalState(
                                                        () => activeStepTab = 1,
                                                      ),
                                                  child: const Text(
                                                    'Lihat Hasil Form →',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: isExtractingFile
                                                ? null
                                                : pickAndExtractSampleFile,
                                            icon: isExtractingFile
                                                ? SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: primaryGreen,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.upload_file_rounded,
                                                    size: 19,
                                                  ),
                                            label: Text(
                                              sampleFileName.isEmpty
                                                  ? 'Pilih File Contoh Laporan (.docx / .pdf / .txt)'
                                                  : 'Ganti File Contoh Laporan',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: primaryGreen,
                                              side: BorderSide(
                                                color: primaryGreen,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 13,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: borderCol),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Identitas Jenis Laporan',
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        if (isWide)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _SpaciousLabeledField(
                                                  controller: titleCtrl,
                                                  label: 'Nama Jenis Laporan',
                                                  hint: 'Contoh: Laporan Penyuluhan / Laporan TRK',
                                                  icon: Icons.badge_outlined,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: _SpaciousLabeledField(
                                                  controller: categoryCtrl,
                                                  label: 'Kategori Laporan',
                                                  hint: 'Contoh: TRK & Rehabilitasi',
                                                  icon: Icons.category_outlined,
                                                ),
                                              ),
                                            ],
                                          )
                                        else ...[
                                          _SpaciousLabeledField(
                                            controller: titleCtrl,
                                            label: 'Nama Jenis Laporan',
                                            hint: 'Contoh: Laporan Penyuluhan / Laporan TRK',
                                            icon: Icons.badge_outlined,
                                          ),
                                          const SizedBox(height: 14),
                                          _SpaciousLabeledField(
                                            controller: categoryCtrl,
                                            label: 'Kategori Laporan',
                                            hint: 'Contoh: TRK & Rehabilitasi',
                                            icon: Icons.category_outlined,
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        _SpaciousLabeledField(
                                          controller: defaultTitleCtrl,
                                          label: 'Judul Default pada Form User',
                                          hint: 'Contoh: Pelaksanaan Kegiatan TRK & Rehabilitasi Lahan',
                                          icon: Icons.title_rounded,
                                        ),
                                        const SizedBox(height: 14),
                                        _SpaciousLabeledField(
                                          controller: descCtrl,
                                          label: 'Deskripsi / Petunjuk Singkat untuk Pegawai',
                                          hint: 'Jelaskan kegunaan jenis laporan ini...',
                                          icon: Icons.info_outline_rounded,
                                          maxLines: 2,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Pilih Ikon Template',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: iconOptions.map((opt) {
                                            final selected =
                                                selectedIconKey == opt.$1;
                                            return ChoiceChip(
                                              avatar: Icon(
                                                opt.$2,
                                                size: 16,
                                                color: selected
                                                    ? Colors.white
                                                    : primaryGreen,
                                              ),
                                              label: Text(opt.$3),
                                              selected: selected,
                                              showCheckmark: false,
                                              selectedColor: const Color(
                                                0xFF245C3A,
                                              ),
                                              labelStyle: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: selected
                                                    ? Colors.white
                                                    : textPrimary,
                                              ),
                                              onSelected: (_) => setModalState(
                                                () => selectedIconKey = opt.$1,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            if (activeStepTab == 1) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderCol),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Atur Kolom Isian untuk Pegawai',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pegawai otomatis mengisi Judul, Tanggal, Lokasi/GPS, dan Foto. Tambahkan atau sesuaikan bagian khusus kegiatan di bawah ini:',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: newFieldCtrl,
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 13.5,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Ketik nama bagian baru (misal: Luas Area Tanam)...',
                                              hintStyle: TextStyle(
                                                fontSize: 12.5,
                                                color: textSecondary,
                                              ),
                                              filled: true,
                                              fillColor: softBg,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: borderCol,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: borderCol,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            final val = newFieldCtrl.text
                                                .trim();
                                            if (val.isEmpty) return;
                                            setModalState(() {
                                              if (!fields.contains(val)) {
                                                fields.add(val);
                                              }
                                              newFieldCtrl.clear();
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Tambah'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF245C3A,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 13,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    ...List.generate(fields.length, (idx) {
                                      final f = fields[idx];
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: softBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(color: borderCol),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 26,
                                              height: 26,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: primaryGreen.withValues(
                                                  alpha: 0.15,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${idx + 1}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryGreen,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                f,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Hapus Bagian Ini',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () {
                                                setModalState(() {
                                                  fields.removeAt(idx);
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 10),
                                    Divider(color: borderCol),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      activeTrackColor: const Color(0xFF245C3A),
                                      title: Text(
                                        'Sarankan Lampiran Foto Dokumentasi',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Menampilkan penanda lampiran foto bukti kegiatan pada form pegawai',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                      value: requirePhoto,
                                      onChanged: (val) => setModalState(
                                        () => requirePhoto = val,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderCol),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Kerangka Naskah Template Laporan',
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          setModalState(
                                            regenerateTemplateBodyFromFields,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Susun Ulang Otomatis',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Klik chip di bawah untuk menyisipkan placeholder bagian ke dalam naskah:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: fields.map((f) {
                                      return ActionChip(
                                        label: Text(
                                          '+ {{$f}}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: primaryGreen,
                                          ),
                                        ),
                                        backgroundColor: softBg,
                                        side: BorderSide(color: borderCol),
                                        onPressed: () {
                                          bodyCtrl.text =
                                              '${bodyCtrl.text}\n$f : {{$f}}'
                                                  .trim();
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 14),
                                  _SpaciousLabeledField(
                                    controller: bodyCtrl,
                                    label: 'Format Naskah Laporan',
                                    hint: 'Tulis kerangka laporan baku di sini...',
                                    icon: Icons.article_outlined,
                                    maxLines: 9,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        MediaQuery.of(sheetCtx).viewInsets.bottom + 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(top: BorderSide(color: borderCol)),
                      ),
                      child: Row(
                        children: [
                          if (activeStepTab > 0)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setModalState(() => activeStepTab--),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 17,
                              ),
                              label: const Text('Sebelumnya'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            )
                          else
                            OutlinedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: const Text('Batal'),
                            ),
                          const SizedBox(width: 10),
                          if (activeStepTab < 2)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setModalState(() => activeStepTab++),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                              ),
                              label: const Text('Lanjut'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryGreen,
                                side: BorderSide(color: primaryGreen),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          if (activeStepTab < 2) const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (titleCtrl.text.trim().isEmpty) {
                                  setModalState(() => activeStepTab = 0);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Nama jenis laporan wajib diisi.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (bodyCtrl.text.trim().isEmpty) {
                                  regenerateTemplateBodyFromFields();
                                }

                                final saved = ReportTemplateManager.normalizeTemplate({
                                  'id':
                                      existingTemplate?['id'] ??
                                      'tpl_${DateTime.now().millisecondsSinceEpoch}',
                                  'title': titleCtrl.text.trim(),
                                  'category': categoryCtrl.text.trim().isEmpty
                                      ? 'Penyuluhan'
                                      : categoryCtrl.text.trim(),
                                  'iconKey': selectedIconKey,
                                  'description': descCtrl.text.trim().isEmpty
                                      ? 'Template laporan kegiatan ${titleCtrl.text.trim()}.'
                                      : descCtrl.text.trim(),
                                  'defaultTitle': defaultTitleCtrl.text.trim(),
                                  'requirePhoto': requirePhoto,
                                  'requireLocation': requireLocation,
                                  'sampleFileName': sampleFileName,
                                  'fields': fields,
                                  'templateBody': bodyCtrl.text.trim(),
                                  'updatedBy': 'Administrator',
                                });

                                Navigator.pop(sheetCtx);
                                await onSaved(saved);
                              },
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text(
                                'Simpan Template',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF245C3A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 4. Bottom Sheet Unduh Laporan (PDF Siap Print / Word untuk Dikirim ke Atasan)
// ---------------------------------------------------------------------------

Future<void> showReportDownloadSheet(
  BuildContext context, {
  required Map<String, dynamic> laporan,
}) async {
  bool isExportingPdf = false;
  bool isExportingWord = false;
  bool isExportingPhoto = false;
  ReportExportResult? lastResult;

  final bool hasPhoto =
      (laporan['foto'] != null &&
          laporan['foto'].toString().trim().isNotEmpty) ||
      (laporan['photo_base64'] != null &&
          laporan['photo_base64'].toString().trim().isNotEmpty) ||
      (laporan['localPhotoPath'] != null &&
          laporan['localPhotoPath'].toString().trim().isNotEmpty) ||
      (laporan['photos'] is List && (laporan['photos'] as List).isNotEmpty);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final primaryGreen = isDark
              ? const Color(0xFF81C784)
              : const Color(0xFF245C3A);
          final softBg = isDark
              ? const Color(0xFF18221B)
              : const Color(0xFFF2F7F0);
          final borderCol = isDark
              ? const Color(0xFF2E3D34)
              : const Color(0xFFE0E8E0);
          final textColor = isDark ? Colors.white : const Color(0xFF24352A);

          Future<void> triggerExport(
            String format, {
            bool openInNewTab = false,
          }) async {
            setSheetState(() {
              if (format == 'pdf') {
                isExportingPdf = true;
              } else {
                isExportingWord = true;
              }
            });

            final res = await ReportDocumentExporter.exportReport(
              laporan,
              format: format,
              openInNewTabOnWeb: openInNewTab,
            );

            if (!sheetCtx.mounted) return;
            setSheetState(() {
              isExportingPdf = false;
              isExportingWord = false;
              lastResult = res;
            });

            ScaffoldMessenger.of(sheetCtx).showSnackBar(
              SnackBar(
                content: Text(res.message),
                backgroundColor: res.success
                    ? const Color(0xFF245C3A)
                    : Colors.red.shade700,
              ),
            );
          }

          Future<void> triggerExportPhoto() async {
            setSheetState(() {
              isExportingPhoto = true;
            });

            final res = await ReportDocumentExporter.exportPhotoOnly(laporan);

            if (!sheetCtx.mounted) return;
            setSheetState(() {
              isExportingPhoto = false;
              lastResult = res;
            });

            ScaffoldMessenger.of(sheetCtx).showSnackBar(
              SnackBar(
                content: Text(res.message),
                backgroundColor: res.success
                    ? const Color(0xFF245C3A)
                    : Colors.red.shade700,
              ),
            );
          }

          return SafeArea(
            child: Center(
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DragHandle(),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF26352B)
                                  : const Color(0xFFE8F2E8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: primaryGreen,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Unduh & Cetak Laporan Resmi',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Siap di-print langsung atau dikirimkan ke atasan.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: softBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KOP SURAT: CABANG DINAS KEHUTANAN WILAYAH V GARUT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (laporan['judul'] ?? 'Laporan Kegiatan')
                                  .toString(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${laporan['jenis'] ?? 'Laporan Penyuluhan'} • ${laporan['tanggal'] ?? '-'} • ${laporan['lokasi'] ?? '-'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                            if (hasPhoto) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_camera_rounded,
                                      size: 15,
                                      color: primaryGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Foto geolokasi tersedia & otomatis dilampirkan dalam dokumen',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (lastResult != null && lastResult!.success) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF245C3A)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tersimpan: ${lastResult!.fileName}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (lastResult!.filePath != null ||
                                  lastResult!.webBlobUrl != null)
                                TextButton.icon(
                                  onPressed: () {
                                    ReportDocumentExporter.openExportedFile(
                                      lastResult!,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Buka / Print'),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isExportingPdf
                              ? null
                              : () => triggerExport('pdf'),
                          icon: isExportingPdf
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text(
                            'Unduh Laporan PDF Siap Print (.pdf)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF245C3A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isExportingPdf
                              ? null
                              : () => triggerExport('pdf', openInNewTab: true),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text(
                            'Buka & Print PDF di Tab Baru',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGreen,
                            side: BorderSide(color: primaryGreen),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isExportingWord
                              ? null
                              : () => triggerExport('doc'),
                          icon: isExportingWord
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryGreen,
                                  ),
                                )
                              : const Icon(Icons.description_outlined),
                          label: const Text(
                            'Unduh Format Word (.doc)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGreen,
                            side: BorderSide(color: primaryGreen),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      if (hasPhoto) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isExportingPhoto
                                ? null
                                : triggerExportPhoto,
                            icon: isExportingPhoto
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryGreen,
                                    ),
                                  )
                                : const Icon(Icons.photo_library_outlined),
                            label: const Text(
                              'Unduh Berkas Foto Lampiran Saja (.jpg)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryGreen,
                              side: BorderSide(color: primaryGreen),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 5. Bottom Sheet Detail Laporan (Menampilkan Foto + Koordinat + Alamat Lokasi)
// ---------------------------------------------------------------------------

void showReportDetail(
  BuildContext context, {
  required Map<String, dynamic> laporan,
  required void Function(String jenisLaporan, {Map<String, dynamic>? existing})
  onEdit,
  required void Function(Map<String, dynamic> laporan) onDownload,
  bool isAdmin = false,
  void Function(Map<String, dynamic> laporan, String newStatus)? onUpdateStatus,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final textColor = isDark ? Colors.white : const Color(0xFF24352A);
      final primaryGreen = isDark
          ? const Color(0xFF81C784)
          : LaporanColors.primary;
      final pelapor =
          (laporan['pelapor'] ?? laporan['userName'] ?? 'Penyuluh Kehutanan')
              .toString();
      final currentStatus = (laporan['status'] ?? 'Draft').toString();
      final alamatGeolokasi = (laporan['alamatGeolokasi'] ?? '')
          .toString()
          .trim();
      final latitude = (laporan['latitude'] ?? '').toString().trim();
      final longitude = (laporan['longitude'] ?? '').toString().trim();
      final coordinates = latitude.isNotEmpty && longitude.isNotEmpty
          ? '$latitude, $longitude'
          : latitude.isNotEmpty
          ? 'Lat: $latitude'
          : longitude.isNotEmpty
          ? 'Lng: $longitude'
          : 'Belum tersedia';

      return Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _DragHandle(),
                  const SizedBox(height: 20),
                  Text(
                    (laporan['judul'] ?? '-').toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (laporan['jenis'] ?? 'Laporan Kegiatan').toString(),
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isAdmin ||
                      laporan['pelapor'] != null ||
                      laporan['userName'] != null)
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Pegawai',
                      value: pelapor,
                    ),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'Tanggal',
                    value: (laporan['tanggal'] ?? '-').toString(),
                  ),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    title: 'Lokasi',
                    value: (laporan['lokasi'] ?? '-').toString(),
                  ),
                  if (alamatGeolokasi.isNotEmpty &&
                      alamatGeolokasi !=
                          (laporan['lokasi'] ?? '').toString().trim())
                    _DetailRow(
                      icon: Icons.map_outlined,
                      title: 'Alamat',
                      value: alamatGeolokasi,
                    ),
                  _DetailRow(
                    icon: Icons.info_outline,
                    title: 'Status',
                    value: currentStatus,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Isi Laporan (Berdasarkan Template)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF18221B)
                          : LaporanColors.templateBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E3D34)
                            : LaporanColors.borderDetail,
                      ),
                    ),
                    child: Text(
                      ReportTemplateManager.sanitizeReportIsi(
                        rawIsi: (laporan['isi'] ?? '').toString(),
                        jenis: (laporan['jenis'] ?? 'Laporan Kegiatan')
                            .toString(),
                        judul: (laporan['judul'] ?? 'Kegiatan Lapangan')
                            .toString(),
                        lokasi: (laporan['lokasi'] ?? 'Kawasan Hutan Garut')
                            .toString(),
                      ),
                      style: TextStyle(height: 1.5, color: textColor),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    icon: Icons.explore_outlined,
                    title: 'Koordinat',
                    value: coordinates,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lampiran Foto & Geolokasi Dokumentasi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildReportPhotoSection(ctx, laporan, isDark),
                  const SizedBox(height: 20),
                  if (isAdmin && onUpdateStatus != null) ...[
                    const Text(
                      'Tindakan Monitoring Admin:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (currentStatus != 'Selesai')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onUpdateStatus(laporan, 'Selesai');
                              },
                              icon: const Icon(
                                Icons.verified_outlined,
                                size: 18,
                              ),
                              label: const Text('Verifikasi Selesai'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF245C3A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (currentStatus != 'Selesai' &&
                            currentStatus != 'Diproses')
                          const SizedBox(width: 10),
                        if (currentStatus != 'Diproses')
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onUpdateStatus(laporan, 'Diproses');
                              },
                              icon: const Icon(
                                Icons.pending_actions_rounded,
                                size: 18,
                              ),
                              label: const Text('Tandai Diproses'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB26A00),
                                side: const BorderSide(
                                  color: Color(0xFFE7C98A),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!isAdmin && currentStatus == 'Draft') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onEdit(
                            (laporan['jenis'] ?? 'Laporan Kegiatan').toString(),
                            existing: laporan,
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Lanjutkan / Edit Draft'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDownload(laporan);
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text(
                        'Unduh Laporan (PDF / Word)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF245C3A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Komponen Penampil Foto Dokumentasi Laporan (Mendukung Base64, File Lokal, & Server URL)
// ---------------------------------------------------------------------------

Widget _buildPhotoImageWidget(
  String sourceUrl, {
  double height = 220,
  required bool isDark,
}) {
  if (sourceUrl.startsWith('data:image')) {
    try {
      final cleanB64 = sourceUrl.contains(',')
          ? sourceUrl.split(',').last
          : sourceUrl;
      final bytes = base64Decode(cleanB64);
      return Image.memory(
        bytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } catch (_) {}
  }

  if (!kIsWeb && !sourceUrl.startsWith('http')) {
    try {
      final f = File(sourceUrl);
      if (f.existsSync()) {
        return Image.file(
          f,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }
    } catch (_) {}
  }

  final fullUrl = sourceUrl.startsWith('http')
      ? sourceUrl
      : (sourceUrl.startsWith('/')
            ? '${ApiConstants.baseUrl}$sourceUrl'
            : '${ApiConstants.baseUrl}/storage/$sourceUrl');

  return Image.network(
    fullUrl,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    loadingBuilder: (ctx, child, progress) {
      if (progress == null) return child;
      return Container(
        height: height,
        color: isDark ? const Color(0xFF1B261F) : Colors.grey.shade100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2.2),
      );
    },
    errorBuilder: (ctx, err, stack) {
      return Container(
        height: 140,
        color: isDark ? const Color(0xFF2E1A1A) : Colors.red.shade50,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_rounded,
              color: Colors.red.shade300,
              size: 36,
            ),
            const SizedBox(height: 6),
            const Text(
              'Foto lampiran tidak dapat dimuat dari server',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildReportPhotoSection(
  BuildContext context,
  Map<String, dynamic> laporan,
  bool isDark,
) {
  String? photoUrl;

  final rawB64 = (laporan['photo_base64'] ?? '').toString().trim();
  final rawFoto = (laporan['foto'] ?? '').toString().trim();
  if (rawFoto.startsWith('data:image')) {
    photoUrl = rawFoto;
  } else if (rawB64.isNotEmpty) {
    photoUrl = rawB64.startsWith('data:image')
        ? rawB64
        : 'data:image/jpeg;base64,$rawB64';
  } else if (rawFoto.isNotEmpty) {
    photoUrl = rawFoto;
  }

  if ((photoUrl == null || photoUrl.isEmpty) &&
      laporan['photos'] is List &&
      (laporan['photos'] as List).isNotEmpty) {
    final first = (laporan['photos'] as List).first;
    if (first is Map) {
      final pB64 = (first['photo_base64'] ?? '').toString().trim();
      final raw = (first['url'] ?? first['photo'] ?? first['local_path'] ?? '')
          .toString()
          .trim();
      if (pB64.isNotEmpty) {
        photoUrl = pB64.startsWith('data:image')
            ? pB64
            : 'data:image/jpeg;base64,$pB64';
      } else if (first['id'] != null) {
        photoUrl = ApiConstants.reportPhotoFileUrl(first['id']);
      } else if (raw.isNotEmpty) {
        photoUrl = raw;
      }
    }
  }

  if ((photoUrl == null || photoUrl.isEmpty) &&
      laporan['localPhotoPath'] != null) {
    final raw = laporan['localPhotoPath'].toString().trim();
    if (raw.isNotEmpty) photoUrl = raw;
  }

  if (photoUrl == null || photoUrl.isEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18221B) : LaporanColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D34) : LaporanColors.borderDetail,
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.photo_outlined, color: Colors.grey, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tidak ada lampiran foto untuk laporan ini.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  final String activePhotoUrl = photoUrl;
  final String lat = (laporan['latitude'] ?? '').toString().trim();
  final String lng = (laporan['longitude'] ?? '').toString().trim();
  final String loc = (laporan['alamatGeolokasi'] ?? laporan['lokasi'] ?? '')
      .toString()
      .trim();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  InteractiveViewer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildPhotoImageWidget(
                        activePhotoUrl,
                        height: 360,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildPhotoImageWidget(
                activePhotoUrl,
                height: 230,
                isDark: isDark,
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Ketuk untuk perbesar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      if (lat.isNotEmpty || lng.isNotEmpty || loc.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18221B) : const Color(0xFFF2F7F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3D34) : const Color(0xFFDCE6DC),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.gps_fixed_rounded,
                    size: 15,
                    color: isDark
                        ? const Color(0xFF81C784)
                        : const Color(0xFF245C3A),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (lat.isNotEmpty && lng.isNotEmpty)
                          ? 'Koordinat Foto: $lat, $lng'
                          : 'Lokasi Foto: $loc',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF245C3A),
                      ),
                    ),
                  ),
                ],
              ),
              if (loc.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  loc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : const Color(0xFF37473B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Submit handler (Menyimpan Laporan + Foto + Koordinat Geolokasi + Notifikasi)
// ---------------------------------------------------------------------------

Future<void> _handleSubmit({
  required BuildContext context,
  required BuildContext parentContext,
  required String jenisLaporan,
  required Map<String, dynamic>? existing,
  required TextEditingController judulCtrl,
  required TextEditingController isiCtrl,
  required TextEditingController lokasiCtrl,
  required TextEditingController latCtrl,
  required TextEditingController lngCtrl,
  String? addressGeolokasi,
  String? customActivityDate,
  required String status,
  required Future<void> Function() onReportSaved,
  bool closeOnSuccess = false,
  Uint8List? photoBytes,
  String? photoFilename,
  String? existingPhotoUrl,
  void Function(String message, bool isError)? onStatusFeedback,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null || token.isEmpty) {
    const msg = 'Sesi berakhir. Silakan login kembali.';
    onStatusFeedback?.call(msg, true);
    if (!parentContext.mounted) return;
    showTopFrontNotification(parentContext, message: msg, isError: true);
    return;
  }

  final title = judulCtrl.text.trim();
  final location = lokasiCtrl.text.trim();

  if (title.isEmpty || location.isEmpty) {
    const msg = 'Judul dan lokasi wajib diisi.';
    onStatusFeedback?.call(msg, true);
    if (!parentContext.mounted) return;
    showTopFrontNotification(parentContext, message: msg, isError: true);
    return;
  }

  final now = DateTime.now();
  final existingDate = existing?['tanggalApi']?.toString();
  final activityDate =
      (customActivityDate != null && customActivityDate.isNotEmpty)
      ? customActivityDate
      : ((existingDate != null && existingDate.isNotEmpty)
            ? existingDate
            : '${now.year}-${now.month.toString().padLeft(2, '0')}'
                  '-${now.day.toString().padLeft(2, '0')}');

  final apiStatus = status == 'Draft' ? 'draft' : 'terkirim';
  final currentUserName =
      prefs.getString('profil_nama') ??
      prefs.getString('name') ??
      (prefs.getString('email')?.isNotEmpty == true
          ? prefs.getString('email')!.split('@').first
          : 'Pengguna');

  final String? photoDataUri = (photoBytes != null && photoBytes.isNotEmpty)
      ? 'data:image/jpeg;base64,${base64Encode(photoBytes)}'
      : existingPhotoUrl;

  final payload = <String, dynamic>{
    'title': title,
    'activity_date': activityDate,
    'location': location,
    'address': (addressGeolokasi != null && addressGeolokasi.trim().isNotEmpty)
        ? addressGeolokasi.trim()
        : location,
    'description': isiCtrl.text.trim(),
    'latitude': latCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(latCtrl.text.trim()),
    'longitude': lngCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(lngCtrl.text.trim()),
    'status': apiStatus,
    if (photoBytes != null && photoBytes.isNotEmpty)
      'photo_base64': base64Encode(photoBytes),
  };

  Future<void> syncToLocalMonitoringStorage(
    String recordId, {
    String? savedPhotoUrl,
    List<dynamic>? serverPhotos,
  }) async {
    try {
      const draftKey = 'phonebook_laporan_drafts_v1';
      final rawDrafts = prefs.getString(draftKey);
      List<Map<String, dynamic>> drafts = [];
      if (rawDrafts != null && rawDrafts.isNotEmpty) {
        final decoded = jsonDecode(rawDrafts) as List<dynamic>;
        drafts = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final effectivePhoto =
          savedPhotoUrl ?? photoDataUri ?? existing?['foto'] ?? '';

      final record = <String, dynamic>{
        'id': recordId,
        'judul': title,
        'jenis': jenisLaporan,
        'pelapor': currentUserName,
        'userName': currentUserName,
        'tanggal': LaporanDateUtils.formatApiDate(activityDate),
        'tanggalApi': activityDate,
        'lokasi': location,
        'alamatGeolokasi':
            (addressGeolokasi != null && addressGeolokasi.trim().isNotEmpty)
            ? addressGeolokasi.trim()
            : location,
        'isi': isiCtrl.text.trim(),
        'latitude': latCtrl.text.trim(),
        'longitude': lngCtrl.text.trim(),
        'status': status,
        'localPhotoPath': photoDataUri ?? existing?['localPhotoPath'],
        'foto': effectivePhoto,
        'photo_base64': photoDataUri ?? existing?['photo_base64'] ?? '',
        'photos':
            serverPhotos ??
            (effectivePhoto.toString().isNotEmpty
                ? [
                    {
                      'url': effectivePhoto,
                      'photo_base64': photoDataUri,
                      'latitude': latCtrl.text.trim(),
                      'longitude': lngCtrl.text.trim(),
                      'address': addressGeolokasi ?? location,
                    },
                  ]
                : (existing?['photos'] ?? <dynamic>[])),
      };

      final existingIdx = drafts.indexWhere(
        (d) => d['id'].toString() == recordId || d['judul'] == title,
      );
      if (existingIdx >= 0) {
        drafts[existingIdx] = record;
      } else {
        drafts.insert(0, record);
      }
      await prefs.setString(draftKey, jsonEncode(drafts));
    } catch (_) {}
  }

  final online = await ConnectivityService.instance.isOnline();
  final isOfflineToken =
      token.startsWith('offline_') || token.startsWith('google_session_');

  if (!online || isOfflineToken) {
    try {
      final insertedId = await LaporanService.saveOffline(
        payload: payload,
        jenisLaporan: jenisLaporan,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      final recordId = 'local_$insertedId';
      await syncToLocalMonitoringStorage(recordId, savedPhotoUrl: photoDataUri);

      await NotificationService.instance.addReportCreatedNotification(
        title: title,
        jenisLaporan: jenisLaporan,
        location: location,
        status: status,
        reportId: recordId,
      );

      final offlineMsg = photoBytes != null
          ? 'Laporan dan foto bukti disimpan secara offline. Akan otomatis disinkronkan saat online.'
          : 'Laporan disimpan secara offline. Akan otomatis dikirim saat ada koneksi.';
      onStatusFeedback?.call(offlineMsg, false);

      await onReportSaved();
      if (closeOnSuccess && context.mounted) {
        Navigator.pop(context);
      }

      if (!parentContext.mounted) return;
      showTopFrontNotification(parentContext, message: offlineMsg);
    } catch (e) {
      final errMsg = 'Gagal menyimpan offline: $e';
      onStatusFeedback?.call(errMsg, true);
      if (!parentContext.mounted) return;
      showTopFrontNotification(parentContext, message: errMsg, isError: true);
    }
    return;
  }

  try {
    final existingId = existing?['id'] != null
        ? int.tryParse(existing!['id'].toString())
        : null;

    final response = await LaporanService.submitReport(
      token: token,
      payload: payload,
      existingId: existingId,
    );

    if (!parentContext.mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      final reportData = body['data'] as Map<String, dynamic>?;
      final reportId = reportData?['id'] != null
          ? int.tryParse(reportData!['id'].toString())
          : existingId;

      List<dynamic> serverPhotos = (reportData?['photos'] is List)
          ? (reportData!['photos'] as List<dynamic>)
          : <dynamic>[];

      bool photoUploaded = photoBytes == null || serverPhotos.isNotEmpty;
      String? photoError;

      // Jika foto belum masuk melalui JSON payload (misal server versi lama), kirim juga via Multipart
      if (reportId != null && photoBytes != null && !photoUploaded) {
        try {
          final photoRes = await LaporanService.uploadReportPhoto(
            token: token,
            reportId: reportId,
            photoBytes: photoBytes,
            filename:
                photoFilename ??
                'bukti_laporan_${DateTime.now().millisecondsSinceEpoch}.jpg',
            latitude: double.tryParse(latCtrl.text.trim()),
            longitude: double.tryParse(lngCtrl.text.trim()),
            address: addressGeolokasi ?? location,
          );
          if (photoRes.statusCode == 200 || photoRes.statusCode == 201) {
            photoUploaded = true;
            try {
              final pBody = jsonDecode(photoRes.body);
              if (pBody['data'] != null) {
                serverPhotos = [pBody['data']];
              }
            } catch (_) {}
          } else {
            photoError =
                'Upload foto gagal dengan status ${photoRes.statusCode}.';
          }
        } catch (e) {
          photoError = 'Upload foto gagal: $e';
        }
      } else if (photoBytes != null && reportId == null && !photoUploaded) {
        photoError =
            'Foto belum dapat dikaitkan karena ID laporan tidak tersedia.';
      }

      final finalRecordId = (reportId ?? DateTime.now().millisecondsSinceEpoch)
          .toString();

      await syncToLocalMonitoringStorage(
        finalRecordId,
        savedPhotoUrl: photoDataUri,
        serverPhotos: serverPhotos.isNotEmpty ? serverPhotos : null,
      );
      await NotificationService.instance.addReportCreatedNotification(
        title: title,
        jenisLaporan: jenisLaporan,
        location: location,
        status: status,
        reportId: finalRecordId,
      );

      await onReportSaved();

      if (!parentContext.mounted) return;

      final String notifyMsg;
      if (apiStatus == 'draft') {
        notifyMsg = photoError != null
            ? 'Draft disimpan, tetapi upload foto gagal ($photoError).'
            : photoBytes != null
            ? 'Draft laporan beserta foto geolokasi berhasil disimpan.'
            : 'Draft berhasil disimpan ke database.';
      } else {
        notifyMsg = photoError != null
            ? 'Laporan terkirim, tetapi upload foto gagal ($photoError).'
            : photoBytes != null
            ? 'Laporan dan foto bukti geolokasi berhasil dikirim.'
            : 'Laporan berhasil dikirim ke database.';
      }

      onStatusFeedback?.call(notifyMsg, photoError != null);

      if (closeOnSuccess && context.mounted) {
        Navigator.pop(context);
      }
      if (!parentContext.mounted) return;
      showTopFrontNotification(
        parentContext,
        message: notifyMsg,
        isError: photoError != null,
      );
    } else {
      final insertedId = await LaporanService.saveOffline(
        payload: payload,
        jenisLaporan: jenisLaporan,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      final recordId = 'local_$insertedId';
      await syncToLocalMonitoringStorage(recordId, savedPhotoUrl: photoDataUri);
      await NotificationService.instance.addReportCreatedNotification(
        title: title,
        jenisLaporan: jenisLaporan,
        location: location,
        status: status,
        reportId: recordId,
      );
      final localMsg = status == 'Draft'
          ? 'Draft laporan disimpan lokal di perangkat.'
          : 'Laporan disimpan lokal di perangkat dan siap diunduh.';
      onStatusFeedback?.call(localMsg, false);
      if (closeOnSuccess && context.mounted) {
        Navigator.pop(context);
      }
      await onReportSaved();

      if (!parentContext.mounted) return;
      showTopFrontNotification(parentContext, message: localMsg);
    }
  } catch (e) {
    try {
      final insertedId = await LaporanService.saveOffline(
        payload: payload,
        jenisLaporan: jenisLaporan,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      final recordId = 'local_$insertedId';
      await syncToLocalMonitoringStorage(recordId, savedPhotoUrl: photoDataUri);
      await NotificationService.instance.addReportCreatedNotification(
        title: title,
        jenisLaporan: jenisLaporan,
        location: location,
        status: status,
        reportId: recordId,
      );
      const fallbackMsg =
          'Koneksi bermasalah. Laporan dan foto disimpan di perangkat.';
      onStatusFeedback?.call(fallbackMsg, false);
      if (closeOnSuccess && context.mounted) {
        Navigator.pop(context);
      }
      await onReportSaved();
      if (parentContext.mounted) {
        showTopFrontNotification(parentContext, message: fallbackMsg);
      }
    } catch (_) {
      final errMsg = 'Gagal mengirim laporan: $e';
      onStatusFeedback?.call(errMsg, true);
      if (!parentContext.mounted) return;
      showTopFrontNotification(parentContext, message: errMsg, isError: true);
    }
  }
}

// ===========================================================================
// KOMPONEN UI PENDUKUNG FORMULIR (RAPI, LEGA & RESPONSIF)
// ===========================================================================

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

class _SectionContainerCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String subtitle;
  final Color cardBg;
  final Color borderCol;
  final Color primaryGreen;
  final Color textPrimary;
  final Color textSecondary;
  final Widget child;

  const _SectionContainerCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.cardBg,
    required this.borderCol,
    required this.primaryGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  stepNumber,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SpaciousLabeledField extends StatelessWidget {
  const _SpaciousLabeledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.onChanged,
    this.suffixWidget,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffixWidget;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF18221B) : const Color(0xFFF7FAF7);
    final borderCol = isDark
        ? const Color(0xFF2E3D34)
        : const Color(0xFFDCE6DC);
    final iconCol = isDark
        ? const Color(0xFF81C784)
        : LaporanColors.textFieldIcon;
    final primaryColor = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF245C3A);
    final labelColor = isDark ? Colors.white : const Color(0xFF24352A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ),
            ?suffixWidget,
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: iconCol, size: 20)
                : null,
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: borderCol),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateSelectorField extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onTap;

  const _DateSelectorField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF18221B) : const Color(0xFFF7FAF7);
    final borderCol = isDark
        ? const Color(0xFF2E3D34)
        : const Color(0xFFDCE6DC);
    final iconCol = isDark
        ? const Color(0xFF81C784)
        : LaporanColors.textFieldIcon;
    final labelColor = isDark ? Colors.white : const Color(0xFF24352A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 19, color: iconCol),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    valueText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
                Icon(Icons.edit_calendar_rounded, size: 18, color: iconCol),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StepTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF245C3A) : Colors.white;
    final activeFg = isDark ? Colors.white : const Color(0xFF245C3A);
    final inactiveFg = isDark ? Colors.white70 : const Color(0xFF6E7A72);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: isSelected ? activeFg : inactiveFg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeFg : inactiveFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF26352B)
        : LaporanColors.templateBackground;
    final cardBorder = isDark
        ? const Color(0xFF2E3D34)
        : LaporanColors.borderDetail;
    final primaryColor = isDark
        ? const Color(0xFF81C784)
        : LaporanColors.primary;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: primaryColor, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF18221B) : const Color(0xFFF7FAF7);
    final borderCol = isDark
        ? const Color(0xFF2E3D34)
        : const Color(0xFFDCE6DC);
    final primaryColor = isDark
        ? const Color(0xFF81C784)
        : LaporanColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            Icon(Icons.add_a_photo_rounded, color: primaryColor, size: 25),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ambil Foto Lokasi (Kamera + Geolocator)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Rekam foto kegiatan beserta koordinat GPS & alamat otomatis',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? const Color(0xFF81C784)
                : LaporanColors.textFieldIcon,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 68,
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
