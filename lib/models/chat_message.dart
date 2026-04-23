
import 'dart:convert';
import 'package:nova_cosmos_messenger/models/apod_data.dart';
import 'package:nova_cosmos_messenger/models/wiki_info.dart';

class ChatMessage {
  final String id;
  final String roomId;
  final String? text;
  final ApodData? apod;
  final WikiInfo? wiki;
  final bool fromUser;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.fromUser,
    required this.createdAt,
    this.text,
    this.apod,
    this.wiki,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'text': text,
      'apod_json': apod == null ? null : jsonEncode(apod!.toMap()),
      'wiki_json': wiki == null ? null : jsonEncode(wiki!.toMap()),
      'from_user': fromUser ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final apodJson = map['apod_json'] as String?;
    final wikiJson = map['wiki_json'] as String?;
    return ChatMessage(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      text: map['text'] as String?,
      apod: apodJson == null
          ? null
          : ApodData.fromMap(jsonDecode(apodJson) as Map<String, dynamic>),
      wiki: wikiJson == null
          ? null
          : WikiInfo.fromMap(jsonDecode(wikiJson) as Map<String, dynamic>),
      fromUser: (map['from_user'] as int) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
