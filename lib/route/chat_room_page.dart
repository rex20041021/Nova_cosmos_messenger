import 'package:flutter/material.dart';
import 'package:nova_cosmos_messenger/route/chat_history_page.dart';

class ChatRoomPage extends StatelessWidget {
  final ChatRoom room;

  const ChatRoomPage({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(room.name),
        centerTitle: false,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '聊天訊息區（待實作）',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
