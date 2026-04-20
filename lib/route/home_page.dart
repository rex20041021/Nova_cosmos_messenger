import 'package:flutter/material.dart';
import 'package:nova_cosmos_messenger/services/apod_service.dart';
import 'package:nova_cosmos_messenger/route/favorites_page.dart';
import 'package:nova_cosmos_messenger/route/chat_history_page.dart';
import 'package:nova_cosmos_messenger/route/apod_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _queryApod(BuildContext context) async {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final apod = await ApodService.fetchApod(date: dateStr);
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
                subtitle: '選擇日期，直接查看當天的星空',
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
