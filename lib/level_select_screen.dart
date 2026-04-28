import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import 'models/level.dart';
import 'ads_manager.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  List<int> _unlockedLevels = [1];
  final Map<int, int> _levelStars = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
    AdsManager().showInterstitialAd();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList('unlocked_levels') ?? ['1'];
    final starsStr = prefs.getString('level_stars') ?? '';
    
    setState(() {
      _unlockedLevels = unlocked.map(int.parse).toList();
      if (starsStr.isNotEmpty) {
        final entries = starsStr.split(',');
        for (var entry in entries) {
          final parts = entry.split(':');
          if (parts.length == 2) {
            _levelStars[int.parse(parts[0])] = int.parse(parts[1]);
          }
        }
      }
    });
  }

  Color _getLevelColor(int id) {
    if (id <= 5) return const Color(0xFF4ECDC4);
    if (id <= 10) return const Color(0xFFFFE66D);
    if (id <= 15) return const Color(0xFFFF6B6B);
    return const Color(0xFF96CEB4);
  }

  String _getStageName(int id) {
    if (id <= 5) return 'STAGE 1: SIMPLE';
    if (id <= 10) return 'STAGE 2: MEDIUM';
    if (id <= 15) return 'STAGE 3: COMPLEX';
    return 'STAGE 4: WORDS';
  }

  @override
  Widget build(BuildContext context) {
    final levels = Level.getAllLevels();
    
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
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'SELECT LEVEL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Level Grid
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: (levels.length / 5).ceil(),
                  itemBuilder: (context, stageIndex) {
                    final startIdx = stageIndex * 5;
                    final endIdx = (startIdx + 5).clamp(0, levels.length);
                    final stageLevels = levels.sublist(startIdx, endIdx);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
                          child: Text(
                            _getStageName(startIdx + 1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white54,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: stageLevels.length,
                          itemBuilder: (context, index) {
                            final level = stageLevels[index];
                            final isUnlocked = _unlockedLevels.contains(level.id);
                            final stars = _levelStars[level.id] ?? 0;
                            
                            return GestureDetector(
                              onTap: isUnlocked
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => GameScreen(levelId: level.id),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: isUnlocked
                                      ? LinearGradient(
                                          colors: [
                                            _getLevelColor(level.id),
                                            _getLevelColor(level.id).withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isUnlocked ? null : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isUnlocked
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isUnlocked) ...[
                                      Text(
                                        '${level.id}',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(3, (i) {
                                          return Icon(
                                            Icons.star,
                                            size: 14,
                                            color: i < stars
                                                ? const Color(0xFFFFE66D)
                                                : Colors.white.withOpacity(0.3),
                                          );
                                        }),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.lock,
                                        color: Colors.white.withOpacity(0.3),
                                        size: 24,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBannerAd(),
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
