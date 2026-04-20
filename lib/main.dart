import 'package:flutter/material.dart';
import 'package:nova_cosmos_messenger/route/home_page.dart';
import 'package:nova_cosmos_messenger/services/favorites_db.dart';
import 'package:nova_cosmos_messenger/services/chat_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FavoritesDB.initDatabase();
  await ChatDB.initDatabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NASA Cosmos Messenger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
