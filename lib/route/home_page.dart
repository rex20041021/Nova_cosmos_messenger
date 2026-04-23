import 'package:flutter/material.dart';
import 'package:nova_cosmos_messenger/services/apod_service.dart';
import 'package:nova_cosmos_messenger/route/favorites_page.dart';
import 'package:nova_cosmos_messenger/route/chat_history_page.dart';
import 'package:nova_cosmos_messenger/route/apod_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _queryApod(BuildContext context) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('選擇日期'),
              subtitle: const Text('挑一個你想看的日子'),
              onTap: () => Navigator.pop(ctx, 'date'),
            ),
            ListTile(
              leading: const Icon(Icons.casino),
              title: const Text('隨機一天'),
              subtitle: const Text('讓 NASA 隨機挑一張給你'),
              onTap: () => Navigator.pop(ctx, 'random'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) return;

    if (mode == 'date') {
      await _queryByDate(context);
    } else if (mode == 'random') {
      await _queryRandom(context);
    }
  }

  Future<void> _queryByDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1995, 6, 16),
      lastDate: DateTime.now(),
      helpText: '選擇 APOD 日期',
    );
    if (picked == null) return;
    if (!context.mounted) return;

    final dateStr =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await _fetchAndShow(context, () => ApodService.fetchApod(date: dateStr));
  }

  Future<void> _queryRandom(BuildContext context) async {
    await _fetchAndShow(context, () => ApodService.fetchApod(random: true));
  }

  Future<void> _fetchAndShow(
    BuildContext context,
    Future<dynamic> Function() fetcher,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final apod = await fetcher();
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ApodDetailPage(apod: apod)),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查詢失敗：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NASA Cosmos Messenger'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                '探索宇宙',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '選擇一個功能開始',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              _HomeButton(
                icon: Icons.forum,
                title: 'Nova',
                subtitle: '與 Nova 聊天，查詢每日星空並保留紀錄',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatHistoryPage()),
                ),
              ),
              const SizedBox(height: 12),
              _HomeButton(
                icon: Icons.calendar_today,
                title: 'APOD',
                subtitle: '挑一個日期，或讓 NOVA 隨機推一張星空',
                onTap: () => _queryApod(context),
              ),
              const SizedBox(height: 12),
              _HomeButton(
                icon: Icons.star_border,
                title: '收藏',
                subtitle: '瀏覽已收藏的星空圖',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoritesPage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.indigo.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Colors.indigo),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
