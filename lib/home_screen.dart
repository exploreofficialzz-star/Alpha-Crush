import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'game_screen.dart';
import 'ads_manager.dart';
import 'sound_manager.dart';
import 'currency_manager.dart';
import 'daily_reward_manager.dart';
import 'daily_challenge_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _btnCtrl;
  late Animation<double> _btnScale;
  int _highScore = 0;
  int _unlockedLevel = 1;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _btnScale = Tween(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));
    _coins = CurrencyManager().balance;
    CurrencyManager().addListener(_onCoinsChanged);
    _loadProgress();
    // BGM already started from splash — no need to restart here
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDailyReward());
  }

  void _onCoinsChanged() {
    if (!mounted) return;
    setState(() => _coins = CurrencyManager().balance);
  }

  void _maybeShowDailyReward() {
    if (!mounted) return;
    if (!DailyRewardManager().canClaimToday) return;
    final previewDay = DailyRewardManager().nextStreakDay;
    final reward = DailyRewardManager().rewardFor(previewDay);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DailyRewardDialog(
        day: previewDay,
        reward: reward,
        onClaim: () async {
          SoundManager().playTap();
          await DailyRewardManager().claimToday();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _onDailyChallengeTap() async {
    SoundManager().playTap();
    final level =
        DailyChallengeManager().todaysLevel(unlockedLevel: _unlockedLevel);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(level: level, isDailyChallenge: true),
      ),
    );
    // isCompletedToday is read live in build(), not cached — a plain
    // rebuild after returning is enough to flip the card to its
    // "come back tomorrow" state, no persistent listener needed.
    if (mounted) setState(() {});
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _highScore = prefs.getInt('high_score') ?? 0;
      _unlockedLevel = prefs.getInt('unlocked_level') ?? 1;
    });
  }

  @override
  void dispose() {
    CurrencyManager().removeListener(_onCoinsChanged);
    _bgCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // ── Animated gradient background ──
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) {
              final t = _bgCtrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                          const Color(0xFF0D0D1A),
                          const Color(0xFF1A0533),
                          math.sin(t * math.pi))!,
                      Color.lerp(
                          const Color(0xFF1A0533),
                          const Color(0xFF0D1A33),
                          math.cos(t * math.pi))!,
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Floating candy tiles ──
          ...List.generate(16, (i) => _BgTile(index: i, ctrl: _bgCtrl, size: size)),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statChip(Icons.emoji_events_rounded,
                          _highScore.toString(), const Color(0xFFFFD700)),
                      GestureDetector(
                        onTap: () {
                          SoundManager().playTap();
                          Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1),
                          ),
                          child: const Icon(Icons.settings_rounded,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                      _statChip(Icons.lock_open_rounded,
                          'LVL $_unlockedLevel', const Color(0xFF64B5F6)),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _statChip(Icons.monetization_on_rounded, '$_coins',
                        const Color(0xFFFFD700)),
                    if (DailyRewardManager().streakDay > 0) ...[
                      const SizedBox(width: 10),
                      _statChip(
                          Icons.local_fire_department_rounded,
                          '${DailyRewardManager().streakDay}',
                          const Color(0xFFFF7043)),
                    ],
                  ],
                ),

                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _dailyChallengeCard(),
                ),

                const Spacer(),

                // ── Logo ──
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A11CB).withOpacity(0.55),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFB388FF)],
                  ).createShader(b),
                  child: const Text('ALPHA',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 10)),
                ),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ).createShader(b),
                  child: const Text('CRUSH',
                      style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 8)),
                ),

                const SizedBox(height: 6),
                Text('Build letters. Crush levels.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.50),
                        fontSize: 14,
                        letterSpacing: 2)),

                const Spacer(),

                // ── Sample color tiles row ──
                _colorTilesRow(),
                const SizedBox(height: 24),

                // ── Play button ──
                ScaleTransition(
                  scale: _btnScale,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _btnCtrl.forward();
                      SoundManager().playTap();
                    },
                    onTapUp: (_) {
                      _btnCtrl.reverse();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LevelSelectScreen()));
                    },
                    onTapCancel: () => _btnCtrl.reverse(),
                    child: Container(
                      width: size.width * 0.72,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8C00).withOpacity(0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('PLAY',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 6)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Ad banner ──
                const BannerAdWidget(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyChallengeCard() {
    final completed = DailyChallengeManager().isCompletedToday;
    return GestureDetector(
      onTap: _onDailyChallengeTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: completed
                ? [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.06)]
                : [const Color(0xFFFF7043).withOpacity(0.30),
                   const Color(0xFFE53935).withOpacity(0.20)],
          ),
          border: Border.all(
              color: completed
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFFF7043).withOpacity(0.5),
              width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: (completed
                        ? Colors.white
                        : const Color(0xFFFF7043))
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.local_fire_department_rounded,
                color: completed ? Colors.white54 : const Color(0xFFFF7043),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Challenge',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: completed ? Colors.white54 : Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                      completed
                          ? 'Come back tomorrow!'
                          : 'Bonus level · +${DailyChallengeManager.bonusCoins} coins',
                      style: TextStyle(
                          fontSize: 11,
                          color: completed
                              ? Colors.white30
                              : Colors.white.withOpacity(0.65))),
                ],
              ),
            ),
            if (!completed)
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.30), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _colorTilesRow() {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
    const colors = [
      Color(0xFFE53935), Color(0xFF1565C0), Color(0xFFFF8F00),
      Color(0xFF6A1B9A), Color(0xFF00897B), Color(0xFFF4511E),
      Color(0xFF2E7D32),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: colors[i].withOpacity(0.85),
            boxShadow: [
              BoxShadow(color: colors[i].withOpacity(0.4), blurRadius: 8),
            ],
          ),
          child: Center(
            child: Text(letters[i],
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ),
        );
      }),
    );
  }
}

