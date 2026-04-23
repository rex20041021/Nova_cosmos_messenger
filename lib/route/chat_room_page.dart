import 'package:flutter/material.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';
import 'package:nova_cosmos_messenger/models/chat_room.dart';
import 'package:nova_cosmos_messenger/models/chat_message.dart';
import 'package:nova_cosmos_messenger/models/wiki_info.dart';
import 'package:nova_cosmos_messenger/services/chat_db.dart';
import 'package:nova_cosmos_messenger/services/chat_service.dart';
import 'package:nova_cosmos_messenger/services/favorites_db.dart';
import 'package:nova_cosmos_messenger/route/apod_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('無法開啟連結：$url')),
    );
  }
}

class ChatRoomPage extends StatefulWidget {
  final ChatRoom room;

  const ChatRoomPage({super.key, required this.room});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final rows = await ChatDB.getMessages(widget.room.id);
    if (!mounted) return;
    setState(() {
      _messages = rows;
      _initialLoading = false;
    });
    _scrollToBottom();
  }

  String _newId() => 'msg${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    final historySnapshot = List<ChatMessage>.from(_messages);
    final userMsg = ChatMessage(
      id: _newId(),
      roomId: widget.room.id,
      text: text,
      fromUser: true,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
      _inputController.clear();
      _loading = true;
    });
    await ChatDB.addMessage(userMsg);
    _scrollToBottom();

    try {
      final reply = await ChatService.sendMessage(
        text: text,
        history: historySnapshot,
      );
      if (!mounted) return;
      final now = DateTime.now();
      if (reply.text.isNotEmpty) {
        final textMsg = ChatMessage(
          id: _newId(),
          roomId: widget.room.id,
          text: reply.text,
          fromUser: false,
          createdAt: now,
        );
        setState(() => _messages.add(textMsg));
        await ChatDB.addMessage(textMsg);
      }
      if (reply.apod != null) {
        final apodMsg = ChatMessage(
          id: _newId(),
          roomId: widget.room.id,
          apod: reply.apod,
          fromUser: false,
          createdAt: now.add(const Duration(milliseconds: 1)),
        );
        setState(() => _messages.add(apodMsg));
        await ChatDB.addMessage(apodMsg);
      }
      if (reply.wiki != null) {
        final wikiMsg = ChatMessage(
          id: _newId(),
          roomId: widget.room.id,
          wiki: reply.wiki,
          fromUser: false,
          createdAt: now.add(const Duration(milliseconds: 2)),
        );
        setState(() => _messages.add(wikiMsg));
        await ChatDB.addMessage(wikiMsg);
      }
    } catch (e) {
      if (!mounted) return;
      final errMsg = ChatMessage(
        id: _newId(),
        roomId: widget.room.id,
        text: '連線失敗：$e',
        fromUser: false,
        createdAt: DateTime.now(),
      );
      setState(() => _messages.add(errMsg));
      await ChatDB.addMessage(errMsg);
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _handleBubbleTap(ChatMessage msg) {
    final apod = msg.apod;
    if (apod != null) {
      if (apod.isVideo) {
        _openUrl(context, apod.url);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ApodDetailPage(apod: apod),
          ),
        );
      }
      return;
    }
    final wiki = msg.wiki;
    if (wiki != null) {
      final url = wiki.url;
      if (url != null && url.isNotEmpty) {
        _openUrl(context, url);
      }
    }
  }

  Future<void> _addFavorite(ApodData apod) async {
    final already = await FavoritesDB.exists(apod.date);
    if (already) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${apod.title}」已在收藏'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    await FavoritesDB.add(apod);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入收藏：${apod.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        centerTitle: false,
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty && !_loading
                      ? const Center(
                          child: Text(
                            '和 Nova 聊聊天文，或請它找某一天的 APOD',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length + (_loading ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _messages.length) {
                              return const _LoadingBubble();
                            }
                            final msg = _messages[i];
                            return _MessageBubble(
                              message: msg,
                              onLongPress: msg.apod != null
                                  ? () => _addFavorite(msg.apod!)
                                  : null,
                              onTap: () => _handleBubbleTap(msg),
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                _InputBar(
                  controller: _inputController,
                  onSend: _sendMessage,
                  enabled: !_loading,
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  const _MessageBubble({required this.message, this.onLongPress, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    final bg = fromUser ? Colors.blue.shade100 : Colors.grey.shade200;
    final align = fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(fromUser ? 16 : 4),
      bottomRight: Radius.circular(fromUser ? 4 : 16),
    );

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          child: message.apod != null
              ? _ApodCard(apod: message.apod!)
              : message.wiki != null
                  ? _WikiCard(wiki: message.wiki!)
                  : Text(message.text ?? ''),
        ),
      ),
    );
  }
}

class _ApodCard extends StatelessWidget {
  final ApodData apod;
  const _ApodCard({required this.apod});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (apod.isVideo)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill,
                    size: 20, color: Colors.redAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '影片：${apod.url}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              apod.url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stack) => const SizedBox(
                height: 120,
                child: Center(child: Icon(Icons.broken_image, size: 40)),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          apod.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          apod.date,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          apod.explanation,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

class _WikiCard extends StatelessWidget {
  final WikiInfo wiki;
  const _WikiCard({required this.wiki});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wiki.thumbnail != null && wiki.thumbnail!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              wiki.thumbnail!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stack) => const SizedBox(
                height: 100,
                child: Center(child: Icon(Icons.broken_image, size: 36)),
              ),
            ),
          ),
        if (wiki.thumbnail != null && wiki.thumbnail!.isNotEmpty)
          const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.menu_book, size: 16, color: Colors.black54),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                wiki.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        if (wiki.description != null && wiki.description!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            wiki.description!,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
        if (wiki.extract != null && wiki.extract!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            wiki.extract!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ],
        if (wiki.url != null && wiki.url!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.open_in_new, size: 12, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  wiki.url!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: '發送訊息...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: enabled ? onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}
