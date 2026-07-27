import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/activity.dart';
import 'models/app_user.dart';
import 'models/category.dart';
import 'models/stored_file.dart';
import 'models/report_template.dart';
import 'services/activity_repository.dart';
import 'services/category_repository.dart';
import 'services/template_repository.dart';
import 'services/garut_geojson_service.dart';
import 'widgets/leaflet_map.dart';
import 'services/user_repository.dart';

const _green = Color(0xFF2E7D32);

class SipenyuluhApp extends StatelessWidget {
  const SipenyuluhApp({super.key, required this.isSupabaseConfigured});
  final bool isSupabaseConfigured;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SIPENYULUH',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _green),
      scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      useMaterial3: true,
    ),
    home: isSupabaseConfigured ? const AuthGate() : const SetupPage(),
  );
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forest, size: 64, color: _green),
            SizedBox(height: 16),
            Text(
              'SIPENYULUH',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Tambahkan SUPABASE_URL dan SUPABASE_ANON_KEY untuk mengaktifkan aplikasi.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) =>
        Supabase.instance.client.auth.currentSession == null
        ? const LoginPage()
        : const DashboardPage(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _loading = false;
  bool _register = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      if (mounted) _message(error.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_register) {
      setState(() => _loading = true);
      try {
        await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'full_name': _name.text.trim()},
        );
        if (mounted) {
          _message('Akun penyuluh dibuat. Periksa email untuk konfirmasi.');
        }
      } on AuthException catch (error) {
        if (mounted) _message(error.message, error: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    await _login();
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : _green,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.forest, color: _green, size: 52),
                const SizedBox(height: 12),
                Text(
                  _register ? 'Daftar Penyuluh' : 'Masuk SIPENYULUH',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                if (_register) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                  ),
                  child: Text(
                    _loading
                        ? 'Memproses...'
                        : (_register ? 'Daftar akun' : 'Masuk'),
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(
                    _register
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Daftar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final ActivityRepository _repository;
  late final UserRepository _userRepository;
  int _index = 0;
  @override
  void initState() {
    super.initState();
    _repository = ActivityRepository(Supabase.instance.client);
    _userRepository = UserRepository(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppUser>(
    future: _userRepository.current(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 54, color: Colors.orange),
                  const SizedBox(height: 14),
                  const Text(
                    'Profil akun belum siap',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Jalankan migration Supabase lalu masuk ulang.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar dan masuk lagi'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return _content(context, snapshot.data!);
    },
  );

  Widget _content(BuildContext context, AppUser user) {
    final isAdmin = user.role == 'admin';
    final pages = [
      OverviewPage(repository: _repository),
      ActivitiesPage(repository: _repository),
      const ArchivePage(),
      if (isAdmin) AdminUsersPage(repository: _userRepository),
      if (isAdmin) const AdminCatalogPage(),
    ];
    final titles = [
      'Dashboard',
      'Kegiatan',
      'Arsip Kegiatan',
      if (isAdmin) 'Kelola Pengguna',
      if (isAdmin) 'Kategori & Template',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final rail = NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          labelType: NavigationRailLabelType.all,
          leading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Icon(Icons.forest, color: _green, size: 34),
          ),
          destinations: [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: Text('Dashboard'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: Text('Kegiatan'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: Text('Arsip'),
            ),
            if (isAdmin)
              const NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Pengguna'),
              ),
            if (isAdmin)
              const NavigationRailDestination(
                icon: Icon(Icons.tune),
                label: Text('Referensi'),
              ),
          ],
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_index]),
            actions: [
              IconButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout),
                tooltip: 'Keluar',
              ),
            ],
          ),
          drawer: wide ? null : Drawer(child: rail),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.event_note_outlined),
                      label: 'Kegiatan',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      label: 'Arsip',
                    ),
                    if (isAdmin)
                      const NavigationDestination(
                        icon: Icon(Icons.people_outline),
                        label: 'Pengguna',
                      ),
                    if (isAdmin)
                      const NavigationDestination(
                        icon: Icon(Icons.tune),
                        label: 'Referensi',
                      ),
                  ],
                ),
          body: Row(
            children: [
              if (wide) rail,
              if (wide) const VerticalDivider(width: 1),
              Expanded(child: pages[_index]),
            ],
          ),
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ActivityForm(repository: _repository),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Kegiatan'),
                )
              : null,
        );
      },
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.repository});
  final ActivityRepository repository;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
    future: repository.list(),
    builder: (_, snapshot) {
      final items = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              MetricCard(
                label: 'Total kegiatan',
                value: '${items.length}',
                icon: Icons.event,
              ),
              const MetricCard(
                label: 'Dokumen',
                value: '-',
                icon: Icons.description,
              ),
              const MetricCard(
                label: 'Foto',
                value: '-',
                icon: Icons.photo_library,
              ),
              const MetricCard(
                label: 'Kategori',
                value: '-',
                icon: Icons.category,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SizedBox(height: 240, child: _ActivityChart(items: items)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Kegiatan terbaru',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...items.take(5).map((item) => ActivityTile(activity: item)),
        ],
      );
    },
  );
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.items});
  final List<Activity> items;
  @override
  Widget build(BuildContext context) => BarChart(
    BarChartData(
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(
        6,
        (index) => BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: items
                  .where((item) => item.activityDate.month == index + 1)
                  .length
                  .toDouble(),
              color: _green,
              width: 24,
            ),
          ],
        ),
      ),
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _green.withValues(alpha: .12),
              child: Icon(icon, color: _green),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key, required this.repository});
  final ActivityRepository repository;
  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
    future: widget.repository.list(query: _query),
    builder: (_, snapshot) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cari kegiatan, desa, kecamatan, kabupaten',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ...?snapshot.data?.map(
            (activity) =>
                ActivityTile(activity: activity, repository: widget.repository),
          ),
      ],
    ),
  );
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.activity, this.repository});
  final Activity activity;
  final ActivityRepository? repository;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: repository == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActivityDetailPage(
                  activity: activity,
                  repository: repository!,
                ),
              ),
            ),
      leading: const CircleAvatar(
        backgroundColor: _green,
        child: Icon(Icons.forest, color: Colors.white),
      ),
      title: Text(activity.title),
      subtitle: Text(
        '${activity.categoryName} • ${DateFormat('dd MMM yyyy', 'id_ID').format(activity.activityDate)}\n${activity.village}, ${activity.district}',
      ),
      isThreeLine: true,
      trailing: repository == null
          ? null
          : PopupMenuButton<String>(
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'upload',
                  child: Text('Upload dokumen/foto'),
                ),
                PopupMenuItem(value: 'report', child: Text('Buat laporan')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
              onSelected: (value) => _select(context, value),
            ),
    ),
  );

  Future<void> _select(BuildContext context, String value) async {
    if (value == 'delete') {
      await repository!.delete(activity.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Data berhasil dihapus')));
      }
      return;
    }
    if (value == 'upload') {
      final file = await FilePicker.platform.pickFiles(withData: true);
      if (file?.files.single.bytes != null) {
        await repository!.uploadFile(
          activityId: activity.id,
          name: file!.files.single.name,
          bytes: file.files.single.bytes!,
          contentType: file.files.single.extension?.toLowerCase() == 'png'
              ? 'image/png'
              : file.files.single.extension?.toLowerCase() == 'jpg' ||
                    file.files.single.extension?.toLowerCase() == 'jpeg'
              ? 'image/jpeg'
              : 'application/octet-stream',
          isPhoto: [
            'jpg',
            'jpeg',
            'png',
          ].contains(file.files.single.extension?.toLowerCase()),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Upload berhasil')));
        }
      }
      return;
    }
    try {
      await repository!.createReport(activity.id, 'pdf');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan berhasil dibuat.')),
        );
      }
    } on FunctionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.details.toString())));
      }
    }
  }
}

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.activity,
    required this.repository,
  });
  final Activity activity;
  final ActivityRepository repository;
  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late Future<List<StoredFile>> _documents;
  late Future<List<StoredFile>> _photos;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _documents = widget.repository.media(widget.activity.id, photos: false);
    _photos = widget.repository.media(widget.activity.id, photos: true);
  }

  Future<void> _upload({bool photosOnly = false}) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: photosOnly ? FileType.image : FileType.any,
    );
    for (final file in result?.files ?? <PlatformFile>[]) {
      if (file.bytes == null) continue;
      final extension = file.extension?.toLowerCase();
      final isPhoto = photosOnly || ['jpg', 'jpeg', 'png'].contains(extension);
      await widget.repository.uploadFile(
        activityId: widget.activity.id,
        name: file.name,
        bytes: file.bytes!,
        contentType: isPhoto ? 'image/$extension' : 'application/octet-stream',
        isPhoto: isPhoto,
      );
    }
    if (mounted) {
      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload berhasil')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail kegiatan')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _upload,
      icon: const Icon(Icons.upload_file),
      label: const Text('Upload'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.activity.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        _section('Identitas kegiatan', {
          'Jenis': widget.activity.categoryName,
          'Tanggal': DateFormat(
            'dd MMMM yyyy',
            'id_ID',
          ).format(widget.activity.activityDate),
          'Lokasi': widget.activity.location ?? '-',
          'Wilayah':
              '${widget.activity.village}, ${widget.activity.district}, ${widget.activity.regency}',
          'Kelompok tani': widget.activity.farmerGroup ?? '-',
          'Peserta': '${widget.activity.participantCount} orang',
        }),
        _section('Pelaksanaan', {
          'Materi': widget.activity.material ?? '-',
          'Tujuan': widget.activity.objective ?? '-',
          'Hasil': widget.activity.result ?? '-',
          'Kendala': widget.activity.obstacle ?? '-',
          'Tindak lanjut': widget.activity.followUp ?? '-',
          'Catatan': widget.activity.notes ?? '-',
        }),
        const SizedBox(height: 12),
        Text('Peta lokasi', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LeafletMap(
              latitude: widget.activity.latitude,
              longitude: widget.activity.longitude,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _report('pdf'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Laporan PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _report('docx'),
                icon: const Icon(Icons.description),
                label: const Text('Laporan Word'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Dokumen', style: Theme.of(context).textTheme.titleLarge),
        _mediaList(_documents, false),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Dokumentasi foto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _upload(photosOnly: true),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Tambah foto'),
            ),
          ],
        ),
        _mediaList(_photos, true),
      ],
    ),
  );
  Widget _section(String title, Map<String, String> values) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          ...values.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${entry.key}: ${entry.value}'),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _mediaList(Future<List<StoredFile>> future, bool photo) =>
      FutureBuilder<List<StoredFile>>(
        future: future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada file.'),
            );
          }
          return Column(
            children: items
                .map(
                  (file) => Card(
                    child: ListTile(
                      leading: Icon(photo ? Icons.image : Icons.description),
                      title: Text(file.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await widget.repository.deleteMedia(
                            file,
                            photo: photo,
                          );
                          setState(_reload);
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
  Future<void> _report(String format) async {
    try {
      await widget.repository.createReport(widget.activity.id, format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Laporan $format berhasil dibuat')),
        );
      }
    } on FunctionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.details.toString())));
      }
    }
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.repository});
  final UserRepository repository;
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<AppUser>> _users;
  @override
  void initState() {
    super.initState();
    _users = widget.repository.list();
  }

  void _reload() => setState(() => _users = widget.repository.list());
  @override
  Widget build(BuildContext context) => FutureBuilder<List<AppUser>>(
    future: _users,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('Gagal memuat pengguna: ${snapshot.error}'));
      }
      final users = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Manajemen Pengguna',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Kelola nama, NIP, dan peran akun penyuluh dengan kontrol yang mudah dibaca.',
          ),
          const SizedBox(height: 18),
          ...users.map(
            (user) => Card(
              child: ListTile(
                minVerticalPadding: 14,
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: user.role == 'admin'
                      ? Colors.orange.shade100
                      : _green.withValues(alpha: .15),
                  child: Icon(
                    user.role == 'admin'
                        ? Icons.admin_panel_settings
                        : Icons.person,
                    color: user.role == 'admin'
                        ? Colors.orange.shade800
                        : _green,
                    size: 28,
                  ),
                ),
                title: Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${user.role == 'admin' ? 'Administrator' : 'Penyuluh'}${user.nip == null || user.nip!.isEmpty ? '' : ' • NIP ${user.nip}'}',
                ),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (_) =>
                          UserForm(user: user, repository: widget.repository),
                    );
                    _reload();
                  },
                  child: const Text('Ubah'),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class UserForm extends StatefulWidget {
  const UserForm({super.key, required this.user, required this.repository});
  final AppUser user;
  final UserRepository repository;
  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  late final TextEditingController _name;
  late final TextEditingController _nip;
  late String _role;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.fullName);
    _nip = TextEditingController(text: widget.user.nip);
    _role = widget.user.role;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.update(
        widget.user,
        fullName: _name.text.trim(),
        nip: _nip.text.trim().isEmpty ? null : _nip.text.trim(),
        role: _role,
      );
      if (mounted) Navigator.pop(context);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ubah pengguna'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama lengkap'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nip,
            decoration: const InputDecoration(labelText: 'NIP (opsional)'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Peran'),
            items: const [
              DropdownMenuItem(value: 'penyuluh', child: Text('Penyuluh')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (value) => setState(() => _role = value!),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
      ),
    ],
  );
}

