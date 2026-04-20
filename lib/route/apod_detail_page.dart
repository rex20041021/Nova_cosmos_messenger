import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nova_cosmos_messenger/config/api_config.dart';
import 'package:nova_cosmos_messenger/models/apod_data.dart';
import 'package:nova_cosmos_messenger/services/favorites_db.dart';

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
      await Share.share(
        '$caption\n\n${apod.url}',
        subject: apod.title,
      );
      return;
    }

    final cardUrl = '${ApiConfig.baseUrl}/apod/card?date=${apod.date}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response =
          await http.get(Uri.parse(cardUrl)).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/apod_${apod.date}_card.jpg');
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: caption,
        subject: apod.title,
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
          title: const Text('移除收藏'),
          content: Text('要從收藏移除「${widget.apod.title}」嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('移除'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await FavoritesDB.remove(widget.apod.date);
      if (!mounted) return;
      setState(() => _isFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已移除：${widget.apod.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      await FavoritesDB.add(widget.apod);
      if (!mounted) return;
      setState(() => _isFavorite = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已加入收藏：${widget.apod.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apod = widget.apod;
    final imageUrl = apod.hdurl ?? apod.url;

    return Scaffold(
      appBar: AppBar(
        title: Text(apod.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '分享',
            icon: const Icon(Icons.share),
            onPressed: _share,
          ),
          IconButton(
            tooltip: _isFavorite ? '移除收藏' : '加入收藏',
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : null,
            ),
            onPressed: _statusLoaded ? _toggleFavorite : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (apod.isVideo)
              Container(
                height: 200,
                color: Colors.black12,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.movie, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SelectableText(
                        apod.url,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
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
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) => const SizedBox(
                    height: 200,
                    child: Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apod.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        apod.date,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (apod.copyright != null &&
                      apod.copyright!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.copyright,
                            size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            apod.copyright!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    apod.explanation,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
