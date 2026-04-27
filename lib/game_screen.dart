import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_logic.dart';
import 'game_board.dart';
import 'letter_fragments.dart';
import 'models/level.dart';
import 'models/game_state.dart';
import 'ads_manager.dart';
import 'sound_manager.dart';

class GameScreen extends StatefulWidget {
  final int levelId;
  
  const GameScreen({super.key, required this.levelId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameLogic _gameLogic;
  late Level _level;
  Timer? _timer;
  late ConfettiController _confettiController;
  
  @override
  void initState() {
    super.initState();
    _level = Level.getLevel(widget.levelId);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _gameLogic = GameLogic(
      onCombo: () {
        SoundManager().playCombo();
      },
      onBuildComplete: () {
        SoundManager().playBuildComplete();
      },
      onGameOver: () {
        _timer?.cancel();
        SoundManager().stopBGM();
        AdsManager().showInterstitialAd();
        _showGameOverDialog();
      },
      onLevelComplete: () {
        _timer?.cancel();
        _confettiController.play();
        SoundManager().playBuildComplete();
        _saveProgress();
        AdsManager().showInterstitialAd();
        Future.delayed(const Duration(seconds: 1), () {
          _showLevelCompleteDialog();
        });
      },
      onWrongTap: () {
        SoundManager().playWrong();
      },
    );
    
    _gameLogic.startLevel(_level);
    
    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _gameLogic.tickTimer();
    });
    
    SoundManager().playBGM();
    AdsManager().showBannerAd();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final state = _gameLogic.state;
    if (state == null) return;
    
    // Unlock next level
    final unlocked = prefs.getStringList('unlocked_levels') ?? ['1'];
    final nextId = '${widget.levelId + 1}';
    if (!unlocked.contains(nextId) && widget.levelId < 20) {
      unlocked.add(nextId);
      await prefs.setStringList('unlocked_levels', unlocked);
    }
    
    // Save stars
    final stars = state.getStars();
    final starsStr = prefs.getString('level_stars') ?? '';
    final Map<int, int> starsMap = {};
    if (starsStr.isNotEmpty) {
      for (var entry in starsStr.split(',')) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          starsMap[int.parse(parts[0])] = int.parse(parts[1]);
        }
      }
    }
    
    // Only update if new stars are higher
    if ((starsMap[widget.levelId] ?? 0) < stars) {
      starsMap[widget.levelId] = stars;
      final newStarsStr = starsMap.entries.map((e) => '${e.key}:${e.value}').join(',');
      await prefs.setString('level_stars', newStarsStr);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameLogic.disposeState();
    _confettiController.dispose();
    super.dispose();
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sentiment_dissatisfied,
                size: 64,
                color: Color(0xFFFF6B6B),
              ),
              const SizedBox(height: 16),
              const Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              // Rewarded ad option
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE66D).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE66D).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Watch an ad to continue with +3 lives!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        AdsManager().showRewardedAd(
                          onRewarded: () {
                            Navigator.pop(context);
                            _gameLogic.continueWithLives(3);
                            _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                              _gameLogic.tickTimer();
                            });
                          },
                          onFailed: () {
                            Navigator.pop(context);
                            _backToMenu();
                          },
                        );
                      },
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Continue (+3 Lives)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE66D),
                        foregroundColor: const Color(0xFF1A1A2E),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _backToMenu();
                },
                child: const Text(
                  'MAIN MENU',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLevelCompleteDialog() {
    final state = _gameLogic.state;
    if (state == null) return;
    final stars = state.getStars();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LEVEL COMPLETE!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4ECDC4),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300 + (index * 200)),
                    curve: Curves.elasticOut,
                    child: Icon(
                      Icons.star,
                      size: 48,
                      color: index < stars ? const Color(0xFFFFE66D) : Colors.white.withOpacity(0.2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Text(
                'Score: ${state.score}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Time Bonus: ${state.timeRemaining * 5}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              Text(
                'Combo Max: ${state.comboCount}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.levelId < 20)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(levelId: widget.levelId + 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('NEXT LEVEL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _backToMenu();
                },
                child: const Text(
                  'MAIN MENU',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _backToMenu() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showPauseMenu() {
    _gameLogic.pause();
    _timer?.cancel();
    SoundManager().pauseBGM();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 32),
              _buildPauseButton('RESUME', Icons.play_arrow, const Color(0xFF4ECDC4), () {
                Navigator.pop(context);
                _gameLogic.resume();
                SoundManager().resumeBGM();
                _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                  _gameLogic.tickTimer();
                });
              }),
              const SizedBox(height: 12),
              _buildPauseButton('RESTART', Icons.replay, const Color(0xFFFFE66D), () {
                Navigator.pop(context);
                _gameLogic.restart();
                SoundManager().resumeBGM();
                _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                  _gameLogic.tickTimer();
                });
              }),
              const SizedBox(height: 12),
              _buildPauseButton('QUIT', Icons.exit_to_app, const Color(0xFFFF6B6B), () {
                Navigator.pop(context);
                _backToMenu();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showPauseMenu();
        return false;
      },
      child: Scaffold(
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
            child: AnimatedBuilder(
              animation: _gameLogic,
              builder: (context, child) {
                final state = _gameLogic.state;
                if (state == null) return const Center(child: CircularProgressIndicator());

                return Column(
                  children: [
                    // Top HUD
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          // Pause button
                          GestureDetector(
                            onTap: _showPauseMenu,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.pause,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Level info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LEVEL ${_level.id}${_level.isWord ? '' : ''}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Target: ${_level.isWord ? _level.target : _level.target}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Timer
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: state.timeRemaining <= 10
                                  ? const Color(0xFFFF6B6B).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: state.timeRemaining <= 10
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  color: state.timeRemaining <= 10
                                      ? const Color(0xFFFF6B6B)
                                      : Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${state.timeRemaining}s',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: state.timeRemaining <= 10
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Score and Lives
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Score
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${state.score}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          
                          // Combo
                          if (state.comboCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE66D).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFFE66D).withOpacity(0.5)),
                              ),
                              child: Text(
                                'COMBO x${state.comboCount}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFE66D),
                                ),
                              ),
                            ),
                          
                          // Lives
                          Row(
                            children: List.generate(state.level.maxLives, (index) {
                              return Icon(
                                Icons.favorite,
                                size: 24,
                                color: index < state.lives
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.white.withOpacity(0.2),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Target Display with sequence progress
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'BUILD: ${state.currentTarget}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSequenceIndicator(state),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Game Board
                    Expanded(
                      child: GameBoard(
                        state: state,
                        onTap: (row, col) {
                          SoundManager().playTap();
                          _gameLogic.onFragmentTap(row, col);
                        },
                      ),
                    ),
                    
                    // Confetti
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        particleDrag: 0.05,
                        emissionFrequency: 0.05,
                        numberOfParticles: 20,
                        gravity: 0.2,
                        colors: const [
                          Color(0xFFFF6B6B),
                          Color(0xFF4ECDC4),
                          Color(0xFFFFE66D),
                          Color(0xFF96CEB4),
                          Color(0xFF45B7D1),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: _buildBannerAd(),
      ),
    );
  }

  Widget _buildSequenceIndicator(GameState state) {
    final targetSequence = LetterFragments.getFragments(state.currentTarget);
    final selectedCount = state.selectedFragments.length;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: targetSequence.asMap().entries.map((entry) {
        final isCompleted = entry.key < selectedCount;
        final isCurrent = entry.key == selectedCount;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: isCompleted
                ? const LinearGradient(
                    colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                  )
                : isCurrent
                    ? const LinearGradient(
                        colors: [Color(0xFFFFE66D), Color(0xFFFFD93D)],
                      )
                    : null,
            color: isCompleted || isCurrent ? null : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFFFFE66D)
                  : isCompleted
                      ? const Color(0xFF4ECDC4)
                      : Colors.white.withOpacity(0.2),
              width: isCurrent ? 2 : 1,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFE66D).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isCompleted || isCurrent ? Colors.white : Colors.white.withOpacity(0.4),
              ),
            ),
          ),
        );
      }).toList(),
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
