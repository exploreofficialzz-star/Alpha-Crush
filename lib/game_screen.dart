import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_logic.dart';
import 'models/level.dart';
import 'models/game_state.dart';
import 'letter_fragments.dart';
import 'ads_manager.dart';
import 'sound_manager.dart';
import 'currency_manager.dart';
import 'daily_challenge_manager.dart';

class GameScreen extends StatefulWidget {
  final Level level;
  final bool isDailyChallenge;
  const GameScreen(
      {super.key, required this.level, this.isDailyChallenge = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late GameLogic _logic;
  late AnimationController _comboCtrl;
  late AnimationController _heartCtrl;
  late AnimationController _celebCtrl;
  late AnimationController _screenPunchCtrl;
  late Animation<double> _comboScale;
  late Animation<double> _screenPunchAnim;
  late ConfettiController _confettiCtrl;

  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _logic = GameLogic();

    _comboCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _celebCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _screenPunchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _confettiCtrl = ConfettiController(duration: const Duration(milliseconds: 900));

    _comboScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _comboCtrl, curve: Curves.easeInOut));

    _screenPunchAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 75),
    ]).animate(CurvedAnimation(parent: _screenPunchCtrl, curve: Curves.easeOut));

    _logic.addListener(_onStateChange);
    _logic.startLevel(widget.level);
  }

  int _lastTargetIndex = 0;
  int _lastComboSeen = 0;

  /// Escalation tier for the current combo count:
  /// 0 = no combo · 1 = combo 2-4 · 2 = combo 5-7 · 3 = combo 8+
  /// Used to scale punch intensity, flash color, and badge styling so the
  /// feedback visibly ramps up rather than looking identical at x2 and x9.
  static int _comboTier(int combo) {
    if (combo >= 8) return 3;
    if (combo >= 5) return 2;
    if (combo >= 2) return 1;
    return 0;
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {});
    final s = _logic.state;
    if (s == null) return;

    if (s.comboCount > 1) _comboCtrl.forward(from: 0);

    // ── Combo milestones (5, 8, 11...) → full-screen punch flash ───────
    // comboCount only ever changes by exactly ±(itself, via reset to 0) or
    // +1 per event, so this fires exactly once per upward crossing — no
    // extra dedup bookkeeping needed.
    if (s.comboCount > _lastComboSeen &&
        s.comboCount >= 5 &&
        (s.comboCount - 5) % 3 == 0) {
      _screenPunchCtrl.forward(from: 0);
    }
    _lastComboSeen = s.comboCount;

    // ── Word complete mid-level → confetti burst ──────────────────────
    // (haptics for this already fire from GameLogic itself; this is just
    // the visual payoff, which needs a BuildContext so it lives here.)
    if (s.targetIndex > _lastTargetIndex && !s.isLevelComplete) {
      _lastTargetIndex = s.targetIndex;
      _confettiCtrl.play();
    }

    if (s.isLevelComplete && !_resultShown) {
      _resultShown = true;
      _celebCtrl.forward(from: 0);
      _confettiCtrl.play();
      Future.delayed(const Duration(milliseconds: 800), _showLevelComplete);
    }
    if (s.isGameOver && !_resultShown) {
      _resultShown = true;
      Future.delayed(const Duration(milliseconds: 500), _showGameOver);
    }
  }

  @override
  void dispose() {
    _logic.removeListener(_onStateChange);
    _logic.dispose();
    _comboCtrl.dispose();
    _heartCtrl.dispose();
    _celebCtrl.dispose();
    _screenPunchCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ─── Save progress ────────────────────────────────────────────────────────
  Future<void> _saveProgress(int stars) async {
    final prefs = await SharedPreferences.getInstance();
    final levelId = widget.level.id;
    final best = prefs.getInt('stars_$levelId') ?? 0;
    if (stars > best) await prefs.setInt('stars_$levelId', stars);
    final unlocked = prefs.getInt('unlocked_level') ?? 1;
    if (levelId >= unlocked && levelId < 20) {
      await prefs.setInt('unlocked_level', levelId + 1);
    }
    final score = _logic.state?.score ?? 0;
    final hiScore = prefs.getInt('high_score') ?? 0;
    if (score > hiScore) await prefs.setInt('high_score', score);
  }

  // ─── Result dialogs ───────────────────────────────────────────────────────
  void _showLevelComplete() async {
    final s = _logic.state!;
    final stars = s.getStars();
    _saveProgress(stars);
    final coinsEarned =
        await CurrencyManager().awardForLevelComplete(stars: stars);
    // Daily Challenge bonus stacks on top of the normal level-complete
    // payout above — claimCompletion() itself is the guard against double
    // claims (returns 0 if today's already been claimed), so this is safe
    // to call every time a daily-challenge run finishes.
    int dailyBonus = 0;
    if (widget.isDailyChallenge) {
      dailyBonus = await DailyChallengeManager().claimCompletion();
    }
    if (!mounted) return;
    // New-user grace: skip interstitials entirely for the first two levels
    // of a fresh install (per AdMob's own guidance: avoid aggressive
    // monetization before a player has had a chance to enjoy the game).
    // AdsManager's own cooldown then keeps it to roughly once per ~2 min
    // for everyone after that — never two in a row, never stacked.
    if (widget.level.id > 2) {
      AdsManager().showInterstitial(
          onDismissed: () =>
              _showCompleteDialog(s, stars, coinsEarned, dailyBonus));
    } else {
      _showCompleteDialog(s, stars, coinsEarned, dailyBonus);
    }
  }

  void _showCompleteDialog(
      GameState s, int stars, int coinsEarned, int dailyBonus) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LevelCompleteDialog(
        score: s.score,
        stars: stars,
        coinsEarned: coinsEarned,
        dailyBonus: dailyBonus,
        isDailyChallenge: widget.isDailyChallenge,
        level: widget.level,
        onNext: () {
          Navigator.pop(context);
          final nextId = widget.level.id + 1;
          if (nextId <= 50) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => GameScreen(level: Level.byId(nextId))),
            );
          } else {
            Navigator.popUntil(context, (r) => r.isFirst);
          }
        },
        onReplay: () {
          Navigator.pop(context);
          setState(() { _resultShown = false; _lastTargetIndex = 0; });
          _logic.startLevel(widget.level);
        },
        onHome: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
    );
  }

  void _showGameOver() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        score: _logic.state?.score ?? 0,
        onContinue: AdsManager().isRewardedReady
            ? () {
                Navigator.pop(context);
                AdsManager().showRewarded(
                  onEarned: (_) {
                    _logic.continueGame();
                    setState(() { _resultShown = false; _lastTargetIndex = 0; });
                  },
                  onFailed: () {
                    setState(() { _resultShown = false; _lastTargetIndex = 0; });
                    _logic.startLevel(widget.level);
                  },
                );
              }
            : null,
        onReplay: () {
          Navigator.pop(context);
          setState(() { _resultShown = false; _lastTargetIndex = 0; });
          _logic.startLevel(widget.level);
        },
        onHome: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
    );
  }

  void _showPauseMenu() {
    _logic.pause();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PauseDialog(
        onResume: () {
          Navigator.pop(context);
          _logic.resume();
        },
        onReplay: () {
          Navigator.pop(context);
          setState(() { _resultShown = false; _lastTargetIndex = 0; });
          _logic.startLevel(widget.level);
        },
        onHome: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
    ).then((_) => _logic.resume());
  }

  void _useHintWithAd() {
    SoundManager().playTap();
    AdsManager().showRewarded(
      onEarned: (_) => _logic.useHint(),
      onFailed: () => _logic.useHint(),
    );
  }

  void _addTimeWithAd() {
    SoundManager().playTap();
    AdsManager().showRewarded(
      onEarned: (_) => _logic.addTime(30),
      onFailed: () {},
    );
  }

  // ── Dual-path boosters: watch an ad, or spend banked coins ─────────────
  // This is the coin sink that closes the loop on the whole currency system
  // — without it, coins earned from levels and the daily streak have
  // nowhere to go, which makes both feel pointless. Ads stay the default,
  // revenue-generating path; coins are the escape valve for players who'd
  // rather cash in banked progress than watch another ad right now.
  void _onHintTap() {
    _showBoosterChoice(
      title: 'Get a Hint',
      icon: Icons.lightbulb_rounded,
      color: const Color(0xFFFFD700),
      coinCost: CurrencyManager.hintCost,
      onWatchAd: _useHintWithAd,
      onSpendCoins: () => _logic.useHint(),
    );
  }

  void _onAddTimeTap() {
    _showBoosterChoice(
      title: 'Add 30 Seconds',
      icon: Icons.timer_rounded,
      color: const Color(0xFF29B6F6),
      coinCost: CurrencyManager.extraTimeCost,
      onWatchAd: _addTimeWithAd,
      onSpendCoins: () => _logic.addTime(30),
    );
  }

  void _showBoosterChoice({
    required String title,
    required IconData icon,
    required Color color,
    required int coinCost,
    required VoidCallback onWatchAd,
    required VoidCallback onSpendCoins,
  }) {
    SoundManager().playTap();
    _logic.pause();
    final coins = CurrencyManager().balance;
    final canAfford = coins >= coinCost;
    final adReady = AdsManager().isRewardedReady;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        decoration: const BoxDecoration(
          color: Color(0xFF1A0A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: adReady
                  ? () {
                      Navigator.pop(sheetCtx);
                      onWatchAd();
                    }
                  : null,
              child: _boosterChoiceRow(
                icon: Icons.play_circle_fill_rounded,
                label: adReady ? 'Watch Ad' : 'Ad not ready',
                sublabel: 'Free',
                color: const Color(0xFF66BB6A),
                enabled: adReady,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: canAfford
                  ? () async {
                      Navigator.pop(sheetCtx);
                      final ok = await CurrencyManager()
                          .spend(coinCost, reason: title);
                      if (ok) onSpendCoins();
                    }
                  : null,
              child: _boosterChoiceRow(
                icon: Icons.monetization_on_rounded,
                label: canAfford ? 'Use Coins' : 'Not enough coins',
                sublabel: '$coinCost coins · you have $coins',
                color: const Color(0xFFFFD700),
                enabled: canAfford,
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => _logic.resume());
  }

  Widget _boosterChoiceRow({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  Text(sublabel,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = _logic.state;
    if (s == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _showPauseMenu();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHUD(s),
                  _buildProgressBar(s),
                  _buildTargetWord(s),
                  _buildShadowZone(s),
                  const SizedBox(height: 6),
                  Expanded(child: _buildBoard(s)),
                  _buildBottomBar(s),
                  const BannerAdWidget(),
                ],
              ),
              // ── Combo-milestone screen punch (fires at x5, x8, x11...) ──
              // A quick full-screen radial flash — color and intensity
              // escalate with combo tier so a x8 run visibly hits harder
              // than a x5 run, not just a bigger number in the corner.
              // Positioned.fill must be the direct Stack child — wrapping
              // it inside IgnorePointer/AnimatedBuilder instead throws
              // "Incorrect use of ParentDataWidget" at runtime, so those
              // go INSIDE it here, not around it.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _screenPunchAnim,
                    builder: (_, __) {
                      final v = _screenPunchAnim.value;
                      if (v <= 0.0) return const SizedBox.shrink();
                      final tier = _comboTier(s.comboCount);
                      final flashColor = tier >= 3
                          ? const Color(0xFFE53935) // red-hot at x8+
                          : const Color(0xFFFFD700); // gold at x5-x7
                      return Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.1,
                            colors: [
                              flashColor.withOpacity(0.0),
                              flashColor.withOpacity(0.0),
                              flashColor.withOpacity(
                                  (tier >= 3 ? 0.30 : 0.18) * v),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // ── Celebration confetti — fires on every word complete and
              // again on full level complete (see _onStateChange). ──
              Align(
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: ConfettiWidget(
                    confettiController: _confettiCtrl,
                    blastDirectionality: BlastDirectionality.explosive,
                    numberOfParticles: 22,
                    maxBlastForce: 18,
                    minBlastForce: 6,
                    gravity: 0.25,
                    emissionFrequency: 0.04,
                    shouldLoop: false,
                    colors: const [
                      Color(0xFFFFD700),
                      Color(0xFF6A11CB),
                      Color(0xFF2575FC),
                      Color(0xFFE53935),
                      Color(0xFF2E7D32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HUD ──────────────────────────────────────────────────────────────────
  Widget _buildHUD(GameState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          // Pause
          GestureDetector(
            onTap: () {
                SoundManager().playTap();
                _showPauseMenu();
              },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.08),
              ),
              child: const Icon(Icons.pause_rounded,
                  color: Colors.white70, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          // Score
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LVL ${widget.level.id}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2)),
                  AnimatedBuilder(
                    animation: _comboScale,
                    builder: (_, __) {
                      // Punch intensity escalates with tier: tier1 keeps
                      // the original 1.5x max untouched; tier2/tier3 punch
                      // progressively harder so a x8 run visibly reads as
                      // bigger than a x2 run, not just a louder number.
                      final tier = _comboTier(s.comboCount);
                      final tierMult = tier >= 3 ? 1.6 : (tier == 2 ? 1.25 : 1.0);
                      final punch = 1.0 + (_comboScale.value - 1.0) * tierMult;
                      return Transform.scale(
                        scale: punch,
                        child: Text('${s.score}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      );
                    },
                  ),
                  if (s.comboCount > 1)
                    Builder(builder: (_) {
                      final tier = _comboTier(s.comboCount);
                      final badgeColors = tier >= 3
                          ? [const Color(0xFFE53935), const Color(0xFF9C27B0)]
                          : tier == 2
                              ? [const Color(0xFFFF7043), const Color(0xFFFFD700)]
                              : [const Color(0xFFFFD700), const Color(0xFFFFD700)];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(colors: [
                            badgeColors[0].withOpacity(0.30),
                            badgeColors[1].withOpacity(0.30),
                          ]),
                          border: tier >= 2
                              ? Border.all(
                                  color: badgeColors[0].withOpacity(0.6),
                                  width: 1)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tier >= 3) ...[
                              const Icon(Icons.local_fire_department_rounded,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 2),
                            ],
                            Text('x${s.comboCount}',
                                style: TextStyle(
                                    color: tier >= 2
                                        ? Colors.white
                                        : const Color(0xFFFFD700),
                                    fontSize: tier >= 3 ? 14 : 13,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      );
                    })
                  else
                    const SizedBox(width: 30),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Lives
          Row(
            children: List.generate(
              s.level.maxLives,
              (i) => Padding(
                padding: const EdgeInsets.only(left: 3),
                child: AnimatedBuilder(
                  animation: _heartCtrl,
                  builder: (_, __) => Icon(
                    Icons.favorite_rounded,
                    size: 22,
                    color: i < s.lives
                        ? const Color(0xFFE53935)
                        : Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Timer
          _TimerWidget(
            seconds: s.timeRemaining,
            total: widget.level.timeLimitSecs,
            onAddTime: _onAddTimeTap,
          ),
        ],
      ),
    );
  }

  // ─── 5-target progress bar ────────────────────────────────────────────────
  Widget _buildProgressBar(GameState s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: List.generate(widget.level.targets.length, (i) {
          final isDone = i < s.targetIndex;
          final isActive = i == s.targetIndex;
          final word = widget.level.targets[i];
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDone
                    ? const Color(0xFF2E7D32).withOpacity(0.7)
                    : isActive
                        ? s.currentColor.withOpacity(0.35)
                        : Colors.white.withOpacity(0.06),
                border: isActive
                    ? Border.all(color: s.currentColor, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  word,
                  style: TextStyle(
                    color: isDone
                        ? Colors.white
                        : isActive
                            ? Colors.white
                            : Colors.white38,
                    fontSize: word.length <= 2 ? 13 : 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Current target word header ───────────────────────────────────────────
  Widget _buildTargetWord(GameState s) {
    final word = s.currentWord;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(word.length, (i) {
          final letter = word[i].toUpperCase();
          final isDone = i < s.letterIndex;
          final isActive = i == s.letterIndex;
          final col = LetterFragments.colorOf(letter);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDone
                  ? col.withOpacity(0.8)
                  : isActive
                      ? col.withOpacity(0.25)
                      : Colors.white.withOpacity(0.05),
              border: isActive
                  ? Border.all(color: col, width: 2)
                  : isDone
                      ? null
                      : Border.all(
                          color: Colors.white.withOpacity(0.15), width: 1),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: isDone
                      ? Colors.white
                      : isActive
                          ? col
                          : Colors.white24,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Shadow zone ──────────────────────────────────────────────────────────
  Widget _buildShadowZone(GameState s) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: s.currentColor.withOpacity(0.30), width: 1),
      ),
      child: Row(
        children: [
          // Shadow letter
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: ShadowPainter(
                letter: s.currentLetter,
                collected: s.letterBuild.collectedPieces,
                letterColor: s.currentColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUILD  "${s.currentLetter}"',
                  style: TextStyle(
                    color: s.currentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                // Piece progress dots
                Row(
                  children: List.generate(
                    s.letterBuild.total,
                    (i) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.letterBuild.collectedPieces.contains(i)
                            ? s.currentColor
                            : Colors.white.withOpacity(0.15),
                        boxShadow: s.letterBuild.collectedPieces.contains(i)
                            ? [
                                BoxShadow(
                                    color: s.currentColor.withOpacity(0.5),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${s.letterBuild.collectedPieces.length} / ${s.letterBuild.total} pieces',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Color legend chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: s.currentColor.withOpacity(0.20),
              border: Border.all(
                  color: s.currentColor.withOpacity(0.50), width: 1),
            ),
            child: Column(
              children: [
                Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: s.currentColor)),
                const SizedBox(height: 4),
                Text('TAP\nTHIS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Board ────────────────────────────────────────────────────────────────
  Widget _buildBoard(GameState s) {
    final board = s.board;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(builder: (context, constraints) {
        final cellSize = constraints.maxWidth / s.level.gridSize;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(board.length, (r) {
            return Row(
              children: List.generate(board[r].length, (c) {
                return _BoardCell(
                  tile: board[r][c],
                  size: cellSize,
                  currentLetter: s.currentLetter,
                  onTap: () {
                    SoundManager().playTap();
                    _logic.onTileTapped(r, c);
                  },
                );
              }),
            );
          }),
        );
      }),
    );
  }

  // ─── Bottom toolbar ───────────────────────────────────────────────────────
  Widget _buildBottomBar(GameState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarBtn(
            icon: Icons.lightbulb_rounded,
            label: 'HINT',
            color: const Color(0xFFFFD700),
            adBadge: true,
            onTap: _onHintTap,
          ),
          _ToolbarBtn(
            icon: Icons.timer_rounded,
            label: '+30s',
            color: const Color(0xFF29B6F6),
            adBadge: true,
            onTap: _onAddTimeTap,
          ),
          _ToolbarBtn(
            icon: Icons.refresh_rounded,
            label: 'REPLAY',
            color: const Color(0xFF66BB6A),
            adBadge: false,
            onTap: () {
              SoundManager().playTap();
              setState(() { _resultShown = false; _lastTargetIndex = 0; });
              _logic.startLevel(widget.level);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Board cell ───────────────────────────────────────────────────────────────
class _BoardCell extends StatefulWidget {
  final CellTile tile;
  final double size;
  final String currentLetter;
  final VoidCallback onTap;

  const _BoardCell({
    required this.tile,
    required this.size,
    required this.currentLetter,
    required this.onTap,
  });

  @override
  State<_BoardCell> createState() => _BoardCellState();
}

class _BoardCellState extends State<_BoardCell> {
  // Purely local, purely visual — doesn't touch GameLogic/CellTile at all.
  // A quick squash-on-press-and-release makes every single tap feel more
  // physical, not just the ones that happen to land on a correct letter.
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    if (tile.isCollected) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withOpacity(0.03),
          ),
        ),
      );
    }

    final isTarget = tile.letter == widget.currentLetter;
    final color = tile.color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.87 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(tile.isShaking ? 1.0 : 0.85),
                  color.withOpacity(tile.isShaking ? 0.6 : 0.60),
                ],
              ),
              border: tile.isPulsing
                  ? Border.all(color: Colors.white, width: 2.5)
                  : isTarget
                      ? Border.all(
                          color: Colors.white.withOpacity(0.35), width: 1.0)
                      : null,
              boxShadow: [
                BoxShadow(
                  color: tile.isShaking
                      ? Colors.white.withOpacity(0.4)
                      : tile.isPulsing
                          ? Colors.white.withOpacity(0.3)
                          : color.withOpacity(0.30),
                  blurRadius: tile.isShaking || tile.isPulsing ? 14 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            transform: tile.isShaking
                ? (Matrix4.identity()
                  ..translate(
                      math.Random().nextDouble() * 4 - 2, 0))
                : Matrix4.identity(),
            child: Center(
              child: CustomPaint(
                size: Size(widget.size * 0.58, widget.size * 0.58),
                painter: PiecePainter(
                  letter: tile.letter,
                  pieceIndex: tile.pieceIndex,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Timer widget ─────────────────────────────────────────────────────────────
class _TimerWidget extends StatelessWidget {
  final int seconds;
  final int total;
  final VoidCallback? onAddTime;

  const _TimerWidget(
      {required this.seconds, required this.total, this.onAddTime});

  @override
  Widget build(BuildContext context) {
    final ratio = (seconds / total).clamp(0.0, 1.0);
    final isLow = seconds <= 15;
    final color = isLow
        ? const Color(0xFFE53935)
        : seconds <= 30
            ? const Color(0xFFFF8F00)
            : const Color(0xFF29B6F6);

    return GestureDetector(
      onTap: onAddTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.40), width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 3,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${seconds}s',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800),
            ),
            if (onAddTime != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.add_circle_outline_rounded,
                  color: color.withOpacity(0.70), size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Toolbar button ────────────────────────────────────────────────────────────
class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool adBadge;
  final VoidCallback? onTap;

  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.adBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: color.withOpacity(0.12),
                border:
                    Border.all(color: color.withOpacity(0.35), width: 1),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ],
              ),
            ),
            if (adBadge)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFFFFD700),
                  ),
                  child: const Text('AD',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Level Complete dialog ────────────────────────────────────────────────────
class _LevelCompleteDialog extends StatelessWidget {
  final int score;
  final int stars;
  final int coinsEarned;
  final int dailyBonus;
  final bool isDailyChallenge;
  final Level level;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const _LevelCompleteDialog({
    required this.score,
    required this.stars,
    required this.coinsEarned,
    this.dailyBonus = 0,
    this.isDailyChallenge = false,
    required this.level,
    required this.onNext,
    required this.onReplay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFF6A11CB).withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                isDailyChallenge ? 'DAILY CHALLENGE COMPLETE!' : 'LEVEL COMPLETE!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 16),
            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.star_rounded,
                    size: 44,
                    color: i < stars
                        ? const Color(0xFFFFD700)
                        : Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('SCORE: $score',
                style: const TextStyle(
                    color: Color(0xFFB388FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      color: Color(0xFFFFD700), size: 18),
                  const SizedBox(width: 6),
                  Text('+$coinsEarned',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            if (dailyBonus > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7043), Color(0xFFE53935)],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('DAILY BONUS +$dailyBonus',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            // Buttons
            // Daily-challenge runs are a bonus replay, not campaign
            // progression — "Next Level" would imply continuing past a
            // level the player may not have actually reached yet, so it's
            // suppressed here in favor of just Replay/Home.
            if (!isDailyChallenge && level.id < 20)
              _dialogBtn('NEXT LEVEL', const Color(0xFFFFD700),
                  Colors.black, onNext),
            if (!isDailyChallenge && level.id < 20)
              const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _dialogBtn(
                      'REPLAY', const Color(0xFF6A11CB), Colors.white, onReplay),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dialogBtn(
                      'HOME', Colors.white.withOpacity(0.1), Colors.white70,
                      onHome),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogBtn(
          String label, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: () {
          SoundManager().playTap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bg,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ),
        ),
      );
}

// ─── Game Over dialog ─────────────────────────────────────────────────────────
class _GameOverDialog extends StatelessWidget {
  final int score;
  final VoidCallback? onContinue;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const _GameOverDialog({
    required this.score,
    this.onContinue,
    required this.onReplay,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0A0A), Color(0xFF1A0533)],
          ),
          border: Border.all(
              color: const Color(0xFFE53935).withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_dissatisfied_rounded,
                color: Color(0xFFE53935), size: 52),
            const SizedBox(height: 10),
            const Text('GAME OVER',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
            const SizedBox(height: 8),
            Text('Score: $score',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.60), fontSize: 16)),
            const SizedBox(height: 22),
            if (onContinue != null) ...[
              _dialogBtn(
                  '▶  CONTINUE  (WATCH AD)', const Color(0xFF6A11CB),
                  Colors.white, onContinue!),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: _dialogBtn('REPLAY', const Color(0xFFFF8F00),
                      Colors.white, onReplay),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dialogBtn(
                      'HOME', Colors.white.withOpacity(0.08), Colors.white70,
                      onHome),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogBtn(
          String label, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: () {
          SoundManager().playTap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bg,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
          ),
        ),
      );
}

// ─── Pause dialog ─────────────────────────────────────────────────────────────
class _PauseDialog extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const _PauseDialog(
      {required this.onResume,
      required this.onReplay,
      required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D1A), Color(0xFF1A0533)],
          ),
          border: Border.all(
              color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PAUSED',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6)),
            const SizedBox(height: 24),
            _dialogBtn('▶  RESUME', const Color(0xFF6A11CB),
                Colors.white, onResume),
            const SizedBox(height: 10),
            _dialogBtn('↺  REPLAY', const Color(0xFFFF8F00),
                Colors.white, onReplay),
            const SizedBox(height: 10),
            _dialogBtn('⌂  HOME', Colors.white.withOpacity(0.08),
                Colors.white70, onHome),
          ],
        ),
      ),
    );
  }

  Widget _dialogBtn(
          String label, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: () {
          SoundManager().playTap();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bg,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ),
        ),
      );
}
