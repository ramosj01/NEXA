import 'dart:convert';

import 'package:http/http.dart' as http;

/// Build-time configuration, passed with `--dart-define`:
///
///   flutter run \
///     --dart-define=NEXA_API_URL=http://10.0.2.2:8000 \
///     --dart-define=NEXA_TOKEN=dev:me:Me \
///     --dart-define=PICOVOICE_ACCESS_KEY=...   # optional: "Jarvis" wake word
class AssistantConfig {
  static const apiUrl = String.fromEnvironment(
    'NEXA_API_URL',
    // 10.0.2.2 is the host machine from the Android emulator.
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const token = String.fromEnvironment('NEXA_TOKEN', defaultValue: 'dev:me:Me');
  static const picovoiceAccessKey = String.fromEnvironment('PICOVOICE_ACCESS_KEY');

  static bool get hasWakeWord => picovoiceAccessKey.isNotEmpty;
}

class AssistantTurn {
  const AssistantTurn(this.role, this.text);
  final String role; // 'user' | 'assistant'
  final String text;

  Map<String, Object> toJson() => {'role': role, 'text': text};
}

class AssistantAction {
  const AssistantAction({required this.tool, required this.ok, required this.summary});
  final String tool;
  final bool ok;
  final String summary;

  factory AssistantAction.fromJson(Map<String, dynamic> j) =>
      AssistantAction(tool: j['tool'] as String, ok: j['ok'] as bool, summary: j['summary'] as String);
}

class AssistantReply {
  const AssistantReply(this.text, this.actions);
  final String text;
  final List<AssistantAction> actions;
}

class AssistantException implements Exception {
  AssistantException(this.spokenMessage);
  final String spokenMessage;
  @override
  String toString() => spokenMessage;
}

/// A short status line for the background notification.
class InboxDigest {
  const InboxDigest({required this.awaitingReply, required this.unreadChats, required this.openTasks});
  final int awaitingReply;
  final int unreadChats;
  final int openTasks;

  String get summary {
    if (awaitingReply == 0 && unreadChats == 0 && openTasks == 0) return 'All caught up';
    final parts = <String>[
      if (awaitingReply > 0) '$awaitingReply waiting on you',
      if (unreadChats > 0) '$unreadChats unread',
      if (openTasks > 0) '$openTasks open task${openTasks == 1 ? '' : 's'}',
    ];
    return parts.join(' · ');
  }
}

/// Talks to the NEXA backend. Safe to use from the background isolate too.
class AssistantApi {
  AssistantApi({String? baseUrl, String? token, http.Client? client})
      : _base = Uri.parse(baseUrl ?? AssistantConfig.apiUrl),
        _token = token ?? AssistantConfig.token,
        _http = client ?? http.Client();

  final Uri _base;
  final String _token;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  Future<AssistantReply> ask(String text, List<AssistantTurn> history) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            _base.resolve('/assistant/chat'),
            headers: _headers,
            body: jsonEncode({
              'text': text,
              'history': history.map((t) => t.toJson()).toList(),
              'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
            }),
          )
          .timeout(const Duration(seconds: 90));
    } on Exception {
      throw AssistantException("I can't reach the NEXA server right now.");
    }
    if (res.statusCode == 503) {
      throw AssistantException(_detail(res) ?? "I'm not available at the moment.");
    }
    if (res.statusCode != 200) {
      throw AssistantException('Something went wrong on the server.');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return AssistantReply(
      j['reply'] as String,
      [for (final a in j['actions'] as List) AssistantAction.fromJson(a as Map<String, dynamic>)],
    );
  }

  /// Cheap, model-free check used by the background service.
  Future<InboxDigest> digest() async {
    final inbox = await _getList('/inbox');
    final tasks = await _getList('/tasks/mine');
    return InboxDigest(
      awaitingReply: inbox.where((i) => i['awaiting_my_reply'] == true).length,
      unreadChats: inbox.where((i) => (i['unread_count'] as int? ?? 0) > 0).length,
      openTasks: tasks.length,
    );
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final res = await _http.get(_base.resolve(path), headers: _headers).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw AssistantException('HTTP ${res.statusCode} for $path');
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List).cast<Map<String, dynamic>>();
  }

  String? _detail(http.Response res) {
    try {
      final d = (jsonDecode(res.body) as Map)['detail'];
      return d is String ? '${d[0].toUpperCase()}${d.substring(1)}.' : null;
    } catch (_) {
      return null;
    }
  }

  void close() => _http.close();
}
