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

  // ── Stage definitions ──────────────────────────────────────────
  static const _stages = [
    _StageConfig(
      label: 'SINGLE LETTERS',
      subtitle: 'Levels 1 – 10',
      fromId: 1,
      toId: 10,
      gradStart: Color(0xFF6A11CB),
      gradEnd: Color(0xFF2575FC),
      icon: Icons.abc_rounded,
    ),
    _StageConfig(
      label: '2-LETTER WORDS',
      subtitle: 'Levels 11 – 20',
      fromId: 11,
      toId: 20,
      gradStart: Color(0xFFFF8F00),
      gradEnd: Color(0xFFE53935),
      icon: Icons.short_text_rounded,
    ),
    _StageConfig(
      label: '3-LETTER WORDS',
      subtitle: 'Levels 21 – 35',
      fromId: 21,
      toId: 35,
      gradStart: Color(0xFF00897B),
      gradEnd: Color(0xFF2E7D32),
      icon: Icons.text_fields_rounded,
    ),
    _StageConfig(
      label: '4-LETTER WORDS',
      subtitle: 'Levels 36 – 50',
      fromId: 36,
      toId: 50,
      gradStart: Color(0xFF4A148C),
      gradEnd: Color(0xFFAD1457),
      icon: Icons.title_rounded,
    ),
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
      for (int i = 1; i <= 50; i++) {
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
            colors: [
              Color(0xFF0D0D1A),
              Color(0xFF1A0533),
              Color(0xFF0D0D1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'SELECT LEVEL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    // Progress summary
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: Text(
                        '${_unlockedLevel - 1}/50',
                        style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Overall progress bar ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ((_unlockedLevel - 1) / 50).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                  ),
                ),
              ),

              // ── Stage scroll ─────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _stages.length,
                  itemBuilder: (_, i) {
                    final stage = _stages[i];
                    final levels = Level.all
                        .where((l) =>
                            l.id >= stage.fromId && l.id <= stage.toId)
                        .toList();
                    final stageUnlocked = _unlockedLevel >= stage.fromId;
                    final stageComplete = _unlockedLevel > stage.toId;
                    final stageStars = levels.fold<int>(
                        0, (sum, l) => sum + (_levelStars[l.id] ?? 0));
                    final maxStars = levels.length * 3;

                    return _StageSection(
                      config: stage,
                      levels: levels,
                      stars: _levelStars,
                      unlockedLevel: _unlockedLevel,
                      shimmer: _shimmer,
                      isStageUnlocked: stageUnlocked,
                      isStageComplete: stageComplete,
                      stageStars: stageStars,
                      maxStars: maxStars,
                      onTap: _onLevelTap,
                    );
                  },
                ),
              ),

              // ── Banner ad ────────────────────────────────────
              const BannerAdWidget(),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tap handler ──────────────────────────────────────────────
  void _onLevelTap(Level level) {
    if (level.id > _unlockedLevel) return;
    // Interstitial every 3rd level tap
    if (level.id % 3 == 0) {
      AdsManager().showInterstitial(
          onDismissed: () => _goToGame(level));
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
              .animate(CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ).then((_) => _loadProgress());
  }
}

// ── Stage config ─────────────────────────────────────────────────
class _StageConfig {
  final String label;
  final String subtitle;
  final int fromId;
  final int toId;
  final Color gradStart;
  final Color gradEnd;
  final IconData icon;

  const _StageConfig({
    required this.label,
    required this.subtitle,
    required this.fromId,
    required this.toId,
    required this.gradStart,
    required this.gradEnd,
    required this.icon,
  });
}

// ── Stage section ─────────────────────────────────────────────────
class _StageSection extends StatelessWidget {
  final _StageConfig config;
  final List<Level> levels;
  final Map<int, int> stars;
  final int unlockedLevel;
  final AnimationController shimmer;
  final bool isStageUnlocked;
  final bool isStageComplete;
  final int stageStars;
  final int maxStars;
  final void Function(Level) onTap;

