import 'package:flutter/material.dart';
import 'package:nova_cosmos_messenger/route/nova_page.dart';
import 'package:nova_cosmos_messenger/route/favorites_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    NovaPage(),
    FavoritesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.public),
            label: 'Nova',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            label: '收藏',
          ),
        ],
      ),
    );
  }
}
