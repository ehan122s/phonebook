import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity.dart';
import '../models/stored_file.dart';

class ActivityRepository {
  ActivityRepository(this._client);
  final SupabaseClient _client;

  Future<List<Activity>> list({String? query, int? month, int? year}) async {
    var request = _client.from('activities').select('*, categories(name), profiles(full_name)');
    if (query != null && query.isNotEmpty) {
      request = request.or(
        'title.ilike.%$query%,village.ilike.%$query%,district.ilike.%$query%,regency.ilike.%$query%',
      );
    }
    if (year != null) {
      request = request
          .gte('activity_date', '$year-01-01')
          .lt('activity_date', '${year + 1}-01-01');
    }
    if (month != null && year != null) {
      final next = month == 12
          ? '$year-01-01'
          : '$year-${(month + 1).toString().padLeft(2, '0')}-01';
      request = request
          .gte('activity_date', '$year-${month.toString().padLeft(2, '0')}-01')
          .lt('activity_date', next);
    }
    final rows = await request.order('activity_date', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Activity.fromMap)
        .toList();
  }

  Future<void> create(Map<String, dynamic> values) =>
      _client.from('activities').insert(values);

  Future<void> update(String id, Map<String, dynamic> values) =>
      _client.from('activities').update(values).eq('id', id);

  Future<List<StoredFile>> media(
    String activityId, {
    required bool photos,
  }) async {
    final data = await _client
        .from(photos ? 'activity_photos' : 'activity_documents')
        .select()
        .eq('activity_id', activityId)
        .order('created_at', ascending: false);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(StoredFile.fromMap)
        .toList();
  }

  Future<String> signedUrl(StoredFile file, {required bool photo}) => _client
      .storage
      .from(photo ? 'activity-photos' : 'activity-documents')
      .createSignedUrl(file.path, 3600);

  Future<void> deleteMedia(StoredFile file, {required bool photo}) async {
    await _client.storage
        .from(photo ? 'activity-photos' : 'activity-documents')
        .remove([file.path]);
    await _client
        .from(photo ? 'activity_photos' : 'activity_documents')
        .delete()
        .eq('id', file.id);
  }

  Future<void> createReport(String activityId, String format) =>
      _client.functions.invoke(
        'generate-report',
        body: {'activity_id': activityId, 'format': format},
      );

  Future<void> delete(String activityId) =>
      _client.from('activities').delete().eq('id', activityId);

  Future<void> uploadFile({
    required String activityId,
    required String name,
    required Uint8List bytes,
    required String contentType,
    required bool isPhoto,
  }) async {
    final path = '$activityId/${DateTime.now().millisecondsSinceEpoch}_$name';
    await _client.storage
        .from(isPhoto ? 'activity-photos' : 'activity-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    await _client
        .from(isPhoto ? 'activity_photos' : 'activity_documents')
        .insert({
          'activity_id': activityId,
          'file_name': name,
          'file_path': path,
          'mime_type': contentType,
          'file_size': bytes.length,
        });
  }
}
