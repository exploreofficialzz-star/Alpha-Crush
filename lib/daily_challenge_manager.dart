import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/level.dart';
import 'currency_manager.dart';

/// Today's Daily Challenge — a bonus replay of one level the player has
/// already unlocked, picked deterministically from the calendar date so
/// every device lands on the same pick for that day without needing a
/// backend. Reuses the existing 50-level pool rather than a separate word
/// list, which was the faster path to ship and means difficulty is
/// already tuned — no new content to balance.
///
/// Deliberately scoped to [1, unlockedLevel]: picking from levels the
/// player hasn't reached yet would occasionally hand a brand-new player
/// a 10-letter compound word as their "daily challenge," which reads as
/// unfair rather than special. Scoping to familiar territory keeps the
/// bonus feeling like a treat, not a wall.
class DailyChallengeManager extends ChangeNotifier {
  static final DailyChallengeManager _instance =
      DailyChallengeManager._internal();
  factory DailyChallengeManager() => _instance;
  DailyChallengeManager._internal();

  static const String _lastCompletedKey = 'daily_challenge_last_completed';

  /// Flat bonus, well above what a single normal level pays (4-35 by
  /// star rating) — the size gap is what makes this read as a special,
  /// worth-coming-back-for reward rather than just another level.
  static const int bonusCoins = 50;

  DateTime? _lastCompleted;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastCompletedKey);
    _lastCompleted = str != null ? DateTime.tryParse(str) : null;
    _loaded = true;
    notifyListeners();
  }

  /// Deterministic "today's level" — same calendar day always yields the
  /// same pick everywhere, no server round-trip needed.
  Level todaysLevel({required int unlockedLevel}) {
    final maxId = unlockedLevel.clamp(1, 50);
    final now = DateTime.now();
    final seed = now.year * 372 + now.month * 31 + now.day;
    final index = seed % maxId; // 0 .. maxId-1
    return Level.byId(index + 1);
  }

  bool get isCompletedToday {
    final last = _lastCompleted;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  /// Awards the daily bonus and marks today as claimed. Returns 0 (grants
  /// nothing) if already claimed today — the hard stop that keeps this
  /// from becoming an infinite coin-farming loop via repeat replays.
  Future<int> claimCompletion() async {
    if (isCompletedToday) return 0;
    _lastCompleted = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastCompletedKey, _lastCompleted!.toIso8601String());
    await CurrencyManager().earn(bonusCoins, reason: 'daily_challenge');
    notifyListeners();
    return bonusCoins;
  }
}
