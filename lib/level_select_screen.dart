import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/level.dart';
import 'game_screen.dart';
import 'ads_manager.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with SingleTickerProviderStateMixin {
  final Map<int, int> _levelStars = {};
  int _unlockedLevel = 1;
  late AnimationController _shimmer;

  static const _stageLabels = [
    'SINGLE LETTERS', '2-LETTER WORDS', '3-LETTER WORDS', '4-LETTER WORDS'
  ];
  static const _stageColors = [
    [Color(0xFF6A11CB), Color(0xFF2575FC)],
    [Color(0xFFFF8F00), Color(0xFFE53935)],
    [Color(0xFF00897B), Color(0xFF2E7D32)],
    [Color(0xFF4A148C), Color(0xFFAD1457)],
  ];

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _unlockedLevel = prefs.getInt('unlocked_level') ?? 1;
      for (int i = 1; i <= 20; i++) {
        final s = prefs.getInt('stars_$i') ?? 0;
        if (s > 0) _levelStars[i] = s;
      }
    });
  }

  @override
  void dispose() {
    _shimmer.dispose();
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
            colors: [Color(0xFF0D0D1A), Color(0xFF1A0533), Color(0xFF0D0D1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text('SELECT LEVEL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4)),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // ── Levels scroll ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: 4,
                  itemBuilder: (_, stageIdx) {
                    final levels = Level.all
                        .where((l) =>
                            l.id > stageIdx * 5 && l.id <= (stageIdx + 1) * 5)
                        .toList();
                    final colors = _stageColors[stageIdx];
                    return _StageSection(
                      label: _stageLabels[stageIdx],
                      gradColors: colors,
                      levels: levels,
                      stars: _levelStars,
                      unlockedLevel: _unlockedLevel,
                      shimmer: _shimmer,
                      onTap: (level) => _onLevelTap(level),
                    );
                  },
                ),
              ),

              // ── Banner ad ──
              const BannerAdWidget(),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  void _onLevelTap(Level level) {
    if (level.id > _unlockedLevel) return;
    // Show interstitial every 3rd level tap
    final shouldShow = (level.id % 3 == 0);
    if (shouldShow) {
      AdsManager().showInterstitial(onDismissed: () => _goToGame(level));
    } else {
      _goToGame(level);
    }
  }

  void _goToGame(Level level) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => GameScreen(level: level),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1.0, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ).then((_) => _loadProgress());
  }
}

// ─── Stage section ────────────────────────────────────────────────────────────
class _StageSection extends StatelessWidget {
  final String label;
  final List<Color> gradColors;
  final List<Level> levels;
  final Map<int, int> stars;
  final int unlockedLevel;
  final AnimationController shimmer;
  final void Function(Level) onTap;

  const _StageSection({
    required this.label,
    required this.gradColors,
    required this.levels,
    required this.stars,
    required this.unlockedLevel,
    required this.shimmer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        // Stage header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: gradColors),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 3)),
        ),
        const SizedBox(height: 14),
        // Level grid: 5 in a row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: levels
              .map((l) => _LevelTile(
                    level: l,
                    starCount: stars[l.id] ?? 0,
                    isUnlocked: l.id <= unlockedLevel,
                    gradColors: gradColors,
                    shimmer: shimmer,
                    onTap: () => onTap(l),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─── Single level tile ────────────────────────────────────────────────────────
class _LevelTile extends StatelessWidget {
  final Level level;
  final int starCount;
  final bool isUnlocked;
  final List<Color> gradColors;
  final AnimationController shimmer;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.starCount,
    required this.isUnlocked,
    required this.gradColors,
    required this.shimmer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.of(context).size.width - 32 - 16) / 5;
    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) {
          final isNext = level.id == 1 || starCount == 0 && isUnlocked;
          return Container(
            width: size,
            height: size * 1.2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isUnlocked
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        gradColors[0].withOpacity(0.85),
                        gradColors[1].withOpacity(0.85),
                      ],
                    )
                  : null,
              color: isUnlocked ? null : Colors.white.withOpacity(0.06),
              border: isNext
                  ? Border.all(
                      color: Colors.white.withOpacity(
                          0.4 + shimmer.value * 0.5),
                      width: 2)
                  : null,
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: gradColors[0].withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isUnlocked)
                  Icon(Icons.lock_rounded,
                      color: Colors.white.withOpacity(0.25), size: 22)
                else ...[
                  Text('${level.id}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 10,
                        color: i < starCount
                            ? const Color(0xFFFFD700)
                            : Colors.white.withOpacity(0.18),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
