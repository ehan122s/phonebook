class StoredFile {
  const StoredFile({
    required this.id,
    required this.name,
    required this.path,
    required this.mimeType,
    this.caption,
  });
  final String id;
  final String name;
  final String path;
  final String mimeType;
  final String? caption;
  factory StoredFile.fromMap(Map<String, dynamic> map) => StoredFile(
    id: map['id'] as String,
    name: map['file_name'] as String,
    path: map['file_path'] as String,
    mimeType: map['mime_type'] as String,
    caption: map['caption'] as String?,
  );
}
