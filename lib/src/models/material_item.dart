class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.title,
    required this.category,
    required this.fileType,
    required this.fileName,
    required this.fileSizeBytes,
    this.storagePath,
    this.contentText,
    this.createdAt,
    this.uploadedBy,
    this.uploaderName,
  });

  final String id;
  final String title;
  final String category;

  /// Salah satu dari: pdf | word | excel | ppt | video | image | other
  /// (sesuai CHECK constraint kolom file_type di tabel materials).
  final String fileType;
  final String fileName;
  final int fileSizeBytes;

  /// Path relatif di bucket storage 'materi-edukasi'. Null berarti belum
  /// ada file fisik yang diunggah (mis. data seed/dummy).
  final String? storagePath;
  final String? contentText;
  final DateTime? createdAt;
  
  // -- FIELD BARU UNTUK KEPEMILIKAN --
  final String? uploadedBy;
  final String? uploaderName;

  factory MaterialItem.fromMap(Map<String, dynamic> map) => MaterialItem(
        id: map['id'].toString(), // Pastikan id berupa string
        title: map['title'] as String,
        category: map['category'] as String? ?? 'Umum',
        fileType: map['file_type'] as String? ?? 'other',
        fileName: map['file_name'] as String? ?? '-',
        fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
        storagePath: map['storage_path'] as String?,
        contentText: map['content_text'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        // Mapping kolom user pengunggah
        uploadedBy: map['uploaded_by'] as String?,
        // Supabase mengembalikan relasi join sebagai nested map
        uploaderName: map['profiles'] != null 
            ? map['profiles']['name'] as String? 
            : null,
      );

  /// Label tampilan untuk badge tipe file, mis. "PDF", "DOCX", "XLSX".
  String get labelTipe {
    switch (fileType) {
      case 'pdf':
        return 'PDF';
      case 'word':
        return 'DOCX';
      case 'excel':
        return 'XLSX';
      case 'ppt':
        return 'PPTX';
      case 'video':
        return 'VIDEO';
      case 'image':
        return 'GAMBAR';
      default:
        return fileType.toUpperCase();
    }
  }

  String get ukuranTerformat {
    if (fileSizeBytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (fileSizeBytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final size = fileSizeBytes / (1 << (i * 10));
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  /// Alias bahasa Inggris untuk [ukuranTerformat], dipakai di beberapa layar
  /// (mis. `_MateriEdukasiFlat` di dashboard.dart).
  String get sizeLabel => ukuranTerformat;

  /// True kalau materi ini punya file fisik yang diunggah ke Storage.
  /// False berarti materi ini murni konten teks (`contentText`) tanpa file,
  /// mis. materi ringkas yang ditulis langsung oleh admin tanpa upload.
  bool get hasRealFile => storagePath != null && storagePath!.isNotEmpty;
}