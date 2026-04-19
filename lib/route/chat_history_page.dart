import 'package:flutter/material.dart';
import 'package:nova_cosmos_messenger/route/chat_room_page.dart';

class ChatRoom {
  final String id;
  String name;
  final DateTime createdAt;

  ChatRoom({required this.id, required this.name, required this.createdAt});
}

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  final List<ChatRoom> _rooms = [];

  void _addRoom() {
    setState(() {
      _rooms.add(ChatRoom(
        id: 'room${DateTime.now().millisecondsSinceEpoch}',
        name: '對話 ${_rooms.length + 1}',
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> _renameRoom(int index) async {
    final controller = TextEditingController(text: _rooms[index].name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '輸入新名稱'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() => _rooms[index].name = newName);
    }
  }

  Future<void> _confirmDelete(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除對話'),
        content: Text('要刪除「${_rooms[index].name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _rooms.removeAt(index));
    }
  }

  void _openRoom(ChatRoom room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('對話紀錄'),
        centerTitle: false,
      ),
      body: _rooms.isEmpty
          ? const Center(
              child: Text('尚無對話，點右下角新增',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final room = _rooms[i];
                return Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.chat_bubble_outline,
                          color: Colors.white, size: 20),
                    ),
                    title: Text(
                      room.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _formatDate(room.createdAt),
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 12),
                    ),
                    onTap: () => _openRoom(room),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _renameRoom(i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(i),
                        ),
                      ],
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoom,
        tooltip: '新增對話',
        child: const Icon(Icons.add),
      ),
    );
  }
}
