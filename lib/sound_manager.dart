import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _bgmPlayer  = AudioPlayer();
  final AudioPlayer _sfxPlayer  = AudioPlayer();
  final AudioPlayer _sfxPlayer2 = AudioPlayer();

  bool _soundEnabled = true;
  bool _musicEnabled = true;

  final double _sfxVolume   = 0.80;
  final double _musicVolume = 0.35;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  // ─── Initialize once in main.dart ─────────────────────────────
  Future<void> initialize() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_musicVolume);
    await _sfxPlayer.setVolume(_sfxVolume);
    await _sfxPlayer2.setVolume(_sfxVolume);
  }

  // ─── BGM ──────────────────────────────────────────────────────
  // Called from splash after 2.8s delay — audio engine is ready by then
  Future<void> startBGM() async {
    if (!_musicEnabled) return;
    try {
      // Small extra delay to ensure engine is fully warmed up
      await Future.delayed(const Duration(milliseconds: 500));
      await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
    } catch (_) {}
  }

  Future<void> pauseBGM() async {
    try {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.pause();
      }
    } catch (_) {}
  }

  Future<void> resumeBGM() async {
    if (!_musicEnabled) return;
    try {
      final state = _bgmPlayer.state;
      if (state == PlayerState.paused) {
        await _bgmPlayer.resume();
      } else if (state != PlayerState.playing) {
        // Not paused and not playing — restart from scratch
        await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
      }
    } catch (_) {}
  }

  Future<void> stopBGM() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  // ─── SFX ──────────────────────────────────────────────────────
  Future<void> playTap() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/tap.mp3'));
    } catch (_) {}
  }

  Future<void> playCorrect() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer2.stop();
      await _sfxPlayer2.play(AssetSource('sounds/correct.mp3'));
    } catch (_) {}
  }

  Future<void> playWrong() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/wrong.mp3'));
    } catch (_) {}
  }

  Future<void> playBuildComplete() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer2.stop();
      await _sfxPlayer2.play(AssetSource('sounds/build_complete.mp3'));
    } catch (_) {}
  }

  Future<void> playCombo() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/combo.mp3'));
    } catch (_) {}
  }

  // ─── Toggles ──────────────────────────────────────────────────
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
  }

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    if (_musicEnabled) {
      startBGM();
    } else {
      stopBGM();
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────
  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    _sfxPlayer2.dispose();
  }
}
