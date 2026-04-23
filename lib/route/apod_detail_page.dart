import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nova_cosmos_messenger/config/api_config.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';
import 'package:nova_cosmos_messenger/services/favorites_db.dart';

const _kBg     = Color(0xFF050505);
const _kFg     = Color(0xFFF6F2EA);
const _kMuted  = Color(0x72F6F2EA);
const _kAccent = Color(0xFFD9C5A7);
const _kHair   = Color(0x14F6F2EA);
const _kSignal = Color(0xFFE94B2A);

class ApodDetailPage extends StatefulWidget {
  final ApodData apod;

  const ApodDetailPage({super.key, required this.apod});

  @override
  State<ApodDetailPage> createState() => _ApodDetailPageState();
}

class _ApodDetailPageState extends State<ApodDetailPage> {
  bool _isFavorite = false;
  bool _statusLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final exists = await FavoritesDB.exists(widget.apod.date);
    if (!mounted) return;
    setState(() {
      _isFavorite = exists;
      _statusLoaded = true;
    });
  }

  Future<void> _share() async {
    final apod = widget.apod;
    final caption =
        '${apod.title}（${apod.date}）\n\n${apod.explanation}\n\n— NASA Astronomy Picture of the Day';

    if (apod.isVideo) {
      await Share.share('$caption\n\n${apod.url}', subject: apod.title);
      return;
    }

    // 先拉卡片，再顯示預覽
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _kAccent, strokeWidth: 1.5),
      ),
    );

    try {
      final cardUrl = '${ApiConfig.baseUrl}/apod/card?date=${apod.date}';
      final response = await http
          .get(Uri.parse(cardUrl))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final bytes = response.bodyBytes;

      if (!mounted) return;
      Navigator.pop(context); // close loading

      // 顯示預覽 bottom sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF0f0f0f),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _SharePreviewSheet(
          apod: apod,
          cardBytes: bytes,
          caption: caption,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失敗：$e')),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    if (!_statusLoaded) return;
    if (_isFavorite) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111111),
          title: Text('移除收藏',
              style: GoogleFonts.instrumentSerif(
                  fontSize: 20, fontStyle: FontStyle.italic, color: _kFg)),
          content: Text('要從收藏移除「${widget.apod.title}」嗎？',
              style: GoogleFonts.dmMono(
                  fontSize: 12, color: _kMuted, fontWeight: FontWeight.w300)),
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
      if (ok != true) return;
      await FavoritesDB.remove(widget.apod.date);
      if (!mounted) return;
      setState(() => _isFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除：${widget.apod.title}'),
            duration: const Duration(seconds: 2)));
    } else {
      await FavoritesDB.add(widget.apod);
      if (!mounted) return;
      setState(() => _isFavorite = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加入收藏：${widget.apod.title}'),
            duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final apod = widget.apod;
    final imageUrl = apod.hdurl ?? apod.url;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(apod.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '分享',
            icon: const Icon(Icons.ios_share_outlined, size: 22),
            color: _kMuted,
            onPressed: _share,
          ),
          IconButton(
            tooltip: _isFavorite ? '移除收藏' : '加入收藏',
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 22,
              color: _isFavorite ? _kAccent : _kMuted,
            ),
            onPressed: _statusLoaded ? _toggleFavorite : null,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kHair),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (apod.isVideo)
              Container(
                height: 220,
                color: const Color(0xFF0b1024),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_outline,
                        size: 52, color: _kAccent),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SelectableText(
                        apod.url,
                        textAlign: TextAlign.center,
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
              InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 260,
                          child: Center(
                            child: CircularProgressIndicator(
                                color: _kAccent, strokeWidth: 1.5),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 200,
                    child: Center(
                        child: Icon(Icons.broken_image,
                            size: 48, color: _kMuted)),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apod.title,
                    style: GoogleFonts.instrumentSerif(
                        fontSize: 26, fontStyle: FontStyle.italic,
                        color: _kFg, height: 1.15),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Text(apod.date,
                        style: GoogleFonts.dmMono(
                            fontSize: 11, color: _kMuted, letterSpacing: .18)),
                    if (apod.copyright != null &&
                        apod.copyright!.trim().isNotEmpty) ...[
                      Text('  ·  ',
                          style: GoogleFonts.dmMono(
                              fontSize: 11, color: _kMuted)),
                      Expanded(
                        child: Text(
                          apod.copyright!.replaceAll('\n', ' ').trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmMono(
                              fontSize: 11, color: _kMuted, letterSpacing: .06),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 20),
                  Container(height: 1, color: _kHair),
                  const SizedBox(height: 18),
                  Text(
                    apod.explanation,
                    style: GoogleFonts.dmMono(
                      fontSize: 13, color: _kMuted,
                      fontWeight: FontWeight.w300, height: 1.65, letterSpacing: .01,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 分享預覽 bottom sheet ──────────────────────────────────────────────────────
class _SharePreviewSheet extends StatefulWidget {
  final ApodData apod;
  final Uint8List cardBytes;
  final String caption;

  const _SharePreviewSheet({
    required this.apod,
    required this.cardBytes,
    required this.caption,
  });

  @override
  State<_SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<_SharePreviewSheet> {
  bool _sharing = false;

  Future<void> _doShare() async {
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/apod_${widget.apod.date}_card.jpg');
      await file.writeAsBytes(widget.cardBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.caption,
        subject: widget.apod.title,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _kHair, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('分享卡片',
                    style: GoogleFonts.instrumentSerif(
                        fontSize: 20, fontStyle: FontStyle.italic,
                        color: _kFg)),
                Text('長按可儲存圖片',
                    style: GoogleFonts.dmMono(
                        fontSize: 10, color: _kMuted, letterSpacing: .1)),
              ],
            ),
          ),

          Container(height: 1, color: _kHair),

          // card preview
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(widget.cardBytes, fit: BoxFit.contain),
                ),
              ),
            ),
          ),

          // share button
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kHair)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: _sharing
                        ? _kAccent.withValues(alpha: 0.6)
                        : _kAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextButton(
                    onPressed: _sharing ? null : _doShare,
                    child: _sharing
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: _kBg, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.ios_share_outlined,
                                  size: 18, color: _kBg),
                              const SizedBox(width: 8),
                              Text('分享',
                                  style: GoogleFonts.dmMono(
                                      fontSize: 14, color: _kBg,
                                      letterSpacing: .1)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
