import 'package:flutter/material.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        centerTitle: false,
      ),
      body: const Center(
        child: Text(
          '尚無收藏',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
