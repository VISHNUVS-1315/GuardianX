import 'dart:convert';

import 'package:http/http.dart' as http;

class AiService {
  AiService._();

  static const _proxyUrl = String.fromEnvironment('GUARDIANX_AI_PROXY');
  static const _groqKey = String.fromEnvironment('GROQ_API_KEY');
  static const _groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'openai/gpt-oss-20b',
  );

  static bool get configured => _proxyUrl.isNotEmpty || _groqKey.isNotEmpty;

  static const _systemPrompt = '''
You are GuardianX AI, a concise personal-safety assistant.
Prioritize immediate safety and practical next steps. If someone is in immediate danger in India, tell them to move to a safer place if possible and contact emergency services on 112. Never claim to replace police, emergency responders, doctors, or lawyers. Do not invent nearby places or live facts you do not have. Keep answers calm, short, and actionable.
''';

  static Future<String> ask({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final text = message.trim();
    if (text.isEmpty) throw Exception('Type a message first.');

    final recent = history.length > 8
        ? history.sublist(history.length - 8)
        : history;

    if (_proxyUrl.isNotEmpty) {
      return _askProxy(text, recent);
    }
    if (_groqKey.isNotEmpty) {
      return _askGroq(text, recent);
    }

    return 'GuardianX AI is not connected yet. Core SOS, GPS, nearby services, '
        'Medical ID and emergency actions still work. Configure '
        'GUARDIANX_AI_PROXY for production, or GROQ_API_KEY for development.';
  }

  static Future<String> _askProxy(
    String text,
    List<Map<String, String>> history,
  ) async {
    final response = await http
        .post(
          Uri.parse(_proxyUrl),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'message': text,
            'history': history,
            'system': _systemPrompt,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI service error (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final reply = decoded['reply'] ?? decoded['content'] ?? decoded['message'];
      if (reply != null && reply.toString().trim().isNotEmpty) {
        return reply.toString().trim();
      }
    }
    throw Exception('AI service returned an empty response.');
  }

  static Future<String> _askGroq(
    String text,
    List<Map<String, String>> history,
  ) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      ...history,
      {'role': 'user', 'content': text},
    ];

    final response = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'authorization': 'Bearer $_groqKey',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': _groqModel,
            'messages': messages,
            'temperature': 0.25,
            'max_tokens': 500,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Groq error (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw Exception('Invalid AI response.');
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('AI returned no answer.');
    }
    final first = choices.first;
    if (first is! Map) throw Exception('Invalid AI response.');
    final message = first['message'];
    if (message is! Map) throw Exception('Invalid AI response.');
    final content = message['content']?.toString().trim();
    if (content == null || content.isEmpty) {
      throw Exception('AI returned an empty answer.');
    }
    return content;
  }
}
