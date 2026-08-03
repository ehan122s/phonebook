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
  });

  final String id;
  final String title;
  final String category;
  final String fileType; // pdf | word | excel | video | image | other
  final String fileName;
  final int fileSizeBytes;
  final String? storagePath;
  final String? contentText;

  /// True kalau materi ini punya file biner asli di Supabase Storage
  /// (diunggah admin), bukan sekadar konten teks contoh.
  bool get hasRealFile => storagePath != null && storagePath!.isNotEmpty;

  String get sizeLabel {
    final kb = fileSizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  factory MaterialItem.fromMap(Map<String, dynamic> map) => MaterialItem(
        id: map['id'] as String,
        title: map['title'] as String,
        category: map['category'] as String,
        fileType: map['file_type'] as String,
        fileName: map['file_name'] as String,
        fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
        storagePath: map['storage_path'] as String?,
        contentText: map['content_text'] as String?,
      );
}
