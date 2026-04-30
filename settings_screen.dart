import 'package:flutter/material.dart';
import 'sound_manager.dart';
import 'ads_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70),
                      onPressed: () {
                        SoundManager().playTap();
                        Navigator.pop(context);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'SETTINGS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Sound Effects toggle ──
              _buildSettingTile(
                'Sound Effects',
                SoundManager().soundEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                SoundManager().soundEnabled,
                (value) {
                  setState(() {
                    SoundManager().toggleSound();
                    SoundManager().playTap(); // plays if sound was just turned ON
                  });
                },
              ),

              const SizedBox(height: 16),

              // ── Music toggle ──
              _buildSettingTile(
                'Background Music',
                SoundManager().musicEnabled
                    ? Icons.music_note_rounded
                    : Icons.music_off_rounded,
                SoundManager().musicEnabled,
                (value) {
                  setState(() {
                    SoundManager().toggleMusic();
                  });
                },
              ),

              const SizedBox(height: 32),

              // ── Ad info tile ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFD700).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.play_circle_rounded,
                            color: Color(0xFFFFD700), size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rewarded Ads',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            SizedBox(height: 3),
                            Text(
                                'Watch ads for hints, +30s time, or to continue after game over',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── App info ──
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('ALPHA CRUSH',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white38,
                          letterSpacing: 3)),
                  const SizedBox(height: 4),
                  const Text('v1.1.0',
                      style: TextStyle(fontSize: 12, color: Colors.white24)),
                  const SizedBox(height: 4),
                  const Text('By chAs Tech Group',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white24,
                          letterSpacing: 2)),
                  const SizedBox(height: 32),
                ],
              ),

              // ── Banner ad ──
              const BannerAdWidget(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
      String title, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.white.withOpacity(0.10), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (value
                        ? const Color(0xFF6A11CB)
                        : Colors.white24)
                    .withOpacity(0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: value
                      ? const Color(0xFF9C6AFF)
                      : Colors.white38,
                  size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF9C6AFF),
              activeTrackColor:
                  const Color(0xFF6A11CB).withOpacity(0.40),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white.withOpacity(0.10),
            ),
          ],
        ),
      ),
    );
  }
}
