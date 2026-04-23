import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova_cosmos_messenger/models/chat_room.dart';
import 'package:nova_cosmos_messenger/services/chat_db.dart';
import 'package:nova_cosmos_messenger/route/chat_room_page.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF050505);
const _kFg     = Color(0xFFF6F2EA);
const _kMuted  = Color(0x72F6F2EA);
const _kFaint  = Color(0x38F6F2EA);
const _kAccent = Color(0xFFD9C5A7);
const _kHair   = Color(0x14F6F2EA);
const _kSurface = Color(0xFF111111);

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  List<ChatRoom> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rows = await ChatDB.getAllRooms();
    if (!mounted) return;
    setState(() { _rooms = rows; _loading = false; });
  }

  Future<void> _addRoom() async {
    final name = '對話 ${_rooms.length + 1}';
    final room = await ChatDB.createRoom(name);
    await _reload();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
    );
    await _reload();
  }

  Future<void> _renameRoom(ChatRoom room) async {
    final controller = TextEditingController(text: room.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: Text('重新命名',
            style: GoogleFonts.instrumentSerif(
                fontSize: 20, fontStyle: FontStyle.italic, color: _kFg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.dmMono(fontSize: 13, color: _kFg, fontWeight: FontWeight.w300),
          decoration: InputDecoration(
            hintText: '輸入新名稱',
            hintStyle: GoogleFonts.dmMono(fontSize: 13, color: _kFaint),
            filled: true,
            fillColor: const Color(0xFF1a1a1a),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kHair),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: GoogleFonts.dmMono(fontSize: 12, color: _kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('確定', style: GoogleFonts.dmMono(fontSize: 12, color: _kAccent)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ChatDB.renameRoom(room.id, newName);
      await _reload();
    }
  }

  Future<void> _confirmDelete(ChatRoom room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: Text('刪除對話',
            style: GoogleFonts.instrumentSerif(
                fontSize: 20, fontStyle: FontStyle.italic, color: _kFg)),
        content: Text('要刪除「${room.name}」嗎？',
            style: GoogleFonts.dmMono(fontSize: 12, color: _kMuted,
                fontWeight: FontWeight.w300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: GoogleFonts.dmMono(fontSize: 12, color: _kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('刪除', style: GoogleFonts.dmMono(fontSize: 12,
                color: const Color(0xFFE94B2A))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ChatDB.deleteRoom(room.id);
      await _reload();
    }
  }

  Future<void> _openRoom(ChatRoom room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
    );
    await _reload();
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '剛才';
    if (diff.inHours < 1) return '${diff.inMinutes} 分鐘前';
    if (diff.inDays < 1) return '${diff.inHours} 小時前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Nova'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kHair),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5))
          : _rooms.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  itemCount: _rooms.length,
                  itemBuilder: (context, i) => _RoomTile(
                    room: _rooms[i],
                    formattedDate: _formatDate(_rooms[i].updatedAt),
                    index: _rooms.length - i,
                    onTap: () => _openRoom(_rooms[i]),
                    onRename: () => _renameRoom(_rooms[i]),
                    onDelete: () => _confirmDelete(_rooms[i]),
                  ),
                ),
      floatingActionButton: _AddButton(onTap: _addRoom),
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
              'No conversations yet.\nTap + to begin.',
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

// ── _RoomTile ─────────────────────────────────────────────────────────────────
class _RoomTile extends StatefulWidget {
  final ChatRoom room;
  final String formattedDate;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _RoomTile({
    required this.room,
    required this.formattedDate,
    required this.index,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_RoomTile> createState() => _RoomTileState();
}

class _RoomTileState extends State<_RoomTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFF1a1a1a) : Colors.transparent,
            border: const Border(bottom: BorderSide(color: _kHair)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // index number
              SizedBox(
                width: 32,
                child: Text(
                  widget.index.toString().padLeft(2, '0'),
                  style: GoogleFonts.dmMono(
                      fontSize: 10, color: _kFaint, letterSpacing: .05),
                ),
              ),
              const SizedBox(width: 12),

              // title + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.room.name,
                      style: GoogleFonts.instrumentSerif(
                          fontSize: 20, color: _kFg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.formattedDate,
                      style: GoogleFonts.dmMono(
                          fontSize: 10, color: _kMuted, letterSpacing: .12),
                    ),
                  ],
                ),
              ),

              // actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TileAction(
                    icon: Icons.edit_outlined,
                    onTap: widget.onRename,
                  ),
                  const SizedBox(width: 4),
                  _TileAction(
                    icon: Icons.delete_outline,
                    color: const Color(0x88E94B2A),
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TileAction({
    required this.icon,
    this.color = _kFaint,
    required this.onTap,
  });

  @override
  State<_TileAction> createState() => _TileActionState();
}

class _TileActionState extends State<_TileAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: _pressed ? _kHair : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(widget.icon, size: 18,
            color: _pressed
                ? widget.color.withValues(alpha: 1)
                : widget.color),
      ),
    );
  }
}

// ── _AddButton ────────────────────────────────────────────────────────────────
class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: _pressed ? _kAccent.withValues(alpha: 0.85) : _kAccent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withValues(alpha: _pressed ? 0.15 : 0.3),
              blurRadius: 20, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: _kBg, size: 22),
      ),
    );
  }
}
