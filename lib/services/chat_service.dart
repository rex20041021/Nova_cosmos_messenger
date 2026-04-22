import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nova_cosmos_messenger/config/api_config.dart';
import 'package:nova_cosmos_messenger/models/chat_message.dart';

class ChatService {
  static Future<String> sendMessage({
    required String text,
    required List<ChatMessage> history,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat');
    final body = {
      'text': text,
      'history': history
          .where((m) => m.text != null && m.text!.isNotEmpty)
          .map((m) => {
                'role': m.fromUser ? 'user' : 'ai',
                'text': m.text,
              })
          .toList(),
    };
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('Chat failed: ${response.statusCode}');
    }
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (decoded['text'] as String?) ?? '';
  }
}
