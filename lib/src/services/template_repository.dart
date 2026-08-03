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
    required String header,
    required String body,
    required bool active,
  }) async {
    final values = {
      'name': name,
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
}