class AdminCatalogPage extends StatefulWidget {
  const AdminCatalogPage({super.key});
  @override
  State<AdminCatalogPage> createState() => _AdminCatalogPageState();
}

class _AdminCatalogPageState extends State<AdminCatalogPage> {
  int _tab = 0;
  final _categories = CategoryRepository(Supabase.instance.client);
  final _templates = TemplateRepository(Supabase.instance.client);
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Kategori')),
          ButtonSegment(value: 1, label: Text('Template laporan')),
        ],
        selected: {_tab},
        onSelectionChanged: (value) => setState(() => _tab = value.first),
      ),
      const SizedBox(height: 18),
      if (_tab == 0) _categoryList() else _templateList(),
    ],
  );
  Widget _categoryList() => FutureBuilder<List<Category>>(
    future: _categories.list(),
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: () => _categoryDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah kategori'),
        ),
        const SizedBox(height: 12),
        ...?snapshot.data?.map(
          (item) => Card(
            child: ListTile(
              title: Text(item.name),
              subtitle: Text(item.description ?? '-'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _categoryDialog(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await _categories.delete(item.id);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _templateList() => FutureBuilder<List<ReportTemplate>>(
    future: _templates.list(),
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: () => _templateDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah template'),
        ),
        const SizedBox(height: 12),
        ...?snapshot.data?.map(
          (item) => Card(
            child: ListTile(
              title: Text(item.name),
              subtitle: Text(item.isActive ? 'Aktif' : 'Nonaktif'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _templateDialog(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await _templates.delete(item.id);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> _categoryDialog([Category? item]) async {
    final name = TextEditingController(text: item?.name);
    final description = TextEditingController(text: item?.description);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null ? 'Kategori baru' : 'Ubah kategori'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama kategori'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              await _categories.save(
                id: item?.id,
                name: name.text,
                description: description.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    setState(() {});
  }

  Future<void> _templateDialog([ReportTemplate? item]) async {
    final name = TextEditingController(text: item?.name);
    final header = TextEditingController(text: item?.headerHtml);
    final body = TextEditingController(text: item?.bodyHtml);
    var active = item?.isActive ?? true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Template baru' : 'Ubah template'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nama template',
                    ),
                  ),
                  TextField(
                    controller: header,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Header / judul laporan',
                    ),
                  ),
                  TextField(
                    controller: body,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Isi template',
                    ),
                  ),
                  SwitchListTile(
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                    title: const Text('Template aktif'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                await _templates.save(
                  id: item?.id,
                  name: name.text,
                  header: header.text,
                  body: body.text,
                  active: active,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Arsip: Tahun → Bulan → Jenis kegiatan → Nama kegiatan'),
  );
}

class ActivityForm extends StatefulWidget {
  const ActivityForm({super.key, required this.repository});
  final ActivityRepository repository;
  @override
  State<ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<ActivityForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _village = TextEditingController();
  final _district = TextEditingController();
  final _regency = TextEditingController();
  final _group = TextEditingController();
  final _participants = TextEditingController();
  final _material = TextEditingController();
  final _objective = TextEditingController();
  final _result = TextEditingController();
  final _obstacle = TextEditingController();
  final _followUp = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _categoryId;
  double? _latitude;
  double? _longitude;
  late final Future<List<String>> _garutDistricts;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _garutDistricts = GarutGeoJsonService().districts();
  }

  Future<void> _useMyLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Layanan lokasi perangkat tidak aktif');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi belum diberikan');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _location.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.create({
        'title': _title.text,
        'category_id': _categoryId,
        'activity_date': DateFormat('yyyy-MM-dd').format(_date),
        'location': _location.text,
        'latitude': _latitude,
        'longitude': _longitude,
        'village': _village.text,
        'district': _district.text,
        'regency': _regency.text,
        'farmer_group': _group.text,
        'participant_count': int.tryParse(_participants.text) ?? 0,
        'material': _material.text,
        'objective': _objective.text,
        'result': _result.text,
        'obstacle': _obstacle.text,
        'follow_up': _followUp.text,
        'notes': _notes.text,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Data berhasil disimpan')));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kegiatan baru'),
    content: SizedBox(
      width: 500,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _field(_title, 'Judul kegiatan'),
              FutureBuilder<List<Category>>(
                future: CategoryRepository(Supabase.instance.client).list(),
                builder: (context, snapshot) => DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Jenis kegiatan',
                  ),
                  items: snapshot.data
                      ?.map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal kegiatan'),
                subtitle: Text(
                  DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_date),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: _date,
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              _optional(_location, 'Lokasi'),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _useMyLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    _latitude == null
                        ? 'Gunakan lokasi saya'
                        : 'Lokasi tersimpan',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LeafletMap(latitude: _latitude, longitude: _longitude),
                ),
              ),
              _field(_village, 'Desa'),
              FutureBuilder<List<String>>(
                future: _garutDistricts,
                builder: (context, snapshot) => snapshot.hasData
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: _district.text.isEmpty
                              ? null
                              : _district.text,
                          decoration: const InputDecoration(
                            labelText: 'Kecamatan Garut (GeoJSON)',
                          ),
                          items: snapshot.data!
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => _district.text = value ?? '',
                        ),
                      )
                    : _field(_district, 'Kecamatan'),
              ),
              _field(_regency, 'Kabupaten'),
              _optional(_group, 'Nama kelompok tani'),
              TextFormField(
                controller: _participants,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah peserta'),
              ),
              _optional(_material, 'Materi penyuluhan', lines: 3),
              _optional(_objective, 'Tujuan kegiatan', lines: 3),
              _optional(_result, 'Hasil kegiatan', lines: 3),
              _optional(_obstacle, 'Kendala', lines: 3),
              _optional(_followUp, 'Tindak lanjut', lines: 3),
              _optional(_notes, 'Catatan', lines: 3),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
      ),
    ],
  );
  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.isEmpty ? 'Wajib diisi' : null,
    ),
  );
  Widget _optional(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
    ),
  );
}
