import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminMonitoringSection extends StatelessWidget {
  final bool isWideScreen;
  final bool isLoading;
  final Map<String, dynamic> summary;
  final List<dynamic> reports;
  final List<dynamic> periodStats;
  final List<dynamic> lastActiveUsers;
  final String statusFilter;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Future<void> Function() onRefresh;
  final ValueChanged<DateTime> onDateFromChanged;
  final ValueChanged<DateTime> onDateToChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<Map<String, dynamic>> onUpdateReportStatus;

  const AdminMonitoringSection({
    super.key,
    required this.isWideScreen,
    required this.isLoading,
    required this.summary,
    required this.reports,
    required this.periodStats,
    required this.lastActiveUsers,
    required this.statusFilter,
    required this.dateFrom,
    required this.dateTo,
    required this.onRefresh,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onStatusFilterChanged,
    required this.onUpdateReportStatus,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _statCard(
    AdminTheme t,
    String title,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 12, color: t.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminTheme.of(context);
    const statusOptions = [
      'Semua',
      'draft',
      'terkirim',
      'diperiksa',
      'disetujui',
      'ditolak',
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isWideScreen ? 28 : 18,
          20,
          isWideScreen ? 28 : 18,
          40,
        ),
        children: [
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: dateFrom ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) onDateFromChanged(date);
                },
                icon: const Icon(Icons.date_range_rounded),
                label: Text('Dari ${_formatDate(dateFrom)}'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: dateTo ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) onDateToChanged(date);
                },
                icon: const Icon(Icons.event_rounded),
                label: Text('Sampai ${_formatDate(dateTo)}'),
              ),
              DropdownButton<String>(
                value: statusFilter,
                items: statusOptions
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(
                          status == 'Semua' ? 'Semua Status' : status,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onStatusFilterChanged(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 900
                  ? 3
                  : width >= 520
                  ? 2
                  : 1;
              final cards = [
                _statCard(
                  t,
                  'Total Pengguna',
                  summary['total_users'] ?? 0,
                  Icons.people_alt_rounded,
                  AdminTheme.kPrimary,
                ),
                _statCard(
                  t,
                  'Aktif / Nonaktif',
                  '${summary['active_users'] ?? 0} / ${summary['inactive_users'] ?? 0}',
                  Icons.person_rounded,
                  const Color(0xFF4F8A5B),
                ),
                _statCard(
                  t,
                  'Total Laporan',
                  summary['total_reports'] ?? 0,
                  Icons.description_rounded,
                  Colors.blue,
                ),
                _statCard(
                  t,
                  'Menunggu',
                  summary['pending_reports'] ?? 0,
                  Icons.pending_actions_rounded,
                  Colors.orange,
                ),
                _statCard(
                  t,
                  'Diproses',
                  summary['processed_reports'] ?? 0,
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
              ];
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: crossAxisCount == 1 ? 3.4 : 2.5,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Aktivitas Laporan Terbaru',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (reports.isEmpty)
            const Card(
              child: ListTile(title: Text('Belum ada aktivitas laporan.')),
            )
          else
            ...reports.map((raw) {
              final report = Map<String, dynamic>.from(raw as Map);
              final user = report['user'] is Map
                  ? Map<String, dynamic>.from(report['user'])
                  : <String, dynamic>{};
              final photos = report['photos'] is List
                  ? List<dynamic>.from(report['photos'])
                  : <dynamic>[];
              final latitude =
                  report['latitude']?.toString() ??
                  (photos.isNotEmpty && photos.first is Map
                      ? photos.first['latitude']?.toString()
                      : null);
              final longitude =
                  report['longitude']?.toString() ??
                  (photos.isNotEmpty && photos.first is Map
                      ? photos.first['longitude']?.toString()
                      : null);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(report['title']?.toString() ?? 'Laporan'),
                  subtitle: Text(
                    '${user['name'] ?? 'Pengguna'} • ${report['location'] ?? '-'}\n'
                    'Koordinat: ${latitude ?? '-'}, ${longitude ?? '-'}',
                  ),
                  trailing: TextButton(
                    onPressed: () => onUpdateReportStatus(report),
                    child: Text(report['status']?.toString() ?? 'draft'),
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          Text(
            'Pengguna Terakhir Aktif',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (lastActiveUsers.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Belum ada data aktivitas pengguna.'),
              ),
            )
          else
            ...lastActiveUsers.map((raw) {
              final user = Map<String, dynamic>.from(raw as Map);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AdminTheme.kLightGreen,
                    child: Text(
                      (user['name']?.toString().isNotEmpty == true)
                          ? user['name'].toString()[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(user['name']?.toString() ?? '-'),
                  subtitle: Text(
                    '${user['wilayah'] ?? '-'} • ${user['reports_count'] ?? 0} laporan',
                  ),
                  trailing: Text(user['status']?.toString() ?? 'Aktif'),
                ),
              );
            }),
          const SizedBox(height: 18),
          Text(
            'Statistik Periode',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...periodStats.map((raw) {
            final stat = Map<String, dynamic>.from(raw as Map);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: Text(stat['periode']?.toString() ?? '-'),
                trailing: Text('${stat['total'] ?? 0} laporan'),
              ),
            );
          }),
        ],
      ),
    );
  }
}
