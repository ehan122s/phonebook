class ReportTemplate {
  const ReportTemplate({
    required this.id,
    required this.name,
    this.logoPath, // BARU
    this.headerHtml,
    this.bodyHtml,
    this.isActive = true,
  });
  final String id;
  final String name;
  final String? logoPath; 
  final String? headerHtml;
  final String? bodyHtml;
  final bool isActive;
  factory ReportTemplate.fromMap(Map<String, dynamic> map) => ReportTemplate(
    id: map['id'] as String,
    name: map['name'] as String,
    logoPath: map['logo_path'] as String?,
    headerHtml: map['header_html'] as String?,
    bodyHtml: map['body_html'] as String?,
    isActive: map['is_active'] as bool? ?? true,
  );
}