import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../constants/api_constants.dart';
import '../../services/material_download_service.dart';
import '../../services/notification_service.dart';

class MateriPage extends StatefulWidget {
  final String? initialMaterialId;
  final String? initialMaterialTitle;

  const MateriPage({
    super.key,
    this.initialMaterialId,
    this.initialMaterialTitle,
  });

  @override
  State<MateriPage> createState() => _MateriPageState();
}

class _MateriPageState extends State<MateriPage> {
  static const String _storageKey = 'phonebook_shared_materials_v2';
  static const Set<String> _legacyDummyMaterialIds = {
    'MAT-001',
    'MAT-002',
    'MAT-003',
    'MAT-004',
    'MAT-005',
  };

  List<Map<String, dynamic>> _materials = [];
  final Set<String> _downloadingIds = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _didOpenInitialMaterial = false;
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

  static bool _isDummyMaterial(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString().trim().toUpperCase();
    final uploader =
        (item['uploader_name'] ?? '').toString().trim().toLowerCase();
    return _legacyDummyMaterialIds.contains(id) ||
        uploader == 'andi wijaya, s.hut.';
  }

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
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // 1. Muat dari Local Storage (SharedPreferences) & bersihkan sisa data dummy lama
    final rawStored = prefs.getString(_storageKey);
    List<Map<String, dynamic>> loadedList = [];

