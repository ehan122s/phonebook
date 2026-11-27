import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../../services/ai_agent_service.dart';

class AiAgentPage extends StatefulWidget {
  const AiAgentPage({super.key});

  @override
  State<AiAgentPage> createState() => _AiAgentPageState();
}

class _AiAgentPageState extends State<AiAgentPage> {
  static const Color kPrimary = Color(0xFF245C3A);
  static const Color kSecondary = Color(0xFF4F8A5B);

  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<AiChatMessage> _messages = [];
  bool _isLoadingHistory = true;
  bool _isThinking = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _baseTextBeforeSpeech = '';
  String? _lastFailedPrompt;

  static const List<String> _starterPrompts = [
    'Rangkum laporan terbaru saya',
    'Bantu susun laporan penyuluhan kehutanan',
    'Cek jadwal kegiatan saya minggu ini',
    'Bandingkan target 30 peserta & hasil 24 peserta',
    'Jelaskan fitur-fitur aplikasi Phonebook',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    if (_isListening) {
      _speech.stop();
    }
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isThinking) return;

    if (_isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    try {
      if (!_speechAvailable) {
        _speechAvailable = await _speech.initialize(
          onStatus: (status) {
            if (!mounted) return;
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Pengenalan suara terhenti: ${error.errorMsg}',
                ),
              ),
            );
          },
        );
      }

      if (!_speechAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mikrofon atau layanan suara tidak tersedia / izin ditolak di perangkat ini.',
            ),
          ),
        );
        return;
      }

      _baseTextBeforeSpeech = _inputCtrl.text.trim();
      setState(() => _isListening = true);

      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: 'id_ID',
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!mounted) return;
          final spoken = result.recognizedWords.trim();
          final combined = _baseTextBeforeSpeech.isEmpty
              ? spoken
              : (spoken.isEmpty
                  ? _baseTextBeforeSpeech
                  : '$_baseTextBeforeSpeech $spoken');
          _inputCtrl.value = TextEditingValue(
            text: combined,
            selection: TextSelection.collapsed(offset: combined.length),
          );
          if (result.finalResult) {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fitur mikrofon tidak didukung pada perangkat ini. Silakan ketik pesan secara manual.',
          ),
        ),
      );
    }
  }

  Future<void> _loadChatHistory() async {
    final loaded = await AiAgentService.instance.loadHistory();
    if (!mounted) return;
    setState(() {
      _messages = loaded;
      _isLoadingHistory = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    if (_isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
    final text = (overrideText ?? _inputCtrl.text).trim();
    if (text.isEmpty || _isThinking) return;

    if (overrideText == null) {
      _inputCtrl.clear();
    }

    // Jika mengulang prompt yang gagal, hapus pesan error terakhir agar rapi
    final cleanedList = List<AiChatMessage>.from(_messages);
    if (cleanedList.isNotEmpty && cleanedList.last.isError) {
      cleanedList.removeLast();
    }

    // Jika ini bukan retry dari pesan user yang sudah ada di akhir, tambahkan bubble user
    final isRetrySameUserMsg = overrideText != null &&
        cleanedList.isNotEmpty &&
        cleanedList.last.isUser &&
        cleanedList.last.content == text;

    final contextHistory = List<AiChatMessage>.from(cleanedList);
    if (!isRetrySameUserMsg) {
      cleanedList.add(
        AiChatMessage(
          id: 'u_${DateTime.now().millisecondsSinceEpoch}',
          role: 'user',
          content: text,
          createdAt: DateTime.now(),
        ),
      );
    }

    setState(() {
      _messages = cleanedList;
      _isThinking = true;
      _lastFailedPrompt = null;
    });
    _scrollToBottom();
    await AiAgentService.instance.saveHistory(_messages);

    try {
      final result = await AiAgentService.instance.sendMessage(
        message: text,
        history: isRetrySameUserMsg && contextHistory.isNotEmpty
            ? contextHistory.sublist(0, contextHistory.length - 1)
            : contextHistory,
      );

      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          AiChatMessage(
            id: 'a_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            content: result.reply,
            createdAt: DateTime.now(),
            usedTools: result.usedTools,
          ),
        ];
        _isThinking = false;
      });
      await AiAgentService.instance.saveHistory(_messages);
      _scrollToBottom();
    } catch (e) {
      final friendlyErr = e.toString().replaceFirst('Exception: ', '').trim();
      if (!mounted) return;
      setState(() {
        _lastFailedPrompt = text;
        _messages = [
          ..._messages,
          AiChatMessage(
            id: 'e_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            content: friendlyErr.isNotEmpty
                ? friendlyErr
                : 'Gagal menghubungi Asisten AI. Silakan coba lagi.',
            createdAt: DateTime.now(),
            isError: true,
          ),
        ];
        _isThinking = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _confirmNewConversation() async {
    if (_messages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mulai Percakapan Baru?'),
        content: const Text(
          'Riwayat percakapan saat ini akan dihapus agar Anda bisa memulai topik baru dengan bersih.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Percakapan Baru'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AiAgentService.instance.clearHistory();
      if (!mounted) return;
      setState(() {
        _messages = [];
        _lastFailedPrompt = null;
      });
    }
  }

  String _formatToolBadge(List<String> tools) {
    final labels = tools.map((t) {
      switch (t) {
        case 'get_user_reports':
          return 'Data Laporan';
        case 'get_report_detail':
          return 'Detail Laporan';
        case 'create_report':
          return 'Simpan Laporan';
        case 'update_report':
          return 'Edit Laporan';
        case 'delete_report':
          return 'Hapus Laporan';
        case 'get_report_templates':
          return 'Template Laporan';
        case 'get_user_schedules':
          return 'Data Jadwal';
        case 'create_schedule':
          return 'Simpan Jadwal';
        case 'update_schedule':
          return 'Edit Jadwal';
        case 'delete_schedule':
          return 'Hapus Jadwal';
        case 'get_materials':
          return 'Data Materi';
        case 'create_material':
          return 'Simpan Materi';
        case 'update_material':
          return 'Edit Materi';
        case 'delete_material':
          return 'Hapus Materi';
        case 'get_categories':
          return 'Kategori';
        case 'create_category':
          return 'Tambah Kategori';
        case 'update_category':
          return 'Edit Kategori';
        case 'delete_category':
          return 'Hapus Kategori';
        case 'get_notifications':
          return 'Notifikasi';
        case 'mark_notification_read':
          return 'Baca Notifikasi';
        case 'delete_notification':
          return 'Hapus Notifikasi';
        case 'get_my_profile':
          return 'Profil Saya';
        case 'update_my_profile':
          return 'Edit Profil';
        case 'get_bug_reports':
          return 'Tiket Kendala';
        case 'create_bug_report':
          return 'Kirim Kendala';
        case 'get_app_update_info':
          return 'Info Update';
        case 'get_app_features_guide':
          return 'Panduan Phonebook';
        default:
          return t;
      }
    }).toSet();
    return labels.join(' • ');
  }

  Future<void> _handleMarkdownLink(String? href) async {
    if (href == null || href.trim().isEmpty) return;
    final uri = Uri.tryParse(href.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildAiMarkdownBody({
    required BuildContext context,
    required AiChatMessage msg,
    required bool isDark,
    required Color borderColor,
    required Color contentColor,
    required Color textSecondary,
  }) {
    final accentColor = isDark ? const Color(0xFF81C784) : kPrimary;
    final strongColor = msg.isError
        ? contentColor
        : (isDark ? Colors.white : const Color(0xFF132219));
    final headingColor = msg.isError ? contentColor : accentColor;
    final baseTextStyle = TextStyle(
      fontSize: 14.5,
      height: 1.5,
      color: contentColor,
    );

    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: baseTextStyle,
      pPadding: EdgeInsets.zero,
      strong: baseTextStyle.copyWith(
        fontWeight: FontWeight.w700,
        color: strongColor,
      ),
      em: baseTextStyle.copyWith(fontStyle: FontStyle.italic),
      h1: TextStyle(
        fontSize: 17.5,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      h2: TextStyle(
        fontSize: 16.5,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      h3: TextStyle(
        fontSize: 15.5,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      h4: TextStyle(
        fontSize: 14.5,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      h1Padding: const EdgeInsets.only(top: 4, bottom: 2),
      h2Padding: const EdgeInsets.only(top: 4, bottom: 2),
      h3Padding: const EdgeInsets.only(top: 2, bottom: 2),
      h4Padding: const EdgeInsets.only(top: 2, bottom: 2),
      blockSpacing: 8,
      listIndent: 18,
      listBullet: baseTextStyle.copyWith(
        fontWeight: FontWeight.w600,
        color: msg.isError ? contentColor : accentColor,
      ),
      listBulletPadding: const EdgeInsets.only(right: 6),
      a: baseTextStyle.copyWith(
        color: accentColor,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w600,
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B4D2E),
        backgroundColor:
            isDark ? const Color(0xFF131B16) : const Color(0xFFEEF3EF),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B16) : const Color(0xFFF3F6F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      blockquote: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontStyle: FontStyle.italic,
        color: textSecondary,
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      blockquoteDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF16201A) : const Color(0xFFF1F6F2),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
    );

    return MarkdownBody(
      data: msg.content,
      selectable: true,
      shrinkWrap: true,
      fitContent: true,
      softLineBreak: true,
      styleSheet: styleSheet,
      onTapLink: (_, href, _) => _handleMarkdownLink(href),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111814) : const Color(0xFFF6F8F6);
    final surfaceColor = isDark ? const Color(0xFF1C2620) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2D3C32) : const Color(0xFFE0EAE1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1D2B22);
    final textSecondary =
        isDark ? const Color(0xFFB5C4B9) : const Color(0xFF5E6D63);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF16201A) : Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        titleSpacing: 4,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: isDark ? 0.35 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: isDark ? const Color(0xFF81C784) : kPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asisten AI Phonebook',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Asisten Laporan & Tugas Kehutanan',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _isThinking ? null : _confirmNewConversation,
              tooltip: 'Percakapan Baru',
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(color: kPrimary),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState(
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          itemCount: _messages.length + (_isThinking ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isThinking && index == _messages.length) {
                              return _buildThinkingBubble(
                                isDark: isDark,
                                surfaceColor: surfaceColor,
                                borderColor: borderColor,
                                textSecondary: textSecondary,
                              );
                            }
                            final msg = _messages[index];
                            return _buildMessageBubble(
                              msg,
                              isDark: isDark,
                              surfaceColor: surfaceColor,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            );
                          },
                        ),
            ),
            _buildInputBar(
              isDark: isDark,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kSecondary, kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Halo! Saya Asisten AI Phonebook',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saya siap membantu menyusun laporan kegiatan kehutanan, merangkum laporan Anda, membandingkan target & hasil, serta menjelaskan fitur aplikasi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Coba tanyakan:',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _starterPrompts.map((prompt) {
              return ActionChip(
                backgroundColor: surfaceColor,
                side: BorderSide(color: borderColor),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                avatar: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF81C784) : kPrimary,
                ),
                label: Text(
                  prompt,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                ),
                onPressed: _isThinking ? null : () => _sendMessage(prompt),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    AiChatMessage msg, {
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isUser = msg.isUser;
    final bubbleColor = isUser
        ? kPrimary
        : (msg.isError
            ? (isDark ? const Color(0xFF3A1E1E) : const Color(0xFFFFF1F1))
            : surfaceColor);
    final bubbleBorder = isUser
        ? Colors.transparent
        : (msg.isError
            ? Colors.red.withValues(alpha: 0.45)
            : borderColor);
    final contentColor = isUser
        ? Colors.white
        : (msg.isError
            ? (isDark ? const Color(0xFFFFB4B4) : Colors.red.shade900)
            : textPrimary);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: bubbleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && msg.usedTools.isNotEmpty && !msg.isError) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: isDark ? 0.30 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 13,
                      color: isDark ? const Color(0xFF81C784) : kPrimary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Menggunakan: ${_formatToolBadge(msg.usedTools)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF81C784) : kPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isUser)
              Text(
                msg.content,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.42,
                  color: contentColor,
                ),
              )
            else
              _buildAiMarkdownBody(
                context: context,
                msg: msg,
                isDark: isDark,
                borderColor: borderColor,
                contentColor: contentColor,
                textSecondary: textSecondary,
              ),
            if (msg.isError && _lastFailedPrompt != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isThinking
                    ? null
                    : () => _sendMessage(_lastFailedPrompt),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? const Color(0xFFFFB4B4) : Colors.red.shade800,
                  side: BorderSide(
                    color: Colors.red.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble({
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textSecondary,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? const Color(0xFF81C784) : kPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI sedang berpikir...',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar({
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isListening)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.22 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mendengarkan suara Anda... Bicara sekarang.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFFB4B4) : Colors.red.shade800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleListening,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Selesai',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFFB4B4) : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  enabled: !_isThinking,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: TextStyle(fontSize: 15, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Mendengarkan...'
                        : 'Ketik atau tekan mic untuk bicara...',
                    hintStyle: TextStyle(fontSize: 14.5, color: textSecondary),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF141D17)
                        : const Color(0xFFF3F6F3),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: kPrimary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  onPressed: _isThinking ? null : _toggleListening,
                  tooltip: _isListening ? 'Hentikan Mikrofon' : 'Bicara dengan AI',
                  style: IconButton.styleFrom(
                    backgroundColor: _isListening
                        ? Colors.red.shade600
                        : (isDark
                            ? const Color(0xFF233329)
                            : const Color(0xFFE8F2E8)),
                    foregroundColor: _isListening
                        ? Colors.white
                        : (isDark ? const Color(0xFF81C784) : kPrimary),
                  ),
                  icon: Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                height: 50,
                child: FilledButton(
                  onPressed: _isThinking ? null : () => _sendMessage(),
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Icon(Icons.send_rounded, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
