import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

/// Model satu pesan percakapan pada fitur AI Agent Phonebook.
class AiChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;
  final bool isError;
  final List<String> usedTools;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isError = false,
    this.usedTools = const [],
  });

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'is_error': isError,
    'used_tools': usedTools,
  };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: (json['id'] ?? '').toString(),
      role: (json['role'] ?? 'assistant').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      isError: json['is_error'] == true,
      usedTools: (json['used_tools'] is List)
          ? (json['used_tools'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class AiAgentReply {
  final String reply;
  final List<String> usedTools;
  final String model;

  const AiAgentReply({
    required this.reply,
    this.usedTools = const [],
    this.model = '',
  });
}

/// Service komunikasi dengan endpoint AI Agent Laravel (Groq API berada aman di backend).
class AiAgentService {
  AiAgentService._();
  static final AiAgentService instance = AiAgentService._();

  static const int _maxStoredMessages = 40;
  static const int _maxContextMessages = 12;

  Future<String> _historyKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString('user_id') ?? '').trim();
    if (userId.isNotEmpty) {
      return 'phonebook_ai_chat_history_u$userId';
    }
    final email = (prefs.getString('email') ?? 'guest').trim().toLowerCase();
    return 'phonebook_ai_chat_history_$email';
  }

  /// Memuat riwayat percakapan lokal milik pengguna saat ini.
  Future<List<AiChatMessage>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _historyKey();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => AiChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.content.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Menyimpan riwayat percakapan secara terbatas (maksimal 40 pesan terakhir).
  Future<void> saveHistory(List<AiChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _historyKey();
      final trimmed = messages.length > _maxStoredMessages
          ? messages.sublist(messages.length - _maxStoredMessages)
          : messages;
      await prefs.setString(
        key,
        jsonEncode(trimmed.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Menghapus riwayat percakapan (memulai percakapan baru).
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _historyKey();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Mengirim pesan ke backend Laravel (`POST /api/ai/chat`).
  Future<AiAgentReply> sendMessage({
    required String message,
    required List<AiChatMessage> history,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();

    if (token.isEmpty ||
        token.startsWith('offline_') ||
        token.startsWith('google_session_')) {
      throw Exception(
        'Fitur Asisten AI memerlukan koneksi internet dan sesi login aktif.',
      );
    }

    final cleanHistory = history
        .where(
          (m) =>
              !m.isError &&
              (m.role == 'user' || m.role == 'assistant') &&
              m.content.trim().isNotEmpty,
        )
        .toList();

    final boundedContext = cleanHistory.length > _maxContextMessages
        ? cleanHistory.sublist(cleanHistory.length - _maxContextMessages)
        : cleanHistory;

    final payload = {
      'message': message.trim(),
      'history': boundedContext
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
    };

    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.aiChatUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 35));

      Map<String, dynamic> decoded = {};
      try {
        final rawJson = jsonDecode(response.body);
        if (rawJson is Map<String, dynamic>) {
          decoded = rawJson;
        }
      } catch (_) {}

      if (response.statusCode == 200 && decoded['success'] == true) {
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        final reply = (data['reply'] ?? '').toString().trim();
        final usedTools = (data['used_tools'] is List)
            ? (data['used_tools'] as List).map((e) => e.toString()).toList()
            : <String>[];
        final model = (data['model'] ?? '').toString();

        return AiAgentReply(
          reply: reply.isNotEmpty
              ? reply
              : 'Maaf, AI belum memberikan jawaban. Silakan coba lagi.',
          usedTools: usedTools,
          model: model,
        );
      }

      if (response.statusCode == 401) {
        throw Exception('Sesi login telah berakhir. Silakan login kembali.');
      }

      if (response.statusCode == 429) {
        throw Exception(
          decoded['message']?.toString() ??
              'Permintaan AI terlalu banyak. Tunggu sebentar lalu coba lagi.',
        );
      }

      throw Exception(
        decoded['message']?.toString() ??
            'Gagal mendapatkan jawaban AI (HTTP ${response.statusCode}).',
      );
    } on TimeoutException {
      throw Exception(
        'Asisten AI membutuhkan waktu terlalu lama untuk merespons. Silakan coba lagi.',
      );
    } on SocketException {
      throw Exception(
        'Tidak ada koneksi internet. Periksa jaringan Anda lalu coba lagi.',
      );
    } on http.ClientException {
      throw Exception(
        'Koneksi ke server terganggu. Silakan coba lagi.',
      );
    }
  }
}