    if (rawStored != null && rawStored.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawStored);
        loadedList = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) => !_isDummyMaterial(m))
            .toList();
        await prefs.setString(_storageKey, jsonEncode(loadedList));
      } catch (e) {
        debugPrint('Error decoding cached materials: $e');
      }
    }

    if (mounted) {
      setState(() {
        _materials = loadedList;
      });
    }

    // 2. Fetch live data dari server backend
    await _fetchLiveMaterialsFromServer(prefs);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _checkAndOpenInitialMaterial();
    }
  }

  void _checkAndOpenInitialMaterial() {
    if (_didOpenInitialMaterial) return;
    final targetId = widget.initialMaterialId?.trim();
    final targetTitle = widget.initialMaterialTitle?.trim().toLowerCase();
    if ((targetId == null || targetId.isEmpty) &&
        (targetTitle == null || targetTitle.isEmpty)) {
      return;
    }

    Map<String, dynamic>? matched;
    if (targetId != null && targetId.isNotEmpty) {
      for (final m in _materials) {
        if ((m['id'] ?? '').toString().trim() == targetId) {
          matched = m;
          break;
        }
      }
    }
    if (matched == null && targetTitle != null && targetTitle.isNotEmpty) {
      for (final m in _materials) {
        final t = (m['title'] ?? '').toString().trim().toLowerCase();
        if (t == targetTitle || t.contains(targetTitle)) {
          matched = m;
          break;
        }
      }
    }

    if (matched != null) {
      _didOpenInitialMaterial = true;
      final itemToOpen = matched;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMaterialDetail(itemToOpen);
        }
      });
    }
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
            final mapItem = Map<String, dynamic>.from(item);
            if (_isDummyMaterial(mapItem)) continue;

            final userObj = mapItem['user'] as Map<String, dynamic>?;
            final uploaderName = (mapItem['uploader_name'] ??
                    mapItem['uploader'] ??
                    userObj?['name'] ??
                    'Penyuluh Kehutanan')
                .toString();

            final uploaderRole = (mapItem['uploader_role'] ??
                    userObj?['role'] ??
                    'user')
                .toString();

            final rawFilePath = (mapItem['file_path'] ?? '').toString();
            final rawDriveUrl = (mapItem['drive_url'] ?? '').toString();

            final existingLocal =
                _materials.cast<Map<String, dynamic>?>().firstWhere(
                      (m) =>
                          m != null &&
                          (m['id']?.toString() == mapItem['id']?.toString() ||
                              m['title']?.toString().toLowerCase() ==
                                  (mapItem['title'] ?? '')
                                      .toString()
                                      .toLowerCase()),
                      orElse: () => null,
                    );

            merged.add({
              'id': mapItem['id']?.toString() ??
                  'MAT-${DateTime.now().millisecondsSinceEpoch}',
              'title': mapItem['title'] ?? 'Materi Kehutanan',
              'type': (mapItem['file_type'] ?? 'PDF').toString().toUpperCase(),
              'category': mapItem['category_name'] ??
                  mapItem['category']?['name'] ??
                  'Penyuluhan',
              'description': mapItem['description'] ?? '',
              'uploader_name': uploaderName,
              'uploader_role': uploaderRole,
              'file_name': mapItem['file_name'] ?? 'Dokumen_Materi.pdf',
              'file_size': existingLocal?['file_size'] ?? '',
              'file_path': rawFilePath,
              'drive_url': rawDriveUrl.isNotEmpty ? rawDriveUrl : rawFilePath,
              'file_data_uri': existingLocal?['file_data_uri'] ?? '',
              'uploaded_at': _formatServerDate(mapItem['created_at']),
            });
          }

          // Gabungkan dengan materi lokal asli (bukan dummy) yang belum ada di server
          for (final local in _materials) {
            if (_isDummyMaterial(local)) continue;
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
              _errorMessage = null;
            });
          }
          await prefs.setString(_storageKey, jsonEncode(merged));
        }
      } else if (_materials.isEmpty && mounted) {
        setState(() {
          _errorMessage =
              'Gagal memuat materi dari server (Status ${response.statusCode}).';
        });
      }
    } catch (e) {
      debugPrint('Background fetch materials error: $e');
      if (_materials.isEmpty && mounted) {
        setState(() {
          _errorMessage =
              'Tidak dapat terhubung ke server untuk memuat materi. Periksa koneksi internet Anda.';
        });
      }
    }
  }

  String _formatServerDate(dynamic dateVal) {
    if (dateVal == null) return 'Baru saja';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      const months = [
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

  List<Map<String, dynamic>> get _filteredMaterials {
    return _materials.where((material) {
      final title = (material['title'] ?? '').toString().toLowerCase();
      final desc = (material['description'] ?? '').toString().toLowerCase();
      final uploader =
          (material['uploader_name'] ?? '').toString().toLowerCase();
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

  String _safeFilePath(PlatformFile? file) {
    if (file == null || kIsWeb) return '';
    try {
      return file.path ?? '';
    } catch (_) {
      return '';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'mp4':
        return 'video/mp4';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<PlatformFile?> _pickLocalFileSafe() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: [
          'pdf',
          'ppt',
          'pptx',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'mp4',
          'txt',
          'jpg',
          'jpeg',
          'png',
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
      return null;
    } catch (filePickerErr) {
      debugPrint(
        'FilePicker.platform belum terinisialisasi ($filePickerErr), beralih ke pemilih berkas bawaan...',
      );
    }

    try {
      final picker = ImagePicker();
      XFile? xfile;
      try {
        xfile = await picker.pickMedia();
      } catch (_) {
        xfile = await picker.pickImage(source: ImageSource.gallery);
      }

      if (xfile == null) return null;

      final bytes = await xfile.readAsBytes();
      final fileName = xfile.name.isNotEmpty
          ? xfile.name
          : 'Dokumen_${DateTime.now().millisecondsSinceEpoch}';

      return PlatformFile(
        name: fileName,
        size: bytes.length,
        bytes: bytes,
        path: kIsWeb ? null : xfile.path,
      );
    } catch (fallbackErr) {
      debugPrint('Fallback picker error: $fallbackErr');
      rethrow;
    }
  }

  /// Membuka form modal upload materi baru dengan File Picker & Google Drive (Mendukung Dark & Light Mode)
  void _showUploadMaterialModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final fileNameCtrl = TextEditingController();
    final driveUrlCtrl = TextEditingController();
    String selectedCat = 'Penyuluhan';
    String selectedType = 'PDF';
    bool isGoogleDriveSource = false;
    PlatformFile? selectedFile;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final labelColor =
                isDark ? Colors.white : const Color(0xFF1E2923);
            final subLabelColor =
                isDark ? Colors.white70 : Colors.grey.shade600;

            Future<void> pickFileFromDevice() async {
              try {
                final file = await _pickLocalFileSafe();

                if (file != null) {
                  selectedFile = file;
                  fileNameCtrl.text = file.name;

                  final ext = file.name.contains('.')
                      ? file.name.split('.').last.toLowerCase()
                      : (file.extension ?? '').toLowerCase();
                  if (ext == 'pdf') {
                    selectedType = 'PDF';
                  } else if (ext == 'ppt' || ext == 'pptx') {
                    selectedType = 'PPT';
                  } else if (ext == 'doc' || ext == 'docx') {
                    selectedType = 'DOC';
                  } else if (ext == 'xls' || ext == 'xlsx') {
                    selectedType = 'XLS';
                  } else if (ext == 'mp4' || ext == 'mov' || ext == 'avi') {
                    selectedType = 'VIDEO';
                  }

                  if (titleCtrl.text.trim().isEmpty) {
                    final nameNoExt = file.name.contains('.')
                        ? file.name.substring(0, file.name.lastIndexOf('.'))
                        : file.name;
                    titleCtrl.text = nameNoExt
                        .replaceAll('_', ' ')
                        .replaceAll('-', ' ');
                  }

                  setModalState(() {});
                }
              } catch (e) {
                debugPrint('Error memilih file: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal memilih file: $e'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            }

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
                              color: isGoogleDriveSource
                                  ? (isDark
                                      ? const Color(0xFF152C44)
                                      : const Color(0xFFE8F0FE))
                                  : (isDark
                                      ? const Color(0xFF3A2714)
                                      : const Color(0xFFFFF3E0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isGoogleDriveSource
                                  ? Icons.add_to_drive_rounded
                                  : Icons.cloud_upload_outlined,
                              color: isGoogleDriveSource
                                  ? const Color(0xFF4285F4)
                                  : const Color(0xFFF57C00),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Upload Materi Edukasi Baru',
                                  style: TextStyle(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.bold,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Materi akan terlihat oleh seluruh user & penyuluh.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subLabelColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: labelColor),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 10),

                      // Info Uploader Banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B3224)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2E5239)
                                : const Color(0xFFC8E6C9),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_circle_outlined,
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFF2E7D32),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E3F24),
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
                                          ? ' (Admin)'
                                          : ' (Akun Anda)',
                                      style: TextStyle(
                                        color: subLabelColor,
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
                      const SizedBox(height: 14),

                      // Judul Materi
                      Text(
                        'Judul Materi Edukasi *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleCtrl,
                        style: TextStyle(color: labelColor),
                        decoration: _inputDecoration(
                          hint: 'Contoh: Panduan Teknis Budidaya Madu Hutan',
                          icon: Icons.title_rounded,
                          isDark: isDark,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Judul materi wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Kategori & Format File Baris
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kategori *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCat,
                                  isExpanded: true,
                                  dropdownColor: Theme.of(context).cardColor,
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: 12.5,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: 'Kategori',
                                    icon: Icons.category_outlined,
                                    isDark: isDark,
                                  ),
                                  items: _categories
                                      .where((c) => c != 'Semua')
                                      .map(
                                        (cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Text(
                                            cat,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: labelColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                                Text(
                                  'Format File *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedType,
                                  isExpanded: true,
                                  dropdownColor: Theme.of(context).cardColor,
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: 12.5,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: 'Format',
                                    icon: Icons.insert_drive_file_outlined,
                                    isDark: isDark,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'PDF',
                                      child: Text(
                                        'PDF',
                                        style: TextStyle(color: labelColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'PPT',
                                      child: Text(
                                        'PPT Slides',
                                        style: TextStyle(color: labelColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'DOC',
                                      child: Text(
                                        'Word (DOC)',
                                        style: TextStyle(color: labelColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'XLS',
                                      child: Text(
                                        'Excel (XLS)',
                                        style: TextStyle(color: labelColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'VIDEO',
                                      child: Text(
                                        'Video',
                                        style: TextStyle(color: labelColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'PANDUAN',
                                      child: Text(
                                        'Panduan Link',
                                        style: TextStyle(color: labelColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
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
                      const SizedBox(height: 16),

                      // BAGIAN PILIH FILE MATERI (FILE PICKER LOKAL / GOOGLE DRIVE)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'File / Dokumen Materi *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: labelColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF243329)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2E3D34)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => setModalState(
                                    () => isGoogleDriveSource = false,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !isGoogleDriveSource
                                          ? const Color(0xFF2E7D32)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.folder_open_rounded,
                                          size: 14,
                                          color: !isGoogleDriveSource
                                              ? Colors.white
                                              : subLabelColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Folder Lokal',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: !isGoogleDriveSource
                                                ? Colors.white
                                                : subLabelColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setModalState(
                                    () => isGoogleDriveSource = true,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isGoogleDriveSource
                                          ? const Color(0xFF1A73E8)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_to_drive_rounded,
                                          size: 14,
                                          color: isGoogleDriveSource
                                              ? Colors.white
                                              : Colors.blue.shade400,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Google Drive',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isGoogleDriveSource
                                                ? Colors.white
                                                : subLabelColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (!isGoogleDriveSource) ...[
                        InkWell(
                          onTap: pickFileFromDevice,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selectedFile != null
                                  ? (isDark
                                      ? const Color(0xFF1B3224)
                                      : const Color(0xFFE8F5E9))
                                  : (isDark
                                      ? const Color(0xFF243329)
                                      : const Color(0xFFF9FBF9)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selectedFile != null
                                    ? const Color(0xFF2E7D32)
                                    : (isDark
                                        ? const Color(0xFF2E3D34)
                                        : Colors.grey.shade300),
                                width: selectedFile != null ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: selectedFile != null
                                        ? const Color(0xFF2E7D32)
                                        : (isDark
                                            ? const Color(0xFF1B3224)
                                            : const Color(0xFFE8F5E9)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    selectedFile != null
                                        ? Icons.insert_drive_file_rounded
                                        : Icons.attach_file_rounded,
                                    color: selectedFile != null
                                        ? Colors.white
                                        : (isDark
                                            ? const Color(0xFF81C784)
                                            : const Color(0xFF2E7D32)),
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
                                        selectedFile != null
                                            ? selectedFile!.name
                                            : 'Klik untuk Pilih File dari Folder Lokal...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: selectedFile != null
                                              ? (isDark
                                                  ? const Color(0xFF81C784)
                                                  : const Color(0xFF1B5E20))
                                              : labelColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        selectedFile != null
                                            ? '${_formatFileSize(selectedFile!.size)} • Siap diupload ($selectedType)'
                                            : 'Pilih PDF, Word, PPT, Excel, Video, atau Gambar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subLabelColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: pickFileFromDevice,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedFile != null
                                        ? (isDark
                                            ? const Color(0xFF1E2822)
                                            : Colors.white)
                                        : const Color(0xFF2E7D32),
                                    foregroundColor: selectedFile != null
                                        ? (isDark
                                            ? const Color(0xFF81C784)
                                            : const Color(0xFF2E7D32))
                                        : Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    side: selectedFile != null
                                        ? const BorderSide(
                                            color: Color(0xFF2E7D32),
                                          )
                                        : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: Icon(
                                    selectedFile != null
                                        ? Icons.sync_rounded
                                        : Icons.folder_open_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    selectedFile != null
                                        ? 'Ganti'
                                        : 'Pilih File',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: driveUrlCtrl,
                          style: TextStyle(color: labelColor),
                          onChanged: (val) {
                            final lower = val.toLowerCase();
                            if (lower.contains('.pdf')) {
                              selectedType = 'PDF';
                            } else if (lower.contains('.ppt') ||
                                lower.contains('presentation')) {
                              selectedType = 'PPT';
                            } else if (lower.contains('.doc') ||
                                lower.contains('document')) {
                              selectedType = 'DOC';
                            } else if (lower.contains('.xls') ||
                                lower.contains('spreadsheet')) {
                              selectedType = 'XLS';
                            } else if (lower.contains('.mp4') ||
                                lower.contains('video')) {
                              selectedType = 'VIDEO';
                            }
                            setModalState(() {});
                          },
                          decoration: _inputDecoration(
                            hint:
                                'https://drive.google.com/file/d/.../view?usp=sharing',
                            icon: Icons.link_rounded,
                            isDark: isDark,
                          ).copyWith(
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Tempel Link dari Clipboard',
                                  icon: Icon(
                                    Icons.content_paste_rounded,
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF2E7D32),
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    final text = data?.text?.trim() ?? '';
                                    if (text.isNotEmpty) {
                                      driveUrlCtrl.text = text;
                                      setModalState(() {});
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Buka Google Drive',
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    color: Color(0xFF1A73E8),
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await launchUrl(
                                        Uri.parse('https://drive.google.com'),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } catch (_) {}
                                  },
                                ),
                              ],
                            ),
                          ),
                          validator: (val) {
                            if (isGoogleDriveSource) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Tautan Google Drive wajib diisi';
                              }
                              final lower = val.trim().toLowerCase();
                              if (!lower.startsWith('http://') &&
                                  !lower.startsWith('https://')) {
                                return 'Awali tautan dengan https://';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pastikan akses file Google Drive disetel ke "Siapa saja yang memiliki link" agar dapat dibuka semua user.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF90CAF9)
                                : Colors.blue.shade800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Deskripsi Materi
                      Text(
                        'Deskripsi & Rangkuman Materi *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: TextStyle(color: labelColor),
                        decoration: _inputDecoration(
                          hint:
                              'Jelaskan tujuan edukasi, sasaran penyuluhan, dan isi materi...',
                          icon: Icons.description_outlined,
                          isDark: isDark,
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
                            backgroundColor: isGoogleDriveSource
                                ? const Color(0xFF1A73E8)
                                : const Color(0xFFF57C00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            if (!isGoogleDriveSource && selectedFile == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Silakan klik "Pilih File" untuk memilih dokumen dari folder lokal terlebih dahulu.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final now = DateTime.now();
                            const months = [
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

                            final driveUrl = isGoogleDriveSource
                                ? driveUrlCtrl.text.trim()
                                : '';

                            final fallbackName =
                                '${titleCtrl.text.trim().replaceAll(' ', '_')}.${selectedType.toLowerCase()}';

                            final resolvedFileName = selectedFile != null
                                ? selectedFile!.name
                                : (fileNameCtrl.text.trim().isNotEmpty
                                    ? fileNameCtrl.text.trim()
                                    : fallbackName);

                            final safeLocalPath = _safeFilePath(selectedFile);

                            String fileDataUri = '';
                            if (selectedFile?.bytes != null &&
                                selectedFile!.bytes!.isNotEmpty &&
                                selectedFile!.size <= 5 * 1024 * 1024) {
                              final ext = resolvedFileName.contains('.')
                                  ? resolvedFileName.split('.').last
                                  : selectedType;
                              final mime = _mimeFromExtension(ext);
                              final b64 = base64Encode(selectedFile!.bytes!);
                              fileDataUri = 'data:$mime;base64,$b64';
                            }

                            final newMaterial = <String, dynamic>{
                              'id':
                                  'MAT-${DateTime.now().millisecondsSinceEpoch}',
                              'title': titleCtrl.text.trim(),
                              'category': selectedCat,
                              'type': selectedType,
                              'drive_url': driveUrl,
                              'file_path': driveUrl.isNotEmpty
                                  ? driveUrl
                                  : (safeLocalPath.isNotEmpty
                                      ? safeLocalPath
                                      : 'materials/$resolvedFileName'),
                              'file_name': resolvedFileName,
                              'file_size': selectedFile != null
                                  ? _formatFileSize(selectedFile!.size)
                                  : '',
                              'local_path': safeLocalPath,
                              'file_data_uri': fileDataUri,
                              'description': descCtrl.text.trim(),
                              'uploader_name': _currentUserName,
                              'uploader_role': _currentUserRole == 'admin'
                                  ? 'Administrator Kehutanan'
                                  : 'Penyuluh Kehutanan',
                              'uploaded_at': timeFormatted,
                            };

                            final pickedFile = selectedFile;
                            Navigator.pop(ctx);
                            await _saveNewMaterial(
                              newMaterial,
                              pickedFile: pickedFile,
                            );
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

  Future<void> _saveNewMaterial(
    Map<String, dynamic> newMaterial, {
    PlatformFile? pickedFile,
  }) async {
    setState(() {
      _materials.insert(0, newMaterial);
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_materials));

    // Catat notifikasi materi baru agar dapat dinavigasi dari halaman Notifikasi
    await NotificationService.instance.addMaterialCreatedNotification(
      title: (newMaterial['title'] ?? 'Materi Edukasi').toString(),
      category: (newMaterial['category'] ?? 'Penyuluhan').toString(),
      fileType: (newMaterial['type'] ?? 'PDF').toString(),
      materialId: newMaterial['id'],
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Materi "${newMaterial['title']}" (${newMaterial['file_name']}) berhasil diupload.',
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );

    // Kirim ke server backend agar terlihat oleh semua user di perangkat lain
    try {
      final token = prefs.getString('token');
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/materials/public');

      if (pickedFile != null && pickedFile.bytes != null) {
        final request = http.MultipartRequest('POST', uri);
        request.headers['Accept'] = 'application/json';
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        request.fields['title'] = (newMaterial['title'] ?? '').toString();
        request.fields['category_name'] =
            (newMaterial['category'] ?? 'Penyuluhan').toString();
        request.fields['file_type'] =
            (newMaterial['type'] ?? 'PDF').toString();
        request.fields['file_name'] =
            (newMaterial['file_name'] ?? pickedFile.name).toString();
        request.fields['description'] =
            (newMaterial['description'] ?? '').toString();
        request.fields['uploader_name'] =
            (newMaterial['uploader_name'] ?? _currentUserName).toString();
        request.fields['uploader_role'] =
            (newMaterial['uploader_role'] ?? 'Penyuluh Kehutanan').toString();

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            pickedFile.bytes!,
            filename: pickedFile.name,
          ),
        );

        final streamed =
            await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode == 200 || response.statusCode == 201) {
          await _fetchLiveMaterialsFromServer(prefs);
        }
      } else {
        final headers = {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        };
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        final response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'title': newMaterial['title'],
                'category_name': newMaterial['category'],
                'file_type': newMaterial['type'],
                'file_name': newMaterial['file_name'],
                'file_path': newMaterial['file_path'],
                'drive_url': newMaterial['drive_url'],
                'description': newMaterial['description'],
                'uploader_name': newMaterial['uploader_name'],
                'uploader_role': newMaterial['uploader_role'],
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _fetchLiveMaterialsFromServer(prefs);
        }
      }
    } catch (e) {
      debugPrint('Background backend upload material: $e');
    }
  }

  /// Mengunduh materi dan menyimpannya ke penyimpanan HP user
  Future<void> _handleDownloadMaterial(Map<String, dynamic> material) async {
    final id = (material['id'] ??
            material['title'] ??
            'MAT-${DateTime.now().millisecondsSinceEpoch}')
        .toString();
    if (_downloadingIds.contains(id)) return;

    setState(() {
      _downloadingIds.add(id);
    });

    final fileName =
        (material['file_name'] ?? material['title'] ?? 'Materi Kehutanan')
            .toString();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mengunduh $fileName...',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final result =
          await MaterialDownloadService.instance.downloadMaterial(material);

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.success && result.filePath != null) {
        final filePath = result.filePath!;
        final dirName = result.displayPath ??
            (filePath.contains('Phonebook_Materi')
                ? 'Download/Phonebook_Materi'
                : 'Download');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E3F24),
            duration: const Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF81C784),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Berhasil Diunduh!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.fileName}${result.formattedSize.isNotEmpty ? ' (${result.formattedSize})' : ''}\nTersimpan di: $dirName',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Buka Berkas',
              textColor: const Color(0xFF81C784),
              onPressed: () async {
                final openResult =
                    await MaterialDownloadService.instance.openFile(filePath);
                if (openResult.type != ResultType.done && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tidak dapat membuka berkas: ${openResult.message}. Berkas tersimpan di folder Download HP.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(result.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Gagal mengunduh: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(id);
        });
      }
    }
  }

  void _showMaterialDetail(Map<String, dynamic> material) {
    final type = (material['type'] ?? 'PDF').toString().toUpperCase();
    final uploaderName =
        (material['uploader_name'] ?? 'Penyuluh Kehutanan').toString();
    final uploaderRole = (material['uploader_role'] ?? 'Penyuluh').toString();
    final uploadedAt = (material['uploaded_at'] ?? 'Baru saja').toString();
    final title = (material['title'] ?? '').toString();
    final desc = (material['description'] ?? '').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final fileName =
        (material['file_name'] ?? 'Dokumen_Materi.pdf').toString();
    final fileSize = (material['file_size'] ?? '').toString();
    final rawUrl =
        (material['drive_url'] ?? material['file_path'] ?? '').toString();
    final dataUri = (material['file_data_uri'] ?? '').toString();
    final bool isGoogleDrive = rawUrl.contains('drive.google.com') ||
        rawUrl.contains('docs.google.com') ||
        (rawUrl.startsWith('http') && rawUrl.contains('drive'));

    final isUploader =
        uploaderName.toLowerCase() == _currentUserName.toLowerCase() ||
            (_currentUserEmail.isNotEmpty &&
                uploaderName.toLowerCase() ==
                    _currentUserEmail.toLowerCase()) ||
            _currentUserRole == 'admin';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDownloading = _downloadingIds.contains(
      (material['id'] ?? material['title'] ?? '').toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: SingleChildScrollView(
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
                        color: _getTypeColor(type)
                            .withValues(alpha: isDark ? 0.22 : 0.12),
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E2923),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1B3B22)
                                      : const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF2E7D32),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2D3530)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade800,
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
                    color: isDark
                        ? const Color(0xFF1E2822)
                        : const Color(0xFFF9FBF9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E3D34)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF2E7D32)
                            .withValues(alpha: isDark ? 0.25 : 0.12),
                        child: Text(
                          uploaderName.isNotEmpty
                              ? uploaderName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF81C784)
                                : const Color(0xFF2E7D32),
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
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600,
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
                                    color: uploaderRole
                                            .toLowerCase()
                                            .contains('admin')
                                        ? (isDark
                                            ? const Color(0xFF351D4A)
                                            : Colors.deepPurple.shade50)
                                        : (isDark
                                            ? const Color(0xFF1B3B22)
                                            : Colors.green.shade50),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    uploaderRole.toLowerCase().contains('admin')
                                        ? 'Admin'
                                        : 'Penyuluh',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: uploaderRole
                                              .toLowerCase()
                                              .contains('admin')
                                          ? (isDark
                                              ? const Color(0xFFCE93D8)
                                              : Colors.deepPurple.shade800)
                                          : (isDark
                                              ? const Color(0xFF81C784)
                                              : Colors.green.shade800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              uploaderName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E2923),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              uploadedAt,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
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
                Text(
                  'Deskripsi Materi:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E2923),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),

                const SizedBox(height: 14),

                // File attachment / Google Drive row
                if (isGoogleDrive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F2537)
                          : const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E496D)
                            : const Color(0xFFBDD7FB),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.add_to_drive_rounded,
                          color: Color(0xFF1A73E8),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dokumen Tersedia di Google Drive',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF90CAF9)
                                      : const Color(0xFF174EA6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rawUrl,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.blue.shade900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: Color(0xFF1A73E8),
                          ),
                          tooltip: 'Salin Tautan Drive',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: rawUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Tautan Google Drive berhasil disalin ke clipboard.',
                                ),
                                backgroundColor: Color(0xFF1A73E8),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2822)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E3D34)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 18,
                          color:
                              isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileSize.isNotEmpty
                                ? '$fileName ($fileSize)'
                                : fileName,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // ACTION BUTTONS: UNDUH KE HP & BUKA MATERI
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isDownloading
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _handleDownloadMaterial(material);
                              },
                        icon: isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 22),
                        label: Text(
                          isDownloading
                              ? 'Sedang Mengunduh...'
                              : (fileSize.isNotEmpty
                                  ? 'Unduh ke Penyimpanan HP ($fileSize)'
                                  : 'Unduh ke Penyimpanan HP'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF2E7D32),
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF2E3D34)
                                      : const Color(0xFFC8E6C9),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                if (isGoogleDrive || rawUrl.startsWith('http')) {
                                  try {
                                    final clean = rawUrl.trim();
                                    final uri = Uri.parse(
                                      clean.startsWith('http')
                                          ? clean
                                          : 'https://$clean',
                                    );
                                    final launched = await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!launched) {
                                      await launchUrl(uri);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Gagal membuka tautan: $e'),
                                        ),
                                      );
                                    }
                                  }
                                } else if (dataUri.isNotEmpty) {
                                  try {
                                    final uri = Uri.parse(dataUri);
                                    final launched = await launchUrl(uri);
                                    if (!launched) {
                                      _showDocumentReaderDialog(material);
                                    }
                                  } catch (_) {
                                    _showDocumentReaderDialog(material);
                                  }
                                } else {
                                  _showDocumentReaderDialog(material);
                                }
                              },
                              icon: Icon(
                                isGoogleDrive
                                    ? Icons.open_in_browser_rounded
                                    : Icons.visibility_outlined,
                                size: 19,
                              ),
                              label: Text(
                                isGoogleDrive
                                    ? 'Buka di Google Drive'
                                    : 'Baca / Pratinjau',
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        if (isUploader) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : Colors.red.shade50,
                              foregroundColor: isDark
                                  ? Colors.red.shade300
                                  : Colors.red.shade700,
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
              ],
            ),
          ),
        );
      },
    );
  }

  /// Menampilkan pratinjau isi materi jika file dibuka di dalam aplikasi
  void _showDocumentReaderDialog(Map<String, dynamic> material) {
    final title = (material['title'] ?? 'Materi Edukasi').toString();
    final fileName = (material['file_name'] ?? 'Dokumen').toString();
    final fileSize = (material['file_size'] ?? '').toString();
    final desc = (material['description'] ?? '').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final uploader = (material['uploader_name'] ?? 'Penyuluh').toString();
    final type = (material['type'] ?? 'PDF').toString();
    final dataUri = (material['file_data_uri'] ?? '').toString();

    Uint8List? imageBytes;
    if (dataUri.startsWith('data:image/') && dataUri.contains(',')) {
      try {
        imageBytes = base64Decode(dataUri.split(',').last);
      } catch (_) {}
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E2923);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(_getTypeIcon(type), color: _getTypeColor(type)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B3224)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF81C784)
                          : const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileSize.isNotEmpty
                            ? '$fileName ($fileSize • $category • Oleh $uploader)'
                            : '$fileName ($category • Oleh $uploader)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (imageBytes != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Isi / Ringkasan Materi:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handleDownloadMaterial(material);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Unduh ke HP'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Tutup',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMaterial(Map<String, dynamic> material) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Hapus Materi?',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Materi "${material['title']}" akan dihapus dari daftar publik.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
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

              final idStr = (material['id'] ?? '').toString();
              if (!idStr.startsWith('MAT-')) {
                try {
                  await http.delete(
                    Uri.parse(
                      '${ApiConstants.baseUrl}/api/materials/$idStr/public',
                    ),
                    headers: {'Accept': 'application/json'},
                  );
                } catch (_) {}
              }

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
      case 'XLS':
      case 'EXCEL':
        return const Color(0xFF2E7D32);
      case 'VIDEO':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF00897B);
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
      case 'XLS':
      case 'EXCEL':
        return Icons.table_chart_rounded;
      case 'VIDEO':
        return Icons.play_circle_fill_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    bool isDark = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.grey.shade400,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
        size: 20,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      filled: true,
      fillColor: isDark ? const Color(0xFF243329) : const Color(0xFFF9FBF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2E3D34) : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2E3D34) : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
          width: 1.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMaterials;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isCompactWidth = mediaQuery.size.width < 360;
    // Jarak aman dari floating BottomNav (tinggi 72 + margin 12 + safe area bottom)
    final double bottomNavSafeOffset = mediaQuery.padding.bottom + 88;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Materi Edukasi Kehutanan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF1E2923),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF18221B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              onPressed: _showUploadMaterialModal,
              style: TextButton.styleFrom(
                backgroundColor:
                    const Color(0xFFF57C00).withValues(alpha: 0.14),
                foregroundColor: const Color(0xFFF57C00),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 17),
              label: const Text(
                'Upload',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
            ),
            tooltip: 'Segarkan Materi',
            onPressed: () async {
              setState(() => _isLoading = true);
              final prefs = await SharedPreferences.getInstance();
              await _fetchLiveMaterialsFromServer(prefs);
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFF2E7D32),
          onRefresh: () async {
            final prefs = await SharedPreferences.getInstance();
            await _fetchLiveMaterialsFromServer(prefs);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              bottomNavSafeOffset + 84,
            ),
            children: [
              // Banner Edukasi Publik
              Container(
                padding: EdgeInsets.all(isCompactWidth ? 14 : 18),
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
                        size: 34,
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
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Cari materi, kategori, atau nama pengunggah...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark
                        ? const Color(0xFF81C784)
                        : const Color(0xFF2E7D32),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E2822) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF2E3D34)
                          : Colors.grey.shade200,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF2E3D34)
                          : Colors.grey.shade200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF81C784)
                          : const Color(0xFF2E7D32),
                      width: 1.5,
                    ),
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
                        selectedColor: isDark
                            ? const Color(0xFF26352B)
                            : const Color(0xFF2E7D32),
                        backgroundColor:
                            isDark ? const Color(0xFF1E2822) : Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFF81C784)
                                  : Colors.white)
                              : (isDark
                                  ? Colors.white70
                                  : Colors.grey.shade800),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? (isDark
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF2E7D32))
                                : (isDark
                                    ? const Color(0xFF2E3D34)
                                    : Colors.grey.shade300),
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
                  Text(
                    'Daftar Materi Edukasi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E2923),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1B3224)
                          : const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filtered.length} Materi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF2E7D32),
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
              else if (_errorMessage != null && _materials.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2822) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E3D34)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: Colors.orange.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal Memuat Materi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _loadUserAndMaterials,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              else if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2822) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E3D34)
                          : Colors.grey.shade200,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 56,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _materials.isEmpty
                            ? 'Belum Ada Materi Edukasi'
                            : 'Tidak ada materi yang sesuai filter',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E2923),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _materials.isEmpty
                            ? 'Materi edukasi dari database akan tampil di sini. Anda juga dapat mengunggah dokumen PDF, Word, PPT, atau tautan Google Drive.'
                            : 'Coba ubah kata kunci pencarian atau kategori filter di atas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color:
                              isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      if (_materials.isEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showUploadMaterialModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF57C00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Upload Materi Pertama',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                ...filtered.map((material) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MaterialCard(
                      material: material,
                      isDownloading: _downloadingIds.contains(
                        (material['id'] ?? material['title'] ?? '').toString(),
                      ),
                      onDownload: () => _handleDownloadMaterial(material),
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomNavSafeOffset),
        child: FloatingActionButton.extended(
          onPressed: _showUploadMaterialModal,
          backgroundColor: const Color(0xFFF57C00),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(
            isCompactWidth ? 'Upload' : 'Upload Materi',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final Color typeColor;
  final IconData typeIcon;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onTap;

  const _MaterialCard({
    required this.material,
    required this.typeColor,
    required this.typeIcon,
    required this.isDownloading,
    required this.onDownload,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (material['title'] ?? '').toString();
    final type = (material['type'] ?? 'PDF').toString();
    final category = (material['category'] ?? 'Penyuluhan').toString();
    final uploaderName =
        (material['uploader_name'] ?? 'Penyuluh Kehutanan').toString();
    final uploaderRole = (material['uploader_role'] ?? 'Penyuluh').toString();
    final uploadedAt = (material['uploaded_at'] ?? 'Baru saja').toString();
    final description = (material['description'] ?? '').toString();
    final driveUrl =
        (material['drive_url'] ?? material['file_path'] ?? '').toString();
    final bool isGoogleDrive = driveUrl.contains('drive.google.com') ||
        driveUrl.contains('docs.google.com') ||
        (driveUrl.startsWith('http') && driveUrl.contains('drive'));

    final isAdmin = uploaderRole.toLowerCase().contains('admin');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2822) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3D34) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: isDark ? 0.22 : 0.12),
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
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E2923),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1B3B22)
                                  : const Color(0xFF2E7D32)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF2E7D32),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2D3530)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isGoogleDrive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F2537)
                                    : const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1E496D)
                                      : const Color(0xFFBDD7FB),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cloud_done_rounded,
                                    size: 11,
                                    color: isDark
                                        ? const Color(0xFF64B5F6)
                                        : const Color(0xFF1A73E8),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Google Drive',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF64B5F6)
                                          : const Color(0xFF1A73E8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isAdmin
                      ? (isDark
                          ? const Color(0xFF351D4A)
                          : Colors.deepPurple.shade100)
                      : const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  child: Text(
                    uploaderName.isNotEmpty
                        ? uploaderName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isAdmin
                          ? (isDark
                              ? const Color(0xFFCE93D8)
                              : Colors.deepPurple.shade800)
                          : (isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF2E7D32)),
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
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                      children: [
                        const TextSpan(text: 'Diupload oleh: '),
                        TextSpan(
                          text: uploaderName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E2923),
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
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Unduh ke Penyimpanan HP',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  icon: isDownloading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark
                                ? const Color(0xFF81C784)
                                : const Color(0xFF2E7D32),
                          ),
                        )
                      : Icon(
                          Icons.download_rounded,
                          size: 20,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF2E7D32),
                        ),
                  onPressed: isDownloading ? null : onDownload,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}