// ── Floating background tile widget ──────────────────────────────────────────
class _BgTile extends StatelessWidget {
  final int index;
  final AnimationController ctrl;
  final Size size;

  const _BgTile(
      {required this.index, required this.ctrl, required this.size});

  static const _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
    'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P'
  ];
  static const _cols = [
    Color(0xFFE53935), Color(0xFF1565C0), Color(0xFFFF8F00), Color(0xFF6A1B9A),
    Color(0xFF00897B), Color(0xFFF4511E), Color(0xFF2E7D32), Color(0xFFAD1457),
    Color(0xFF0097A7), Color(0xFF558B2F), Color(0xFFC62828), Color(0xFF0277BD),
    Color(0xFFEF6C00), Color(0xFF4527A0), Color(0xFFE65100), Color(0xFF37474F),
  ];

  @override
  Widget build(BuildContext context) {
    final x = (index * 73 % 90) / 100.0;
    final y = (index * 47 % 90) / 100.0;
    return Positioned(
      left: x * size.width,
      top: y * size.height,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final angle = (ctrl.value * 2 * math.pi + index * 0.8);
          final opacity = 0.04 + (math.sin(angle) * 0.03).abs();
          return Transform.rotate(
            angle: angle * 0.15,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _cols[index % _cols.length],
                ),
                child: Center(
                  child: Text(
                    _letters[index % _letters.length],
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Daily login reward dialog ───────────────────────────────────────────────
class _DailyRewardDialog extends StatelessWidget {
  final int day; // raw streak count (can exceed 7 — shown as "DAY 12" etc.)
  final int reward;
  final VoidCallback onClaim;

  const _DailyRewardDialog({
    required this.day,
    required this.reward,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final cyclePos = ((day - 1) % 7) + 1; // 1-7, position within this week
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0A2E), Color(0xFF0D1A33)],
          ),
          border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Color(0xFFFF7043), size: 36),
            const SizedBox(height: 6),
            Text('DAY $day STREAK',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (i) {
                final pipDay = i + 1;
                final isToday = pipDay == cyclePos;
                final isPast = pipDay < cyclePos;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isToday ? 14 : 10,
                  height: isToday ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday
                        ? const Color(0xFFFFD700)
                        : isPast
                            ? const Color(0xFFFFD700).withOpacity(0.5)
                            : Colors.white.withOpacity(0.15),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFFFFD700).withOpacity(0.12),
                border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: Color(0xFFFFD700), size: 22),
                  const SizedBox(width: 8),
                  Text('+$reward',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onClaim,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                ),
                child: const Center(
                  child: Text('CLAIM',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
