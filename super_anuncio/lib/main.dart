import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

part 'home_screen.dart';
part 'analyzer_screen.dart';
part 'wizard_screen.dart';
part 'manual_competitor.dart';
part 'result_page.dart';
part 'coach_page.dart';
part 'history_page.dart';
part 'tasks_page.dart';
part 'achievements_page.dart';
part 'settings_page.dart';
part 'shopee_service.dart';
part 'shopee_connection.dart';
part 'shopee_web_collector.dart';
part 'shopee_web_collector_v2.dart';
part 'shopee_verification_gate.dart';
part 'gemini_service.dart';
part 'engine.dart';
part 'app_store.dart';
part 'expert_tips.dart';
part 'roas_strategy.dart';
part 'pdf_exporter.dart';
part 'minigame_page.dart';
part 'competitor_widgets.dart';
part 'gauge_solution_widgets.dart';
part 'branding_widgets.dart';
part 'utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SuperAnuncioApp());
}

const kOrange = Color(0xFFFF5A1F);
const kShareChannel = MethodChannel('super_anuncio/share');

class SuperAnuncioApp extends StatefulWidget {
  const SuperAnuncioApp({super.key});

  @override
  State<SuperAnuncioApp> createState() => _SuperAnuncioAppState();
}

class _SuperAnuncioAppState extends State<SuperAnuncioApp> {
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Anúncio',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kOrange, primary: kOrange),
        scaffoldBackgroundColor: const Color(0xFFF7F7F9),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: kOrange, brightness: Brightness.dark),
      ),
      home: SplashGate(
        childBuilder: () => HomePage(
          darkMode: darkMode,
          onDarkModeChanged: (value) => setState(() => darkMode = value),
        ),
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  final Widget Function() childBuilder;
  const SplashGate({super.key, required this.childBuilder});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (done) return widget.childBuilder();
    return const SplashPage();
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kOrange,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SaShield(size: 150),
            SizedBox(height: 20),
            SuperAnuncioLogo(fontSize: 36),
            SizedBox(height: 10),
            Text('Analise. Otimize. Venda mais.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
