import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

class MateriPage extends StatefulWidget {
  const MateriPage({super.key});

  @override
  State<MateriPage> createState() => _MateriPageState();
}

class _MateriPageState extends State<MateriPage> {
  static const String _storageKey = 'phonebook_shared_materials_v2';

  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  String _currentUserName = 'Penyuluh Kehutanan';
  String _currentUserRole = 'user';
  String _currentUserEmail = '';

  final List<String> _categories = [
    'Semua',
    'Penyuluhan',
    'Konservasi & Ekosistem',
    'Kebakaran Hutan',
    'Rehabilitasi Hutan',
    'Kelembagaan KTH',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAndMaterials();
  }

  Future<void> _loadUserAndMaterials() async {
    final prefs = await SharedPreferences.getInstance();

    final name = prefs.getString('profil_nama') ??
        prefs.getString('name') ??
        'Penyuluh Kehutanan';
    final role = (prefs.getString('role') ?? 'user').toLowerCase();
    final email = prefs.getString('email') ?? '';

    if (mounted) {
      setState(() {
        _currentUserName = name;
        _currentUserRole = role;
        _currentUserEmail = email;
      });
    }

    // 1. Muat dari Local Storage (SharedPreferences)
    final rawStored = prefs.getString(_storageKey);
    List<Map<String, dynamic>> loadedList = [];

    if (rawStored != null && rawStored.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawStored);
        loadedList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Error decoding cached materials: $e');
      }
    }

    // Jika belum ada data lokal, inisialisasi dengan materi edukasi default
    if (loadedList.isEmpty) {
      loadedList = _buildDefaultMaterials();
      await prefs.setString(_storageKey, jsonEncode(loadedList));
    }

    if (mounted) {
      setState(() {
        _materials = loadedList;
        _isLoading = false;
      });
    }

    // 2. Fetch live data dari server backend
    _fetchLiveMaterialsFromServer(prefs);
  }

  Future<void> _fetchLiveMaterialsFromServer(SharedPreferences prefs) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}/api/materials'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> serverList = data['data'];

          final List<Map<String, dynamic>> merged = [];
          for (final item in serverList) {
            final userObj = item['user'] as Map<String, dynamic>?;
            final uploaderName = (item['uploader_name'] ??
                    item['uploader'] ??
                    userObj?['name'] ??
                    'Administrator Kehutanan')
                .toString();

            final uploaderRole = (item['uploader_role'] ??
                    userObj?['role'] ??
                    'user')
                .toString();

            merged.add({
              'id': item['id']?.toString() ?? 'MAT-${DateTime.now().millisecondsSinceEpoch}',
              'title': item['title'] ?? 'Materi Kehutanan',
              'type': (item['file_type'] ?? 'PDF').toString().toUpperCase(),
              'category': item['category_name'] ??
                  item['category']?['name'] ??
                  'Penyuluhan',
              'description': item['description'] ?? '',
              'uploader_name': uploaderName,
              'uploader_role': uploaderRole,
              'file_name': item['file_name'] ?? 'Dokumen_Materi.pdf',
              'uploaded_at': _formatServerDate(item['created_at']),
            });
          }

          // Gabungkan dengan materi lokal yang belum ada di server
          for (final local in _materials) {
            final exists = merged.any((m) =>
                m['title'].toString().toLowerCase() ==
                local['title'].toString().toLowerCase());
            if (!exists) {
              merged.add(local);
            }
          }

          if (mounted) {
            setState(() {
              _materials = merged;
            });
          }
          await prefs.setString(_storageKey, jsonEncode(merged));
        }
      }
    } catch (e) {
      debugPrint('Background fetch materials error: $e');
    }
  }

  String _formatServerDate(dynamic dateVal) {
    if (dateVal == null) return 'Baru saja';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month]} ${dt.year}, $hour:$min';
    } catch (_) {
      return dateVal.toString();
    }
  }

  List<Map<String, dynamic>> _buildDefaultMaterials() {
    return [
      {
        'id': 'MAT-001',
        'title': 'Pedoman Penyuluhan Kehutanan & Pembinaan KTH',
        'type': 'PDF',
        'category': 'Penyuluhan',
        'description':
            'Panduan teknis kegiatan penyuluhan kehutanan lapangan, pembentukan kelompok tani hutan, peningkatan kelas kelembagaan dari Pemula ke Madya, serta pengembangan agroforestri produktif.',
        'uploader_name': 'Rizky Pratama, S.Hut.',
        'uploader_role': 'Penyuluh Kehutanan (CDK Garut)',
        'file_name': 'Buku_Pedoman_Penyuluhan_Kehutanan_2026.pdf',
        'uploaded_at': '3 Nov 2026, 09:15',
      },
      {
        'id': 'MAT-002',
        'title': 'Manual Konservasi Ekosistem & Patroli Kawasan Hutan',
        'type': 'PDF',
        'category': 'Konservasi & Ekosistem',
        'description':
            'Metodologi pemetaan koridor satwa, identifikasi flora langka dilindungi, pencegahan perambahan kawasan konservasi, serta inventarisasi keanekaragaman hayati.',
        'uploader_name': 'Siti Nurhaliza, S.Hut.',
        'uploader_role': 'Penyuluh Kehutanan (Kec. Cisurupan)',
        'file_name': 'Manual_Konservasi_Hutan_Lindung.pdf',
        'uploaded_at': '2 Nov 2026, 14:20',
      },
      {
        'id': 'MAT-003',
        'title': 'SOP Mitigasi & Pengendalian Kebakaran Hutan (Karhutla)',
        'type': 'DOC',
        'category': 'Kebakaran Hutan',
        'description':
            'Prosedur operasional standar deteksi dini hotspot berbasis satelit, mobilisasi regu Masyarakat Peduli Api (MPA), dan teknik sekat bakar pencegah kebakaran meluas.',
        'uploader_name': 'Administrator Kehutanan',
        'uploader_role': 'Admin Dinas Kehutanan',
        'file_name': 'SOP_Pengendalian_Karhutla_v2.docx',
        'uploaded_at': '1 Nov 2026, 08:30',
      },
      {
        'id': 'MAT-004',
        'title': 'Modul Teknis Rehabilitasi Hutan & Lahan (RHL)',
        'type': 'PPT',
        'category': 'Rehabilitasi Hutan',
        'description':
            'Teknik pembibitan bibit tanaman hutan unggul MPTS (Multi-Purpose Tree Species), teknik penanaman kontur lereng curam, dan pemeliharaan tegakan.',
        'uploader_name': 'Budi Santoso, M.Si.',
        'uploader_role': 'Koordinator CDK Wilayah',
        'file_name': 'Presentasi_Teknik_RHL_2026.pptx',
        'uploaded_at': '28 Okt 2026, 11:45',
      },
      {
        'id': 'MAT-005',
        'title': 'Sertifikasi & Standar Legalitas Kayu Rakyat (SVLK)',
        'type': 'PDF',
        'category': 'Kelembagaan KTH',
        'description':
            'Tata kelola pengurusan dokumen legalitas hasil hutan rakyat (DKR) untuk memperluas akses pasar dan meningkatkan harga jual komoditas petani binaan.',
        'uploader_name': 'Andi Wijaya, S.Hut.',
        'uploader_role': 'Penyuluh Kehutanan (Gunung Guntur)',
        'file_name': 'Panduan_SVLK_Kayu_Rakyat.pdf',
        'uploaded_at': '25 Okt 2026, 16:10',
      },
    ];
  }

  List<Map<String, dynamic>> get _filteredMaterials {
    return _materials.where((material) {
      final title = (material['title'] ?? '').toString().toLowerCase();
      final desc = (material['description'] ?? '').toString().toLowerCase();
      final uploader = (material['uploader_name'] ?? '').toString().toLowerCase();
      final category = (material['category'] ?? '').toString();

      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          uploader.contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'Semua' || category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  /// Membuka form modal upload materi baru
  void _showUploadMaterialModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final fileNameCtrl = TextEditingController();
    String selectedCat = 'Penyuluhan';
    String selectedType = 'PDF';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Modal
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              color: Color(0xFFF57C00),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Upload Materi Edukasi Baru',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E2923),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Materi akan terlihat oleh seluruh user & penyuluh.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Info Uploader Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              color: Color(0xFF2E7D32),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Color(0xFF1E3F24),
                                    fontSize: 12.5,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Diupload oleh: '),
                                    TextSpan(
                                      text: _currentUserName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _currentUserRole == 'admin'
                                          ? ' (Administrator)'
                                          : ' (Akun Anda)',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Judul Materi
                      const Text(
                        'Judul Materi Edukasi *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: _inputDecoration(
                          hint: 'Contoh: Panduan Teknis Budidaya Madu Hutan',
                          icon: Icons.title_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Judul materi wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Kategori & Tipe Baris
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kategori *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: selectedCat,
                                  decoration: _inputDecoration(
                                    hint: 'Kategori',
                                    icon: Icons.category_outlined,
                                  ),
                                  items: _categories
                                      .where((c) => c != 'Semua')
                                      .map(
                                        (cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Text(
                                            cat,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => selectedCat = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Format File *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: selectedType,
                                  decoration: _inputDecoration(
                                    hint: 'Format',
                                    icon: Icons.insert_drive_file_outlined,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                                    DropdownMenuItem(value: 'DOC', child: Text('Word (DOC)')),
                                    DropdownMenuItem(value: 'PPT', child: Text('PPT Slides')),
                                    DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                                    DropdownMenuItem(value: 'PANDUAN', child: Text('Panduan / Link')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => selectedType = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Nama Berkas / Dokumen
                      const Text(
                        'Nama File / Dokumen (Opsional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: fileNameCtrl,
                        decoration: _inputDecoration(
                          hint: 'Contoh: Panduan_Budidaya_Madu_2026.pdf',
                          icon: Icons.attach_file_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Deskripsi Materi
                      const Text(
                        'Deskripsi & Rangkuman Materi *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          hint: 'Jelaskan tujuan edukasi, sasaran penyuluhan, dan isi materi...',
                          icon: Icons.description_outlined,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Deskripsi materi wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      // Tombol Submit
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF57C00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final now = DateTime.now();
                            final months = [
                              '',
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'Mei',
                              'Jun',
                              'Jul',
                              'Agu',
                              'Sep',
                              'Okt',
                              'Nov',
                              'Des'
                            ];
                            final timeFormatted =
                                '${now.day} ${months[now.month]} ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                            final newMaterial = {
                              'id': 'MAT-${DateTime.now().millisecondsSinceEpoch}',
                              'title': titleCtrl.text.trim(),
                              'category': selectedCat,
                              'type': selectedType,
                              'file_name': fileNameCtrl.text.trim().isNotEmpty
                                  ? fileNameCtrl.text.trim()
                                  : '${titleCtrl.text.trim().replaceAll(' ', '_')}.${selectedType.toLowerCase()}',
                              'description': descCtrl.text.trim(),
                              'uploader_name': _currentUserName,
                              'uploader_role': _currentUserRole == 'admin'
                                  ? 'Administrator Kehutanan'
                                  : 'Penyuluh Kehutanan',
                              'uploaded_at': timeFormatted,
                            };

                            Navigator.pop(ctx);
                            await _saveNewMaterial(newMaterial);
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text(
                            'Upload & Publikasikan Materi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  Future<void> _saveNewMaterial(Map<String, dynamic> newMaterial) async {
    setState(() {
      _materials.insert(0, newMaterial);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_materials));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Materi edukasi berhasil diupload oleh ${_currentUserName} dan terlihat oleh semua user.',
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );

    // Kirim juga ke server backend secara asinkron
    try {
      final token = prefs.getString('token');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/api/materials/public'),
            headers: headers,
            body: jsonEncode({
              'title': newMaterial['title'],
              'category_name': newMaterial['category'],
              'file_type': newMaterial['type'],
              'file_name': newMaterial['file_name'],
              'description': newMaterial['description'],
              'uploader_name': newMaterial['uploader_name'],
              'uploader_role': newMaterial['uploader_role'],
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Background backend upload material: $e');
    }
  }

  void _showMaterialDetail(Map<String, dynamic> material) {
    final type = (material['type'] ?? 'PDF').toString().toUpperCase();
    final uploaderName = (material['uploader_name'] ?? 'Penyuluh Kehutanan').toString();
    final uploaderRole = (material['uploader_role'] ?? 'Penyuluh').toString();
    final uploadedAt = (material['uploaded_at'] ?? 'Baru saja').toString();
    final title = (material['title'] ?? '').toString();
    final desc = (material['description'] ?? '').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final fileName = (material['file_name'] ?? 'Dokumen_Materi.pdf').toString();

    final isUploader = uploaderName.toLowerCase() == _currentUserName.toLowerCase() ||
        _currentUserRole == 'admin';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Materi
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _getTypeColor(type).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getTypeIcon(type),
                      color: _getTypeColor(type),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2923),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),

              // KARTU INFORMASI PENGUNGGAH (UPLOADED BY)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBF9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      child: Text(
                        uploaderName.isNotEmpty
                            ? uploaderName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Diupload oleh',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: uploaderRole.toLowerCase().contains('admin')
                                      ? Colors.deepPurple.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  uploaderRole.toLowerCase().contains('admin')
                                      ? 'Admin'
                                      : 'Penyuluh',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: uploaderRole.toLowerCase().contains('admin')
                                        ? Colors.deepPurple.shade800
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            uploaderName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2923),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            uploadedAt,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Deskripsi
              const Text(
                'Deskripsi Materi:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2923),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF374151),
                ),
              ),

              const SizedBox(height: 14),

              // File attachment row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tombol Buka Materi & Hapus
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Membuka berkas: $fileName'),
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        label: const Text(
                          'Buka / Baca Materi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  if (isUploader) ...[
                    const SizedBox(width: 10),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Hapus Materi Ini',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDeleteMaterial(material);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteMaterial(Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Materi?'),
        content: Text(
          'Materi "${material['title']}" akan dihapus dari daftar publik.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _materials.removeWhere((m) => m['id'] == material['id']);
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_storageKey, jsonEncode(_materials));

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Materi berhasil dihapus.')),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return const Color(0xFFE65100);
      case 'DOC':
      case 'WORD':
        return const Color(0xFF1565C0);
      case 'PPT':
      case 'SLIDES':
        return const Color(0xFFD84315);
      case 'VIDEO':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'DOC':
      case 'WORD':
        return Icons.description_rounded;
      case 'PPT':
      case 'SLIDES':
        return Icons.slideshow_rounded;
      case 'VIDEO':
        return Icons.play_circle_fill_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
      filled: true,
      fillColor: const Color(0xFFF9FBF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMaterials;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          'Materi Edukasi Kehutanan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1E2923),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2E7D32)),
            tooltip: 'Segarkan Materi',
            onPressed: () async {
              setState(() => _isLoading = true);
              final prefs = await SharedPreferences.getInstance();
              await _fetchLiveMaterialsFromServer(prefs);
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2E7D32),
        onRefresh: () async {
          final prefs = await SharedPreferences.getInstance();
          await _fetchLiveMaterialsFromServer(prefs);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 80),
          children: [
            // Banner Edukasi Publik
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF285C2E), Color(0xFF388E3C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF285C2E).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Materi Edukasi Bersama',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Dapat diakses oleh seluruh user & penyuluh. Lengkapi referensi dan panduan lapangan Anda.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Kolom Pencarian
            TextField(
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              decoration: InputDecoration(
                hintText: 'Cari materi, kategori, atau nama pengunggah...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2E7D32)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Kategori Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      selectedColor: const Color(0xFF2E7D32),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade300,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            // Header Daftar & Jumlah
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Materi Edukasi',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2923),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filtered.length} Materi',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                ),
              )
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada materi yang sesuai',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coba ubah kata kunci pencarian atau kategori filter.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )
            else
              ...filtered.map((material) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MaterialCard(
                    material: material,
                    typeColor: _getTypeColor(
                      (material['type'] ?? 'PDF').toString(),
                    ),
                    typeIcon: _getTypeIcon(
                      (material['type'] ?? 'PDF').toString(),
                    ),
                    onTap: () => _showMaterialDetail(material),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadMaterialModal,
        backgroundColor: const Color(0xFFF57C00),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text(
          'Upload Materi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final Color typeColor;
  final IconData typeIcon;
  final VoidCallback onTap;

  const _MaterialCard({
    required this.material,
    required this.typeColor,
    required this.typeIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (material['title'] ?? '').toString();
    final type = (material['type'] ?? 'PDF').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final uploaderName = (material['uploader_name'] ?? 'Penyuluh Kehutanan').toString();
    final uploaderRole = (material['uploader_role'] ?? 'Penyuluh').toString();
    final uploadedAt = (material['uploaded_at'] ?? 'Baru saja').toString();
    final description = (material['description'] ?? '').toString();

    final isAdmin = uploaderRole.toLowerCase().contains('admin');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Atas: Ikon + Judul + Kategori Tag
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2923),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // BARIS UPLOAD BY SIAPA SIAPANYA
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isAdmin
                      ? Colors.deepPurple.shade100
                      : const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  child: Text(
                    uploaderName.isNotEmpty
                        ? uploaderName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isAdmin
                          ? Colors.deepPurple.shade800
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      children: [
                        const TextSpan(text: 'Diupload oleh: '),
                        TextSpan(
                          text: uploaderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2923),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  uploadedAt,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
