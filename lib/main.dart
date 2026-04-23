import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova_cosmos_messenger/route/home_page.dart';
import 'package:nova_cosmos_messenger/services/favorites_db.dart';
import 'package:nova_cosmos_messenger/services/chat_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FavoritesDB.initDatabase();
  await ChatDB.initDatabase();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const MyApp());
}

const _kBg = Color(0xFF050505);
const _kSurface = Color(0xFF0f0f0f);
const _kFg = Color(0xFFF6F2EA);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'Nova Cosmos',
      theme: base.copyWith(
        scaffoldBackgroundColor: _kBg,
        colorScheme: base.colorScheme.copyWith(
          surface: _kSurface,
          onSurface: _kFg,
          primary: _kFg,
          onPrimary: _kBg,
          secondary: const Color(0xFFD9C5A7),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _kBg,
          foregroundColor: _kFg,
          elevation: 0,
          titleTextStyle: GoogleFonts.instrumentSerif(
            fontSize: 20,
            fontStyle: FontStyle.italic,
            color: _kFg,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0x14F6F2EA),
          thickness: 1,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1a1a1a),
          contentTextStyle: TextStyle(color: _kFg),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _kFg),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF111111),
          titleTextStyle: TextStyle(color: _kFg, fontSize: 18),
          contentTextStyle: TextStyle(color: Color(0xAAF6F2EA)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: const Color(0xFF111111),
          hintStyle: TextStyle(color: _kFg.withValues(alpha: 0.35)),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