  const _StageSection({
    required this.config,
    required this.levels,
    required this.stars,
    required this.unlockedLevel,
    required this.shimmer,
    required this.isStageUnlocked,
    required this.isStageComplete,
    required this.stageStars,
    required this.maxStars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Stage header ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isStageUnlocked
                ? LinearGradient(
                    colors: [config.gradStart, config.gradEnd])
                : LinearGradient(colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.03),
                  ]),
            border: !isStageUnlocked
                ? Border.all(
                    color: Colors.white.withOpacity(0.10), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(config.icon,
                  color: isStageUnlocked
                      ? Colors.white
                      : Colors.white24,
                  size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.label,
                        style: TextStyle(
                            color: isStageUnlocked
                                ? Colors.white
                                : Colors.white30,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 2)),
                    Text(config.subtitle,
                        style: TextStyle(
                            color: isStageUnlocked
                                ? Colors.white.withOpacity(0.60)
                                : Colors.white.withOpacity(0.20),
                            fontSize: 11)),
                  ],
                ),
              ),
              // Stars earned
              if (isStageUnlocked)
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFD700), size: 14),
                    const SizedBox(width: 3),
                    Text('$stageStars/$maxStars',
                        style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ],
                )
              else
                const Icon(Icons.lock_rounded,
                    color: Colors.white24, size: 18),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Level grid ───────────────────────────────────────
        _LevelGrid(
          levels: levels,
          stars: stars,
          unlockedLevel: unlockedLevel,
          gradColors: [config.gradStart, config.gradEnd],
          shimmer: shimmer,
          onTap: onTap,
        ),
      ],
    );
  }
}

// ── Level grid (5 tiles per row) ─────────────────────────────────
class _LevelGrid extends StatelessWidget {
  final List<Level> levels;
  final Map<int, int> stars;
  final int unlockedLevel;
  final List<Color> gradColors;
  final AnimationController shimmer;
  final void Function(Level) onTap;

  const _LevelGrid({
    required this.levels,
    required this.stars,
    required this.unlockedLevel,
    required this.gradColors,
    required this.shimmer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cols = 5;
    final rows = (levels.length / cols).ceil();
    final tileWidth =
        (MediaQuery.of(context).size.width - 32 - (cols - 1) * 6) / cols;

    return Column(
      children: List.generate(rows, (r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: List.generate(cols, (c) {
              final idx = r * cols + c;
              if (idx >= levels.length) {
                return SizedBox(width: tileWidth);
              }
              final level = levels[idx];
              return Padding(
                padding: EdgeInsets.only(right: c < cols - 1 ? 6 : 0),
                child: _LevelTile(
                  level: level,
                  starCount: stars[level.id] ?? 0,
                  isUnlocked: level.id <= unlockedLevel,
                  isNext: level.id == unlockedLevel,
                  gradColors: gradColors,
                  shimmer: shimmer,
                  tileWidth: tileWidth,
                  onTap: () => onTap(level),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ── Single level tile ─────────────────────────────────────────────
class _LevelTile extends StatelessWidget {
  final Level level;
  final int starCount;
  final bool isUnlocked;
  final bool isNext;
  final List<Color> gradColors;
  final AnimationController shimmer;
  final double tileWidth;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.starCount,
    required this.isUnlocked,
    required this.isNext,
    required this.gradColors,
    required this.shimmer,
    required this.tileWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) {
          return Container(
            width: tileWidth,
            height: tileWidth * 1.15,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isUnlocked
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        gradColors[0].withOpacity(0.85),
                        gradColors[1].withOpacity(0.80),
                      ],
                    )
                  : null,
              color: isUnlocked ? null : Colors.white.withOpacity(0.05),
              border: isNext
                  ? Border.all(
                      color: Colors.white
                          .withOpacity(0.35 + shimmer.value * 0.50),
                      width: 2.0)
                  : isUnlocked
                      ? null
                      : Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: gradColors[0].withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isUnlocked)
                  Icon(Icons.lock_rounded,
                      color: Colors.white.withOpacity(0.20), size: 20)
                else ...[
                  // Level number
                  Text(
                    '${level.id}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: tileWidth > 55 ? 18 : 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Icon(
                        i < starCount
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: tileWidth > 55 ? 10 : 9,
                        color: i < starCount
                            ? const Color(0xFFFFD700)
                            : Colors.white.withOpacity(0.20),
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
