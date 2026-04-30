import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'ads_manager.dart';
import 'sound_manager.dart';

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
    _loadProgress();
    // BGM already started from splash — no need to restart here
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
