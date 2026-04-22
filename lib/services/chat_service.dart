import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nova_cosmos_messenger/config/api_config.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';
import 'package:nova_cosmos_messenger/models/chat_message.dart';

class ChatResponse {
  final String text;
  final ApodData? apod;
  ChatResponse({required this.text, this.apod});
}

class ChatService {
  static Future<ChatResponse> sendMessage({
    required String text,
    required List<ChatMessage> history,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat');
    final body = {
      'text': text,
      'history': history
          .map(_serializeMessage)
          .whereType<Map<String, String>>()
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
    final apodJson = decoded['apod'] as Map<String, dynamic>?;
    return ChatResponse(
      text: (decoded['text'] as String?) ?? '',
      apod: apodJson == null ? null : ApodData.fromJson(apodJson),
    );
  }

  // 把訊息轉成 backend 要的 {role, text} 格式。
  // 只有 APOD 卡片沒有 text 的訊息，轉成描述字串讓 LLM 仍有上下文。
  static Map<String, String>? _serializeMessage(ChatMessage m) {
    final role = m.fromUser ? 'user' : 'ai';
    final text = (m.text != null && m.text!.isNotEmpty)
        ? m.text!
        : (m.apod != null
            ? '[已顯示 APOD 卡片：${m.apod!.date} ${m.apod!.title}]'
            : null);
    if (text == null) return null;
    return {'role': role, 'text': text};
  }
}
