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

  // ── 17 Stage definitions ────────────────────────────────────────
  static const _stages = [
    _StageConfig(
      number: 1, label: 'SINGLE LETTERS', subtitle: 'Levels 1–3',
      fromId: 1, toId: 3,
      gradStart: Color(0xFF6A11CB), gradEnd: Color(0xFF2575FC),
      icon: Icons.abc_rounded,
    ),
    _StageConfig(
      number: 2, label: '2-LETTER WORDS', subtitle: 'Levels 4–6',
      fromId: 4, toId: 6,
      gradStart: Color(0xFF1565C0), gradEnd: Color(0xFF0097A7),
      icon: Icons.short_text_rounded,
    ),
    _StageConfig(
      number: 3, label: '3-LETTER WORDS', subtitle: 'Levels 7–9',
      fromId: 7, toId: 9,
      gradStart: Color(0xFF00897B), gradEnd: Color(0xFF2E7D32),
      icon: Icons.text_fields_rounded,
    ),
    _StageConfig(
      number: 4, label: '4-LETTER WORDS', subtitle: 'Levels 10–12',
      fromId: 10, toId: 12,
      gradStart: Color(0xFFFF8F00), gradEnd: Color(0xFFF4511E),
      icon: Icons.format_size_rounded,
    ),
    _StageConfig(
      number: 5, label: '5-LETTER WORDS', subtitle: 'Levels 13–15',
      fromId: 13, toId: 15,
      gradStart: Color(0xFFE53935), gradEnd: Color(0xFFAD1457),
      icon: Icons.title_rounded,
    ),
    _StageConfig(
      number: 6, label: '6-LETTER WORDS', subtitle: 'Levels 16–18',
      fromId: 16, toId: 18,
      gradStart: Color(0xFF6A1B9A), gradEnd: Color(0xFF4527A0),
      icon: Icons.sort_by_alpha_rounded,
    ),
    _StageConfig(
      number: 7, label: '7-LETTER WORDS', subtitle: 'Levels 19–21',
      fromId: 19, toId: 21,
      gradStart: Color(0xFF283593), gradEnd: Color(0xFF00838F),
      icon: Icons.auto_fix_high_rounded,
    ),
    _StageConfig(
      number: 8, label: '8-LETTER WORDS', subtitle: 'Levels 22–24',
      fromId: 22, toId: 24,
      gradStart: Color(0xFF558B2F), gradEnd: Color(0xFF827717),
      icon: Icons.star_half_rounded,
    ),
    _StageConfig(
      number: 9, label: '9-LETTER WORDS', subtitle: 'Levels 25–27',
      fromId: 25, toId: 27,
      gradStart: Color(0xFF4E342E), gradEnd: Color(0xFF37474F),
      icon: Icons.workspace_premium_rounded,
    ),
    _StageConfig(
      number: 10, label: '10-LETTER WORDS', subtitle: 'Levels 28–30',
      fromId: 28, toId: 30,
      gradStart: Color(0xFF880E4F), gradEnd: Color(0xFF4A148C),
      icon: Icons.military_tech_rounded,
    ),
    _StageConfig(
      number: 11, label: 'COMPOUND WORDS', subtitle: 'Levels 31–33',
      fromId: 31, toId: 33,
      gradStart: Color(0xFF0277BD), gradEnd: Color(0xFF00695C),
      icon: Icons.link_rounded,
    ),
    _StageConfig(
      number: 12, label: 'TECH & CODE', subtitle: 'Levels 34–36',
      fromId: 34, toId: 36,
      gradStart: Color(0xFF1B5E20), gradEnd: Color(0xFF006064),
      icon: Icons.code_rounded,
    ),
    _StageConfig(
      number: 13, label: 'SCIENCE TERMS', subtitle: 'Levels 37–39',
      fromId: 37, toId: 39,
      gradStart: Color(0xFF0D47A1), gradEnd: Color(0xFF006064),
      icon: Icons.science_rounded,
    ),
    _StageConfig(
      number: 14, label: 'GEOGRAPHY', subtitle: 'Levels 40–42',
      fromId: 40, toId: 42,
      gradStart: Color(0xFF1A237E), gradEnd: Color(0xFF880E4F),
      icon: Icons.public_rounded,
    ),
    _StageConfig(
      number: 15, label: 'NATURE & ANIMALS', subtitle: 'Levels 43–45',
      fromId: 43, toId: 45,
      gradStart: Color(0xFF33691E), gradEnd: Color(0xFF827717),
      icon: Icons.eco_rounded,
    ),
    _StageConfig(
      number: 16, label: 'BODY & MIND', subtitle: 'Levels 46–48',
      fromId: 46, toId: 48,
      gradStart: Color(0xFFC62828), gradEnd: Color(0xFF6A1B9A),
      icon: Icons.favorite_rounded,
    ),
    _StageConfig(
      number: 17, label: 'GRAND MASTER', subtitle: 'Levels 49–50',
      fromId: 49, toId: 50,
      gradStart: Color(0xFFFFD700), gradEnd: Color(0xFFFF8C00),
      icon: Icons.emoji_events_rounded,
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
            colors: [Color(0xFF0D0D1A), Color(0xFF1A0533), Color(0xFF0D0D1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
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
                      child: Text('SELECT LEVEL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: Text('${(_unlockedLevel - 1).clamp(0, 50)}/50',
                          style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),

              // ── Progress bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ((_unlockedLevel - 1) / 50).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                  ),
                ),
              ),

              // ── Stage list ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _stages.length,
                  itemBuilder: (_, i) {
                    final stage = _stages[i];
                    final levels = Level.all
                        .where((l) =>
                            l.id >= stage.fromId && l.id <= stage.toId)
                        .toList();
                    final isUnlocked = _unlockedLevel >= stage.fromId;
                    final isComplete = _unlockedLevel > stage.toId;
                    final earned = levels.fold<int>(
                        0, (s, l) => s + (_levelStars[l.id] ?? 0));
                    final maxPossible = levels.length * 3;

                    return _StageSection(
                      config: stage,
                      levels: levels,
                      stars: _levelStars,
                      unlockedLevel: _unlockedLevel,
                      shimmer: _shimmer,
                      isUnlocked: isUnlocked,
                      isComplete: isComplete,
                      earnedStars: earned,
                      maxStars: maxPossible,
                      onTap: _onLevelTap,
                    );
                  },
                ),
              ),

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
    // Interstitial every 5th level tap (not 3rd — less aggressive)
    if (level.id % 5 == 0) {
      AdsManager()
          .showInterstitial(onDismissed: () => _goToGame(level));
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

// ─── Stage config data class ──────────────────────────────────────
class _StageConfig {
  final int number;
  final String label;
  final String subtitle;
  final int fromId;
  final int toId;
  final Color gradStart;
  final Color gradEnd;
  final IconData icon;

  const _StageConfig({
    required this.number,
    required this.label,
    required this.subtitle,
    required this.fromId,
    required this.toId,
    required this.gradStart,
    required this.gradEnd,
    required this.icon,
  });
}

// ─── Stage section widget ─────────────────────────────────────────
class _StageSection extends StatelessWidget {
  final _StageConfig config;
  final List<Level> levels;
  final Map<int, int> stars;
  final int unlockedLevel;
  final AnimationController shimmer;
  final bool isUnlocked;
  final bool isComplete;
  final int earnedStars;
  final int maxStars;
  final void Function(Level) onTap;

  const _StageSection({
    required this.config,
    required this.levels,
    required this.stars,
    required this.unlockedLevel,
    required this.shimmer,
    required this.isUnlocked,
    required this.isComplete,
    required this.earnedStars,
    required this.maxStars,
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
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isUnlocked
                ? LinearGradient(colors: [config.gradStart, config.gradEnd])
                : null,
            color: isUnlocked ? null : Colors.white.withOpacity(0.04),
            border: !isUnlocked
                ? Border.all(
                    color: Colors.white.withOpacity(0.08), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(config.icon,
                  color: isUnlocked ? Colors.white : Colors.white24,
                  size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'STAGE ${config.number}  ',
                          style: TextStyle(
                              color: isUnlocked
                                  ? Colors.white.withOpacity(0.60)
                                  : Colors.white.withOpacity(0.20),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2),
                        ),
                        Text(
                          config.label,
                          style: TextStyle(
                              color: isUnlocked
                                  ? Colors.white
                                  : Colors.white30,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5),
                        ),
                      ],
                    ),
                    Text(config.subtitle,
                        style: TextStyle(
                            color: isUnlocked
                                ? Colors.white.withOpacity(0.55)
                                : Colors.white.withOpacity(0.18),
                            fontSize: 11)),
                  ],
                ),
              ),
              if (isUnlocked) ...[
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFD700), size: 13),
                const SizedBox(width: 3),
                Text('$earnedStars/$maxStars',
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ] else
                const Icon(Icons.lock_rounded,
                    color: Colors.white24, size: 18),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Level tiles row (max 3 per stage so always 1 row)
        _LevelRow(
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

// ─── Level row (3 tiles side by side) ────────────────────────────
class _LevelRow extends StatelessWidget {
  final List<Level> levels;
  final Map<int, int> stars;
  final int unlockedLevel;
  final List<Color> gradColors;
  final AnimationController shimmer;
  final void Function(Level) onTap;

  const _LevelRow({
    required this.levels,
    required this.stars,
    required this.unlockedLevel,
    required this.gradColors,
    required this.shimmer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 3 tiles with spacing: subtract padding (32) and 2 gaps (8 each)
    final tileW = (width - 32 - 16) / 3;

    return Row(
      children: List.generate(levels.length, (i) {
        final lvl = levels[i];
        return Padding(
          padding: EdgeInsets.only(right: i < levels.length - 1 ? 8 : 0),
          child: _LevelTile(
            level: lvl,
            starCount: stars[lvl.id] ?? 0,
            isUnlocked: lvl.id <= unlockedLevel,
            isNext: lvl.id == unlockedLevel,
            gradColors: gradColors,
            shimmer: shimmer,
            tileW: tileW,
            onTap: () => onTap(lvl),
          ),
        );
      }),
    );
  }
}

// ─── Single level tile ────────────────────────────────────────────
class _LevelTile extends StatelessWidget {
  final Level level;
  final int starCount;
  final bool isUnlocked;
  final bool isNext;
  final List<Color> gradColors;
  final AnimationController shimmer;
  final double tileW;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.starCount,
    required this.isUnlocked,
    required this.isNext,
    required this.gradColors,
    required this.shimmer,
    required this.tileW,
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
            width: tileW,
            height: tileW * 1.20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isUnlocked
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        gradColors[0].withOpacity(0.90),
                        gradColors[1].withOpacity(0.80),
                      ],
                    )
                  : null,
              color: isUnlocked ? null : Colors.white.withOpacity(0.05),
              border: isNext
                  ? Border.all(
                      color: Colors.white
                          .withOpacity(0.30 + shimmer.value * 0.55),
                      width: 2.5)
                  : !isUnlocked
                      ? Border.all(
                          color: Colors.white.withOpacity(0.07), width: 1)
                      : null,
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                          color: gradColors[0].withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isUnlocked)
                  Icon(Icons.lock_rounded,
                      color: Colors.white.withOpacity(0.20), size: 26)
                else ...[
                  Text('${level.id}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Icon(
                          i < starCount
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 13,
                          color: i < starCount
                              ? const Color(0xFFFFD700)
                              : Colors.white.withOpacity(0.22),
                        ),
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
