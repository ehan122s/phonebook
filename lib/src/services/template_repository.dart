import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_template.dart';

class TemplateRepository {
  TemplateRepository(this._client);
  final SupabaseClient _client;

  Future<List<ReportTemplate>> list() async {
    final data = await _client.from('report_templates').select().order('name');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(ReportTemplate.fromMap)
        .toList();
  }

  Future<void> save({
    String? id,
    required String name,
    String? logoPath, // BARU
    required String header,
    required String body,
    required bool active,
  }) async {
    final values = {
      'name': name,
      'logo_path': logoPath, // BARU
      'header_html': header,
      'body_html': body,
      'is_active': active,
    };
    if (id == null) {
      await _client.from('report_templates').insert(values);
    } else {
      await _client.from('report_templates').update(values).eq('id', id);
    }
  }

  Future<void> delete(String id) =>
      _client.from('report_templates').delete().eq('id', id);

  // ---------------------------------------------------------------------
  // LOGO — BARU
  // ---------------------------------------------------------------------

  /// Upload logo ke bucket `report-template-logos`. Mengembalikan path
  /// yang disimpan ke kolom `logo_path`.
  Future<String> uploadLogo(Uint8List bytes, String extension) async {
    final path = 'logo_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('report-template-logos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  Future<void> deleteLogo(String path) =>
      _client.storage.from('report-template-logos').remove([path]);

  Future<String> signedLogoUrl(String path) => _client.storage
      .from('report-template-logos')
      .createSignedUrl(path, 3600);
}