import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final _sfxPool = <AudioPlayer>[];
  final _musicPlayer = AudioPlayer();
  final double _sfxVolume = 0.7;
  final double _musicVolume = 0.4;
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _musicEnabled = prefs.getBool('music_enabled') ?? true;
    // Pre-warm pool
    for (int i = 0; i < 4; i++) {
      _sfxPool.add(AudioPlayer());
    }
  }

  Future<void> _playSfx(String asset) async {
    if (!_soundEnabled) return;
    try {
      final p = _sfxPool.firstWhere(
        (p) => p.state != PlayerState.playing,
        orElse: () {
          final np = AudioPlayer();
          _sfxPool.add(np);
          return np;
        },
      );
      await p.setVolume(_sfxVolume);
      await p.play(AssetSource(asset));
    } catch (_) {}
  }

  void playCorrect() => _playSfx('sounds/correct.mp3');
  void playWrong() => _playSfx('sounds/wrong.mp3');
  void playCombo() => _playSfx('sounds/combo.mp3');
  void playLetterComplete() => _playSfx('sounds/letter_complete.mp3');
  void playLevelComplete() => _playSfx('sounds/level_complete.mp3');
  void playGameOver() => _playSfx('sounds/game_over.mp3');

  Future<void> playMusic() async {
    if (!_musicEnabled) return;
    try {
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(AssetSource('sounds/bg_music.mp3'));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
  }

  Future<void> toggleMusic() async {
    _musicEnabled = !_musicEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', _musicEnabled);
    if (_musicEnabled) {
      playMusic();
    } else {
      stopMusic();
    }
  }

  void dispose() {
    for (final p in _sfxPool) {
      p.dispose();
    }
    _musicPlayer.dispose();
  }
}
