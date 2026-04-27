import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'splash_screen.dart';
import 'ads_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Ads
  await AdsManager().initialize();

  runApp(const AlphaCrushApp());
}

class AlphaCrushApp extends StatelessWidget {
  const AlphaCrushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alpha Crush',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A11CB),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
