import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Raised when Razi cannot answer. [detail] carries the real cause (HTTP code,
/// socket error, timeout) so the chat bubble shows it instead of a generic
/// "cannot be reached" that hides whether the host is blocked or merely slow.
class RaziException implements Exception {
  RaziException(this.detail);

  final String detail;

  @override
  String toString() => detail;
}

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

  /// The browser widget reaches this API from tafseer.id, so the same origin
  /// and referer are sent here. A bare Dart request can be refused by edge
  /// rules that never see a browser on the other end.
  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Origin': 'https://tafseer.id',
    'Referer': 'https://tafseer.id/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/126.0.0.0 Mobile Safari/537.36 TafseerApp/3.3',
  };

  final http.Client _client;
  String? sessionId;

  /// Sends [message] and returns the reply. One retry covers a dropped
  /// connection; a 90 s timeout covers the long answer the model returns as a
  /// single body.
  Future<String> ask(String message, {required String lang}) async {
    var lastDetail = 'unknown error';
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _client
            .post(
              Uri.parse(endpoint),
              headers: {..._headers, 'Accept-Language': lang},
              body: jsonEncode({
                'message': message,
                'lang': lang,
                if (sessionId != null) 'session_id': sessionId,
              }),
            )
            .timeout(const Duration(seconds: 90));
        if (res.statusCode != 200) {
          lastDetail = 'HTTP ${res.statusCode}';
          throw RaziException(lastDetail);
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final sid = data['session_id'];
        if (sid is String && sid.isNotEmpty) sessionId = sid;
        final reply = data['reply'];
        if (reply is String && reply.trim().isNotEmpty) return reply;
        lastDetail = 'empty reply';
        throw RaziException(lastDetail);
      } on RaziException catch (e) {
        lastDetail = e.detail;
      } on TimeoutException {
        lastDetail = 'timeout after 90s';
      } catch (e) {
        lastDetail = e is SocketException
            ? 'socket: ${e.osError?.message ?? e.message}'
            : e.toString();
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    throw RaziException(lastDetail);
  }

  void reset() => sessionId = null;
}
