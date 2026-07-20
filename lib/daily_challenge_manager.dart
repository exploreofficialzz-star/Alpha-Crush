import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/level.dart';
import 'currency_manager.dart';
import 'endless_word_bank.dart';
import 'endless_level_generator.dart';

/// Today's Daily Challenge — a bonus replay of one level, picked
/// deterministically from the calendar date so every device lands on the
/// same pick for that day without needing a backend.
///
/// Two sources, depending on progress:
/// - Before the 50-level campaign is cleared: reuses that pool, scoped to
///   [1, unlockedLevel] — picking from levels the player hasn't reached
///   yet would occasionally hand a brand-new player a 10-letter compound
///   word as their "daily challenge," which reads as unfair rather than
///   special.
/// - After the campaign is cleared: draws from the same curated word bank
///   Endless Mode uses, still fully date-deterministic (a seeded shuffle,
///   not the player's own progressing endless deck) so the "same for
///   everyone today" property holds either way — finishing the campaign
///   changes where the words come from, not what Daily Challenge means.
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

  static int get _dateSeed {
    final now = DateTime.now();
    return now.year * 372 + now.month * 31 + now.day;
  }

  /// Deterministic "today's level." [campaignCompleted] should reflect
  /// whether level 50 has actually been CLEARED (e.g. a saved star value
  /// for it exists) — not just whether it's unlocked, since those aren't
  /// the same moment.
  Level todaysLevel({
    required int unlockedLevel,
    bool campaignCompleted = false,
  }) {
    final seed = _dateSeed;
    if (!campaignCompleted) {
      final maxId = unlockedLevel.clamp(1, 50);
      final index = seed % maxId; // 0 .. maxId-1
      return Level.byId(index + 1);
    }

    // Post-campaign: deterministic pick from the endless word bank. Uses
    // a seeded Random rather than the player's own shuffled endless deck,
    // so the result is reproducible from the date alone, on any device —
    // the same guarantee the pre-campaign path has.
    const cycle = EndlessWordBank.lengthCycle;
    final length = cycle[seed % cycle.length];
    final pool = List<String>.from(EndlessWordBank.byLength[length]!)
      ..shuffle(Random(seed));
    final words = pool.take(3).toList();
    final t1 = EndlessLevelGenerator.threshold1For(length);
    return Level(
      id: EndlessLevelGenerator.idOffset - 1, // reserved id, never persisted
      stageNumber: 0,
      targets: words,
      gridSize: EndlessLevelGenerator.gridSizeFor(length),
      starThreshold1: t1,
      starThreshold2: t1 * 2,
      starThreshold3: t1 * 3,
    );
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
