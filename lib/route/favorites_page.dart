import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';
import 'package:nova_cosmos_messenger/services/favorites_db.dart';
import 'package:nova_cosmos_messenger/route/apod_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF050505);
const _kFg     = Color(0xFFF6F2EA);
const _kMuted  = Color(0x72F6F2EA);
const _kAccent = Color(0xFFD9C5A7);
const _kHair   = Color(0x14F6F2EA);
const _kSignal = Color(0xFFE94B2A);

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<ApodData> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rows = await FavoritesDB.getAll();
    if (!mounted) return;
    setState(() { _items = rows; _loading = false; });
  }

  Future<void> _openItem(ApodData apod) async {
    if (apod.isVideo) {
      final uri = Uri.tryParse(apod.url);
      if (uri == null) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟連結：${apod.url}')),
        );
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApodDetailPage(apod: apod)),
    );
    await _reload();
  }

  Future<void> _confirmDelete(ApodData apod) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          '移除收藏',
          style: GoogleFonts.instrumentSerif(
              fontSize: 20, fontStyle: FontStyle.italic, color: _kFg),
        ),
        content: Text(
          '要移除「${apod.title}」嗎？',
          style: GoogleFonts.dmMono(
              fontSize: 12, color: _kMuted, fontWeight: FontWeight.w300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: GoogleFonts.dmMono(fontSize: 12, color: _kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('移除',
                style: GoogleFonts.dmMono(fontSize: 12, color: _kSignal)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FavoritesDB.remove(apod.date);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('收藏'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: _kMuted,
            onPressed: _reload,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kHair),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5))
          : _items.isEmpty
              ? _buildEmptyState()
              : _buildGrid(),
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
              'No skies saved yet.\nLong-press an APOD card in chat\nto add it here.',
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

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: _items.length,
      itemBuilder: (context, i) => _FavoriteCard(
        apod: _items[i],
        index: i + 1,
        onTap: () => _openItem(_items[i]),
        onLongPress: () => _confirmDelete(_items[i]),
      ),
    );
  }
}

// ── _FavoriteCard ─────────────────────────────────────────────────────────────
class _FavoriteCard extends StatefulWidget {
  final ApodData apod;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FavoriteCard({
    required this.apod,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) => _ctrl.forward(),
        onTapCancel: () => _ctrl.forward(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // image / placeholder
              widget.apod.isVideo
                  ? Container(
                      color: const Color(0xFF0b1024),
                      child: const Center(
                        child: Icon(Icons.play_circle_outline,
                            color: _kAccent, size: 42),
                      ),
                    )
                  : Image.network(
                      widget.apod.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF0b1024),
                        child: const Center(
                          child: Icon(Icons.broken_image,
                              color: _kMuted, size: 32),
                        ),
                      ),
                    ),

              // bottom gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.4, 1.0],
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                ),
              ),

              // top-left index
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.index.toString().padLeft(2, '0'),
                    style: GoogleFonts.dmMono(
                        fontSize: 9, color: _kAccent, letterSpacing: .15),
                  ),
                ),
              ),

              // video badge
              if (widget.apod.isVideo)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('VIDEO',
                        style: GoogleFonts.dmMono(
                            fontSize: 8, color: _kSignal, letterSpacing: .2)),
                  ),
                ),

              // bottom text
              Positioned(
                left: 10, right: 10, bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.apod.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: _kFg,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.apod.date,
                      style: GoogleFonts.dmMono(
                          fontSize: 9, color: _kMuted, letterSpacing: .15),
                    ),
                  ],
                ),
              ),

              // hairline border
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _kHair),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
