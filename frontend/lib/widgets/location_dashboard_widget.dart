import 'package:flutter/material.dart';
import '../services/location_service.dart';

/// Komponen pill lokasi bergaya Gojek untuk bagian atas Dashboard Header:
/// Menampilkan "Kamu sedang berada di...", nama wilayah/alamat, indikator
/// pembaruan lokasi, serta tombol muat ulang / aktifkan izin.
class LocationHeaderBanner extends StatelessWidget {
  const LocationHeaderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocationService.instance,
      builder: (context, _) {
        final service = LocationService.instance;
        final loc = service.currentLocation;
        final isRefreshing = service.isRefreshing;
        final status = service.status;

        String headlineText;
        String subText;
        IconData leadingIcon = Icons.location_on_rounded;
        Color iconColor = const Color(0xFFA5D6A7);

        if (isRefreshing && loc == null) {
          headlineText = 'Mendeteksi lokasi GPS Anda...';
          subText = 'Sedang mengambil titik koordinat perangkat';
        } else if (loc != null) {
          headlineText = loc.shortLocationName;
          subText =
              'GPS: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}';
        } else if (status == LocationStatus.permissionDenied ||
            status == LocationStatus.permissionDeniedForever) {
          headlineText = 'Izin lokasi belum diaktifkan';
          subText = 'Ketuk untuk mengizinkan akses lokasi GPS';
          leadingIcon = Icons.location_disabled_rounded;
          iconColor = const Color(0xFFFFCC80);
        } else if (status == LocationStatus.serviceDisabled) {
          headlineText = 'Layanan GPS perangkat nonaktif';
          subText = 'Ketuk untuk mengaktifkan GPS perangkat';
          leadingIcon = Icons.gps_off_rounded;
          iconColor = const Color(0xFFFFCC80);
        } else {
          headlineText = 'Lokasi belum tersedia';
          subText = 'Ketuk tombol segarkan untuk memuat lokasi GPS';
          leadingIcon = Icons.location_searching_rounded;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: isRefreshing
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        leadingIcon,
                        color: iconColor,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleActionTap(context, service),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Kamu sedang berada di...',
                            style: TextStyle(
                              color: Color(0xFFD8EBD9),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isRefreshing) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Memperbarui...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headlineText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: isRefreshing
                    ? null
                    : () => _handleActionTap(context, service),
                tooltip: 'Perbarui Lokasi GPS',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.my_location_rounded, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleActionTap(
    BuildContext context,
    LocationService service,
  ) async {
    if (service.status == LocationStatus.permissionDeniedForever) {
      final opened = await service.openAppSettings();
      if (!opened && context.mounted) {
        await service.refreshLocation();
      }
      return;
    }
    if (service.status == LocationStatus.serviceDisabled) {
      final opened = await service.openLocationSettings();
      if (!opened && context.mounted) {
        await service.refreshLocation();
      }
      return;
    }
    await service.refreshLocation();
  }
}

/// Widget kartu lokasi pada Dashboard yang terhubung ke instance [LocationService]
/// yang sama dengan Header, sehingga selalu sinkron dan responsif tanpa menjalankan
/// sistem GPS kedua.
class LocationDashboardWidget extends StatelessWidget {
  const LocationDashboardWidget({super.key});

  String _formatUpdatedTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s WIB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A241E) : Colors.white;
    final innerBg = isDark ? const Color(0xFF223026) : const Color(0xFFF2F7F0);
    final borderCol =
        isDark ? const Color(0xFF2E3D34) : const Color(0xFFE1EAE0);
    final primaryCol =
        isDark ? const Color(0xFF81C784) : const Color(0xFF245C3A);
    final textPrimary = isDark ? Colors.white : const Color(0xFF24352A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF758278);

    return ListenableBuilder(
      listenable: LocationService.instance,
      builder: (context, _) {
        final service = LocationService.instance;
        final loc = service.currentLocation;
        final isRefreshing = service.isRefreshing;
        final status = service.status;

        final bool isDenied = status == LocationStatus.permissionDenied ||
            status == LocationStatus.permissionDeniedForever;
        final bool isGpsOff = status == LocationStatus.serviceDisabled;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderCol),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF245C3A)
                    .withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF26382B)
                          : const Color(0xFFE8F2E8),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isDenied || isGpsOff
                          ? Icons.location_disabled_rounded
                          : Icons.place_rounded,
                      color: isDenied || isGpsOff
                          ? const Color(0xFFE65100)
                          : primaryCol,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Kamu sedang berada di...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isRefreshing
                                    ? const Color(0xFFE3F2FD)
                                    : (loc != null
                                        ? (isDark
                                            ? const Color(0xFF233829)
                                            : const Color(0xFFE8F2E8))
                                        : const Color(0xFFFFF3E0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isRefreshing) ...[
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Memperbarui',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(
                                      loc != null
                                          ? Icons.gps_fixed_rounded
                                          : Icons.info_outline_rounded,
                                      size: 12,
                                      color: loc != null
                                          ? primaryCol
                                          : const Color(0xFFE65100),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      loc != null ? 'GPS Aktif' : 'Perlu Izin',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: loc != null
                                            ? primaryCol
                                            : const Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          loc != null
                              ? loc.shortLocationName
                              : (isGpsOff
                                  ? 'GPS Perangkat Belum Aktif'
                                  : (isDenied
                                      ? 'Izin Lokasi Ditolak'
                                      : 'Mencari Lokasi GPS...')),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: loc != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 15,
                                color: primaryCol,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  loc.fullAddress,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.my_location_rounded,
                                    size: 13.5,
                                    color: primaryCol,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Koordinat: ${loc.coordinatesText}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: primaryCol,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13.5,
                                    color: textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Diperbarui: ${_formatUpdatedTime(loc.updatedAt)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      )
                    : Text(
                        service.errorMessage ??
                            'Aktifkan GPS dan izinkan akses lokasi agar aplikasi dapat menampilkan wilayah kerja Anda saat ini secara akurat.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: textSecondary,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (isDenied || isGpsOff) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (isGpsOff) {
                            await service.openLocationSettings();
                          } else if (status ==
                              LocationStatus.permissionDeniedForever) {
                            await service.openAppSettings();
                          } else {
                            await service.refreshLocation();
                          }
                        },
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: Text(
                          isGpsOff ? 'Pengaturan GPS' : 'Aktifkan Izin Lokasi',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE65100),
                          side: const BorderSide(color: Color(0xFFE65100)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isRefreshing
                          ? null
                          : () => service.refreshLocation(),
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        isRefreshing
                            ? 'Memperbarui Lokasi...'
                            : 'Perbarui Lokasi Sekarang',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF245C3A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}