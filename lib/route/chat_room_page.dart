import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';
import 'package:nova_cosmos_messenger/models/chat_room.dart';
import 'package:nova_cosmos_messenger/models/chat_message.dart';
import 'package:nova_cosmos_messenger/models/wiki_info.dart';
import 'package:nova_cosmos_messenger/services/chat_db.dart';
import 'package:nova_cosmos_messenger/services/chat_service.dart';
import 'package:nova_cosmos_messenger/services/favorites_db.dart';
import 'package:nova_cosmos_messenger/route/apod_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF050505);
const _kFg      = Color(0xFFF6F2EA);
const _kMuted   = Color(0x72F6F2EA);
const _kFaint   = Color(0x38F6F2EA);
const _kAccent  = Color(0xFFD9C5A7);
const _kHair    = Color(0x14F6F2EA);
const _kUserBg  = Color(0xFF1E1A10);   // warm dark — user bubble
const _kNovaBg  = Color(0xFF111111);   // cool dark — AI bubble

// ── URL helper ────────────────────────────────────────────────────────────────
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

// ── ChatRoomPage ──────────────────────────────────────────────────────────────
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
    setState(() { _messages = rows; _initialLoading = false; });
    _scrollToBottom();
  }

  String _newId() => 'msg${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    final historySnapshot = List<ChatMessage>.from(_messages);
    final userMsg = ChatMessage(
      id: _newId(), roomId: widget.room.id,
      text: text, fromUser: true, createdAt: DateTime.now(),
    );
    setState(() { _messages.add(userMsg); _inputController.clear(); _loading = true; });
    await ChatDB.addMessage(userMsg);
    _scrollToBottom();

    try {
      final reply = await ChatService.sendMessage(text: text, history: historySnapshot);
      if (!mounted) return;
      final now = DateTime.now();
      if (reply.text.isNotEmpty) {
        final m = ChatMessage(id: _newId(), roomId: widget.room.id,
            text: reply.text, fromUser: false, createdAt: now);
        setState(() => _messages.add(m));
        await ChatDB.addMessage(m);
      }
      if (reply.apod != null) {
        final m = ChatMessage(id: _newId(), roomId: widget.room.id,
            apod: reply.apod, fromUser: false,
            createdAt: now.add(const Duration(milliseconds: 1)));
        setState(() => _messages.add(m));
        await ChatDB.addMessage(m);
      }
      if (reply.wiki != null) {
        final m = ChatMessage(id: _newId(), roomId: widget.room.id,
            wiki: reply.wiki, fromUser: false,
            createdAt: now.add(const Duration(milliseconds: 2)));
        setState(() => _messages.add(m));
        await ChatDB.addMessage(m);
      }
    } catch (e) {
      if (!mounted) return;
      final m = ChatMessage(id: _newId(), roomId: widget.room.id,
          text: '連線失敗：$e', fromUser: false, createdAt: DateTime.now());
      setState(() => _messages.add(m));
      await ChatDB.addMessage(m);
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
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ApodDetailPage(apod: apod)));
      }
      return;
    }
    final wiki = msg.wiki;
    if (wiki != null && (wiki.url?.isNotEmpty ?? false)) {
      _openUrl(context, wiki.url!);
    }
  }

  Future<void> _addFavorite(ApodData apod) async {
    final already = await FavoritesDB.exists(apod.date);
    if (!mounted) return;
    if (already) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('「${apod.title}」已在收藏'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    await FavoritesDB.add(apod);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已加入收藏：${apod.title}'),
      duration: const Duration(seconds: 2),
    ));
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
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(widget.room.name),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kHair),
        ),
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty && !_loading
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                          itemCount: _messages.length + (_loading ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _messages.length) return const _LoadingBubble();
                            final msg = _messages[i];
                            return _MessageBubble(
                              message: msg,
                              onLongPress: msg.apod != null
                                  ? () => _addFavorite(msg.apod!) : null,
                              onTap: () => _handleBubbleTap(msg),
                            );
                          },
                        ),
                ),
                _InputBar(
                  controller: _inputController,
                  onSend: _sendMessage,
                  enabled: !_loading,
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✷',
                style: GoogleFonts.instrumentSerif(
                    fontSize: 36, color: _kAccent, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            Text(
              'Ask Nova about the cosmos,\nor request an APOD by date.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmMono(
                  fontSize: 12, color: _kMuted,
                  fontWeight: FontWeight.w300, height: 1.7, letterSpacing: .02),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _MessageBubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  const _MessageBubble({required this.message, this.onLongPress, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    final isCard = message.apod != null || message.wiki != null;

    final bg = fromUser ? _kUserBg : _kNovaBg;
    final align = fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(fromUser ? 16 : 4),
      bottomRight: Radius.circular(fromUser ? 4 : 16),
    );

    Widget child;
    if (message.apod != null) {
      child = _ApodCard(apod: message.apod!);
    } else if (message.wiki != null) {
      child = _WikiCard(wiki: message.wiki!);
    } else {
      child = SelectableText(
        message.text ?? '',
        style: GoogleFonts.dmMono(
          fontSize: 13.5,
          color: _kFg,
          fontWeight: FontWeight.w300,
          height: 1.55,
          letterSpacing: .015,
        ),
      );
    }

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: isCard
              ? const EdgeInsets.all(0)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.80,
          ),
          decoration: BoxDecoration(
            color: isCard ? Colors.transparent : bg,
            borderRadius: radius,
            border: isCard
                ? Border.all(color: _kHair)
                : Border.all(color: _kHair),
          ),
          clipBehavior: isCard ? Clip.antiAlias : Clip.none,
          child: isCard
              ? ClipRRect(borderRadius: radius, child: child)
              : child,
        ),
      ),
    );
  }
}

