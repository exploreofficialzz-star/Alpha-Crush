import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_manager.dart';

/// 7-day login streak — the primary "reason to open the app today" hook.
///
/// Design choices (grounded in current retention research, not guesswork):
/// - Escalating reward curve where Day 7 (200 coins) pays out MORE than the
///   sum of Days 1-6 (150 coins combined). A flat daily bonus doesn't create
///   urgency; a back-loaded curve does — it's why this pattern shows up
///   across Clash Royale, Hearthstone, and most top-grossing live-ops games.
/// - ONE missed day is forgiven: the streak holds and simply advances on
///   the next visit, instead of resetting to Day 1. Two or more missed days
///   in a row resets it. Hard "miss-one-day-lose-everything" resets read as
///   punishing rather than motivating and are a known churn driver — the
///   goal is "missing a day should feel costly, not catastrophic."
/// - Cycles every 7 days indefinitely (Day 8 = Day 1's reward, etc.) rather
///   than scaling forever, which avoids the currency-inflation trap where
///   a coin earned on Day 90 is worth nothing next to a coin earned on
///   Day 1. Milestone bonuses (Day 30, Day 100) are a good Phase 2/3
///   addition once there's a shop for that currency to mean something
///   beyond hoarding.
class DailyRewardManager extends ChangeNotifier {
  static final DailyRewardManager _instance = DailyRewardManager._internal();
  factory DailyRewardManager() => _instance;
  DailyRewardManager._internal();

  static const String _streakKey = 'daily_streak_day';
  static const String _lastClaimKey = 'daily_streak_last_claim';

  /// Index 0 = Day 1 ... Index 6 = Day 7. Day 7 (200) > sum(Days 1-6) (150).
  static const List<int> rewardTable = [10, 15, 20, 25, 35, 45, 200];

  int _streakDay = 0; // 0 = never claimed
  DateTime? _lastClaim;
  bool _loaded = false;

  int get streakDay => _streakDay;
  bool get isLoaded => _loaded;

  int rewardFor(int day) => rewardTable[(day - 1) % 7];

  /// True if today's reward is still unclaimed.
  bool get canClaimToday {
    final last = _lastClaim;
    if (last == null) return true;
    return !_isSameDay(last, DateTime.now());
  }

  /// The streak day that WOULD be recorded if claimed right now — used to
  /// preview the reward in the UI before the player taps claim.
  int get nextStreakDay {
    final last = _lastClaim;
    if (last == null) return 1;
    final daysSince = _daysBetween(last, DateTime.now());
    if (daysSince <= 0) return _streakDay; // already claimed today
    if (daysSince <= 2) return _streakDay + 1; // consecutive, or 1 day forgiven
    return 1; // 2+ days missed → reset
  }

  Future<void> initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _streakDay = prefs.getInt(_streakKey) ?? 0;
    final lastStr = prefs.getString(_lastClaimKey);
    _lastClaim = lastStr != null ? DateTime.tryParse(lastStr) : null;
    _loaded = true;
    notifyListeners();
  }

  /// Claims today's reward if available. Returns the coins awarded, or
  /// null if today was already claimed.
  Future<int?> claimToday() async {
    if (!canClaimToday) return null;
    final day = nextStreakDay;
    final reward = rewardFor(day);

    _streakDay = day;
    _lastClaim = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_streakKey, _streakDay);
    await prefs.setString(_lastClaimKey, _lastClaim!.toIso8601String());

    await CurrencyManager().earn(reward, reason: 'daily_streak_day_$day');
    notifyListeners();
    return reward;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }
}
