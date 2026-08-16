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

  /// Ambil satu kegiatan berdasarkan id. Dipakai oleh route
  /// `/kegiatan/:id` supaya halaman detail bisa dimuat ulang langsung
  /// dari URL (mis. saat browser di-refresh), bukan cuma lewat objek
  /// [Activity] yang dioper dari halaman daftar.
  Future<Activity> getById(String id) async {
    final row = await _client
        .from('activities')
        .select('*, categories(name), profiles(full_name)')
        .eq('id', id)
        .single();
    return Activity.fromMap(row);
  }

  Future<void> create(Map<String, dynamic> values) =>
      _client.from('activities').insert(values);

  /// BARU — sama seperti [create], tapi mengembalikan `id` baris yang baru
  /// dibuat. Dipakai oleh [OfflineActivityRepository] saat menyinkronkan
  /// kegiatan dari antrian lokal, supaya file/foto yang tadinya nempel ke
  /// id sementara bisa "dipindah" ke id asli ini.
  Future<String> createAndReturnId(Map<String, dynamic> values) async {
    final row = await _client
        .from('activities')
        .insert(values)
        .select('id')
        .single();
    return row['id'] as String;
  }

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

  /// Memanggil Edge Function `generate-report` dan mengembalikan datanya
  /// (biasanya berisi URL/path file hasil generate).
  ///
  /// Melempar [Exception] dengan pesan yang jelas kalau function gagal,
  /// supaya UI bisa menampilkan alasan sebenarnya (bukan cuma "Exception").
  Future<Map<String, dynamic>?> createReport(String activityId, String format) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'generate-report',
        body: {'activity_id': activityId, 'format': format},
      );
    } on FunctionException catch (error) {
      // Function mengembalikan status non-2xx
      throw Exception(
        'Edge Function generate-report gagal (status ${error.status}): ${error.details ?? error.reasonPhrase}',
      );
    }

    if (response.status != 200) {
      throw Exception(
        'Edge Function generate-report mengembalikan status ${response.status}: ${response.data}',
      );
    }

    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    // Kalau response bukan Map (mis. null atau string), kembalikan null
    // supaya UI tetap bisa menampilkan pesan sukses generik.
    return null;
  }

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