// ── _ApodCard ─────────────────────────────────────────────────────────────────
class _ApodCard extends StatelessWidget {
  final ApodData apod;
  const _ApodCard({required this.apod});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // image / video placeholder
        if (apod.isVideo)
          Container(
            color: const Color(0xFF0b1024),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill, size: 20, color: Color(0xFFE94B2A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    apod.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmMono(
                      fontSize: 11, color: _kAccent,
                      decoration: TextDecoration.underline,
                      decorationColor: _kAccent,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Image.network(
            apod.url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 180,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    height: 180, color: const Color(0xFF0b1024),
                    child: const Center(
                      child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5),
                    ),
                  ),
            errorBuilder: (_, __, ___) => Container(
              height: 120, color: const Color(0xFF0b1024),
              child: const Center(child: Icon(Icons.broken_image, color: _kFaint, size: 36)),
            ),
          ),

        // text section
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                apod.title,
                style: GoogleFonts.instrumentSerif(
                  fontSize: 16, fontStyle: FontStyle.italic,
                  color: _kFg, height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                apod.date,
                style: GoogleFonts.dmMono(
                  fontSize: 10, color: _kMuted, letterSpacing: .18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                apod.explanation,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmMono(
                  fontSize: 11.5, color: _kMuted,
                  fontWeight: FontWeight.w300, height: 1.55, letterSpacing: .01,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── _WikiCard ─────────────────────────────────────────────────────────────────
class _WikiCard extends StatelessWidget {
  final WikiInfo wiki;
  const _WikiCard({required this.wiki});

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = wiki.thumbnail != null && wiki.thumbnail!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasThumbnail)
          Image.network(
            wiki.thumbnail!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 140,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    height: 140, color: const Color(0xFF0b1024),
                    child: const Center(
                      child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5),
                    ),
                  ),
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.menu_book_outlined, size: 14, color: _kAccent),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      wiki.title,
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 16, fontStyle: FontStyle.italic,
                        color: _kFg, height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              if (wiki.description != null && wiki.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  wiki.description!,
                  style: GoogleFonts.dmMono(
                    fontSize: 10, color: _kMuted, letterSpacing: .12,
                  ),
                ),
              ],
              if (wiki.extract != null && wiki.extract!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  wiki.extract!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmMono(
                    fontSize: 11.5, color: _kMuted,
                    fontWeight: FontWeight.w300, height: 1.55, letterSpacing: .01,
                  ),
                ),
              ],
              if (wiki.url != null && wiki.url!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(bottom: 1),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _kAccent, width: .5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_in_new, size: 11, color: _kAccent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          wiki.url!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmMono(
                            fontSize: 10.5, color: _kAccent, letterSpacing: .08,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── _LoadingBubble ────────────────────────────────────────────────────────────
class _LoadingBubble extends StatefulWidget {
  const _LoadingBubble();

  @override
  State<_LoadingBubble> createState() => _LoadingBubbleState();
}

class _LoadingBubbleState extends State<_LoadingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _kNovaBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: _kHair),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final t = ((_ctrl.value - delay) % 1.0).abs();
                final opacity = t < 0.5 ? 0.3 + t * 1.4 : 1.0 - (t - 0.5) * 1.4;
                return Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  child: Opacity(
                    opacity: opacity.clamp(0.3, 1.0),
                    child: Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: _kAccent, shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

// ── _InputBar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  const _InputBar({required this.controller, required this.onSend, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kHair)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: enabled ? (_) => onSend() : null,
                  style: GoogleFonts.dmMono(
                    fontSize: 13.5, color: _kFg,
                    fontWeight: FontWeight.w300,
                  ),
                  decoration: InputDecoration(
                    hintText: '發送訊息…',
                    hintStyle: GoogleFonts.dmMono(
                      fontSize: 13, color: _kFaint,
                      fontWeight: FontWeight.w300,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF111111),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: _kHair),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: _kHair),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: _kAccent, width: 1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                color: enabled ? _kAccent : _kFaint,
                onPressed: enabled ? onSend : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
