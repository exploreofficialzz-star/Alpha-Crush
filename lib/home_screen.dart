import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'ads_manager.dart';
import 'sound_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    SoundManager().playBGM();
    AdsManager().showBannerAd();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with settings
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Logo Area
              AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatController.value * 10 - 5),
                    child: child,
                  );
                },
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Shimmer.fromColors(
                      baseColor: Colors.white,
                      highlightColor: const Color(0xFFFFE66D),
                      child: const Text(
                        'ALPHA CRUSH',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crush fragments. Build words.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Menu Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _buildMenuButton(
                      'PLAY NOW',
                      const Color(0xFFFF6B6B),
                      Icons.play_arrow_rounded,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GameScreen(levelId: 1)),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      'LEVELS',
                      const Color(0xFF4ECDC4),
                      Icons.grid_view_rounded,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      'SETTINGS',
                      const Color(0xFF96CEB4),
                      Icons.settings_rounded,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // By chAs footer
              const Text(
                'By chAs',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white30,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBannerAd(),
    );
  }

  Widget _buildMenuButton(String text, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildBannerAd() {
    final bannerAd = AdsManager().bannerAd;
    if (bannerAd != null) {
      return Container(
        color: Colors.transparent,
        width: bannerAd.size.width.toDouble(),
        height: bannerAd.size.height.toDouble(),
        child: AdWidget(ad: bannerAd),
      );
    }
    return null;
  }
}
