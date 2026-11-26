import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/razi_service.dart';
import '../../core/settings_manager.dart';
import '../../core/theme.dart';
import 'razi_rich_text.dart';

/// Razi in the tafseer.id app — the same widget the website embeds
/// (`razi-chat.js` → `https://razi.hadeeth.id/api/chat`), rebuilt in this app's
/// theme. Copied from the hadeeth.id mobile chat page: one session per screen,
/// a retry on a dropped connection, and an error bubble that says what happened
/// instead of leaving a spinner.
class RaziScreen extends ConsumerStatefulWidget {
  const RaziScreen({super.key});

  @override
  ConsumerState<RaziScreen> createState() => _RaziScreenState();
}

class _RaziMessage {
  _RaziMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}

class _RaziScreenState extends ConsumerState<RaziScreen> {
  final List<_RaziMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final RaziService _razi = RaziService();
  bool _sending = false;

  /// Seconds spent waiting on the backend. razi.hadeeth.id answers in 25-40 s
  /// (measured), so a silent spinner reads as "stuck"; the counter and the slow
  /// note below make the wait legible.
  int _elapsed = 0;
  Timer? _ticker;

  void _startTicker() {
    _ticker?.cancel();
    _elapsed = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _elapsed++);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  static const _startersId = [
    'Apa makna ayat tentang sabar?',
    'Jelaskan asbabun nuzul Surah Al-Fatihah',
    'Apa pesan utama Surah Al-Kahfi?',
    'Bagaimana Al-Qur\'an menjelaskan rezeki?',
  ];

  static const _startersEn = [
    'What do the verses on patience mean?',
    'Explain the context of Surah Al-Fatihah',
    'What is the main message of Surah Al-Kahf?',
    'How does the Qur\'an describe provision (rizq)?',
  ];

  @override
  void dispose() {
    _stopTicker();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _lang => ref.read(settingsProvider).appLanguage == 'en' ? 'en' : 'id';

  bool get _isEn => _lang == 'en';

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final lang = _lang;
    setState(() {
      _messages.add(_RaziMessage(text: text, fromUser: true));
      _sending = true;
    });
    _startTicker();
    _input.clear();
    _scrollToEnd();
    try {
      final reply = await _razi.ask(text, lang: lang);
      if (!mounted) return;
      setState(() {
        _messages.add(_RaziMessage(text: reply, fromUser: false));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_RaziMessage(
          text: lang == 'id'
              ? 'Maaf, Razi tidak dapat dihubungi sekarang. Periksa koneksi lalu coba lagi.'
              : 'Razi could not be reached right now. Check your connection and try again.',
          fromUser: false,
        ));
        _sending = false;
      });
    }
    _stopTicker();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _newChat() {
    _razi.reset();
    setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _isEn;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(isEn),
            Expanded(
              child: _messages.isEmpty
                  ? _intro(isEn)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _messages.length) return _typingBubble(isEn);
                        return _bubble(_messages[i]);
                      },
                    ),
            ),
            _composer(isEn),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isEn) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.onSurface),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          const CircleAvatar(
            radius: 18,
            backgroundImage: AssetImage('assets/images/razi_avatar.jpg'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Razi',
                  style: TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isEn ? 'AI Assistant for Qur\'an Study' : 'Asisten AI untuk Studi Al-Qur\'an',
                  style: TextStyle(color: AppTheme.outline, fontSize: 10.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isEn ? 'New chat' : 'Obrolan baru',
            icon: Icon(Icons.restart_alt, color: AppTheme.outline),
            onPressed: _messages.isEmpty ? null : _newChat,
          ),
        ],
      ),
    );
  }

  Widget _intro(bool isEn) {
    final starters = isEn ? _startersEn : _startersId;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        Center(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundImage: AssetImage('assets/images/razi_avatar.jpg'),
              ),
              const SizedBox(height: 14),
              Text(
                isEn ? 'Ask Razi' : 'Tanya Razi',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'Questions about the Qur\'an, its tafsir and its context.'
                    : 'Pertanyaan tentang Al-Qur\'an, tafsir, dan konteksnya.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.outline, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final q in starters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _send(q),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        q,
                        style: TextStyle(color: AppTheme.onSurface, fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bubble(_RaziMessage m) {
    final fromUser = m.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: fromUser ? AppTheme.primaryContainer : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(fromUser ? 14 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 14),
          ),
        ),
        child: fromUser
            ? SelectableText(
                m.text,
                style: TextStyle(
                  color: AppTheme.onPrimaryContainer,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              )
            : RaziRichText(
                text: m.text,
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 13.5,
                  height: 1.5,
                ),
                onLink: _openLink,
              ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // tafseer.id verse links have an exact in-app route. Opening them inside
    // the app avoids depending on an external browser (and its <queries>
    // visibility on Android 11+).
    final verse = RegExp(r'tafseer\.id/#sura/(\d+)/verse/(\d+)').firstMatch(url);
    if (verse != null && context.mounted) {
      context.go('/surahs/${verse.group(1)}/ayahs/${verse.group(2)}');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEn
                ? 'Could not open $url'
                : 'Tidak bisa membuka $url',
          ),
        ),
      );
    }
  }

  Widget _typingBubble(bool isEn) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  isEn
                      ? 'Razi is thinking... ${_elapsed}s'
                      : 'Razi sedang berpikir... ${_elapsed}s',
                  style: TextStyle(color: AppTheme.outline, fontSize: 12),
                ),
              ],
            ),
            if (_elapsed >= 8) ...[
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'Usually 25-40 s. Answers arrive all at once, not word by word.'
                    : 'Biasanya 25-40 detik. Jawaban datang sekaligus, bukan kata per kata.',
                style: TextStyle(color: AppTheme.outline.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composer(bool isEn) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: isEn ? 'Ask about a verse or a topic...' : 'Tanya tentang ayat atau topik...',
                      hintStyle: TextStyle(color: AppTheme.outline, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : () => _send(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    disabledBackgroundColor: AppTheme.surfaceContainerHigh,
                  ),
                  icon: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isEn
                  ? 'Razi is an AI. Verify citations against the verses and tafsir.'
                  : 'Razi adalah AI. Periksa kutipan terhadap ayat dan tafsir.',
              style: TextStyle(color: AppTheme.outline, fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}
