import 'package:flutter/material.dart';
import 'sound_manager.dart';

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
                        'SETTINGS',
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
              
              const SizedBox(height: 32),
              
              // Settings Options
              _buildSettingTile(
                'Sound Effects',
                SoundManager().soundEnabled ? Icons.volume_up : Icons.volume_off,
                SoundManager().soundEnabled,
                (value) {
                  setState(() {
                    SoundManager().toggleSound();
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildSettingTile(
                'Music',
                SoundManager().musicEnabled ? Icons.music_note : Icons.music_off,
                SoundManager().musicEnabled,
                (value) {
                  setState(() {
                    SoundManager().toggleMusic();
                  });
                },
              ),
              
              const Spacer(),
              
              // Credits
              const Text(
                'ALPHA CRUSH',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'By chAs',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white24,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (value ? const Color(0xFF4ECDC4) : Colors.white24).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: value ? const Color(0xFF4ECDC4) : Colors.white54,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF4ECDC4),
              activeTrackColor: const Color(0xFF4ECDC4).withOpacity(0.3),
              inactiveThumbColor: Colors.white54,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
            ),
          ],
        ),
      ),
    );
  }
}
