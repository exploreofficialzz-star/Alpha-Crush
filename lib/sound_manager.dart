import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer2 = AudioPlayer();

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _sfxVolume = 0.7;
  double _musicVolume = 0.4;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  Future<void> initialize() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_musicVolume);
    await _sfxPlayer.setVolume(_sfxVolume);
    await _sfxPlayer2.setVolume(_sfxVolume);
  }

  Future<void> playTap() async {
    if (!_soundEnabled) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sounds/tap.mp3'));
  }

  Future<void> playCorrect() async {
    if (!_soundEnabled) return;
    await _sfxPlayer2.stop();
    await _sfxPlayer2.play(AssetSource('sounds/correct.mp3'));
  }

  Future<void> playWrong() async {
    if (!_soundEnabled) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sounds/wrong.mp3'));
  }

  Future<void> playBuildComplete() async {
    if (!_soundEnabled) return;
    await _sfxPlayer2.stop();
    await _sfxPlayer2.play(AssetSource('sounds/build_complete.mp3'));
  }

  Future<void> playCombo() async {
    if (!_soundEnabled) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sounds/combo.mp3'));
  }

  Future<void> playBGM() async {
    if (!_musicEnabled) return;
    await _bgmPlayer.stop();
    await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
  }

  Future<void> stopBGM() async {
    await _bgmPlayer.stop();
  }

  Future<void> pauseBGM() async {
    await _bgmPlayer.pause();
  }

  Future<void> resumeBGM() async {
    if (_musicEnabled) {
      await _bgmPlayer.resume();
    }
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
  }

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    if (_musicEnabled) {
      playBGM();
    } else {
      stopBGM();
    }
  }

  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    _sfxPlayer2.dispose();
  }
}
