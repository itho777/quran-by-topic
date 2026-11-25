import 'dart:convert';

import 'package:http/http.dart' as http;

/// Razi — the assistant behind the tafseer.id web widget, reached through the
/// same Worker the web chat uses. The session id keeps one conversation
/// grounded in a single server-side thread, so follow-up questions have
/// context; [reset] starts a fresh thread.
///
/// Copied from the hadeeth.id mobile client (`lib/data/razi_service.dart`) and
/// pointed at the endpoint tafseer.id already ships in `razi-chat.js`.
class RaziService {
  RaziService({http.Client? client}) : _client = client ?? http.Client();

  static const endpoint = 'https://razi.hadeeth.id/api/chat';

  final http.Client _client;
  String? sessionId;

  /// Sends [message] and returns the reply. One retry covers a dropped
  /// connection; a 90 s timeout covers the long answer the model streams back
  /// as one body.
  Future<String> ask(String message, {required String lang}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _client
            .post(
              Uri.parse(endpoint),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'message': message,
                'lang': lang,
                if (sessionId != null) 'session_id': sessionId,
              }),
            )
            .timeout(const Duration(seconds: 90));
        if (res.statusCode != 200) {
          throw Exception('Razi HTTP ${res.statusCode}');
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final sid = data['session_id'];
        if (sid is String && sid.isNotEmpty) sessionId = sid;
        final reply = data['reply'];
        if (reply is String && reply.trim().isNotEmpty) return reply;
        throw Exception('Razi returned an empty reply');
      } catch (e) {
        if (attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    throw Exception('Razi unavailable');
  }

  void reset() => sessionId = null;
}
