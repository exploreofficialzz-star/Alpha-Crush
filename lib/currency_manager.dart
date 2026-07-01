import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alpha Crush's single soft currency: Crush Coins.
///
/// Deliberately ONE currency, not two. Stars/trophies stay as pure skill
/// progression (level-unlock gating + star rating); coins are the only
/// spendable balance. Top-grossing casual puzzle games (Candy Crush,
/// Gardenscapes, Royal Match) all run on a single soft currency — splitting
/// rewards across multiple currencies mainly adds bookkeeping and makes the
/// economy harder to balance without adding real player value.
///
/// Sources (live now): level completion, daily login streak.
/// Sources (Phase 2): daily challenge, optional bonus on rewarded ads.
/// Sinks (live now): in-game hint / +30s choice sheet (spend-or-watch-ad).
/// Sinks (Phase 2 — dedicated shop screen): time packs, skip tokens,
/// cosmetic letter skins.
class CurrencyManager extends ChangeNotifier {
  static final CurrencyManager _instance = CurrencyManager._internal();
  factory CurrencyManager() => _instance;
  CurrencyManager._internal();

  static const String _prefsKey = 'crush_coins';

  /// Coin sink prices. Centralized here (not hardcoded at call sites) so
  /// the in-game hint/+30s choice sheet and any future shop screen always
  /// agree on cost — one source of truth, no drift.
  /// Priced against level-complete payouts (4/10/20/35 by star rating):
  /// a hint costs about one no-star clear's worth of coins, so a player who
  /// is genuinely stuck can always afford a way forward without paying —
  /// the ad path exists for players who'd rather not spend banked coins,
  /// not because the coin path is deliberately priced out of reach.
  static const int hintCost = 15;
  static const int extraTimeCost = 20;

  int _balance = 0;
  bool _loaded = false;

  int get balance => _balance;
  bool get isLoaded => _loaded;

  Future<void> initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _balance = prefs.getInt(_prefsKey) ?? 0;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, _balance);
  }

  /// Adds coins to the balance. [reason] isn't used yet but keeps every
  /// call site self-documenting and gives us a single hook to wire up
  /// analytics logging later without touching every caller.
  Future<int> earn(int amount, {String? reason}) async {
    if (amount <= 0) return _balance;
    _balance += amount;
    await _persist();
    notifyListeners();
    return _balance;
  }

  bool canAfford(int amount) => _balance >= amount;

  /// Attempts to spend coins. Returns false (and changes nothing) if the
  /// balance is insufficient — callers should check this before unlocking
  /// whatever the spend was for.
  Future<bool> spend(int amount, {String? reason}) async {
    if (amount <= 0) return true;
    if (_balance < amount) return false;
    _balance -= amount;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Coin payout for finishing a level, scaled by stars earned.
  /// 0★: 4 · 1★: 10 · 2★: 20 · 3★: 35
  /// A perfect run pays ~3.5x a no-star clear (not a flat multiplier) so
  /// early, scrappy clears still feel worth something, while chasing 3
  /// stars stays the clearly-better payout — without flooding the economy
  /// once a player is 3-starring most levels.
  Future<int> awardForLevelComplete({required int stars}) async {
    int payout;
    if (stars >= 3) {
      payout = 35;
    } else if (stars == 2) {
      payout = 20;
    } else if (stars == 1) {
      payout = 10;
    } else {
      payout = 4;
    }
    await earn(payout, reason: 'level_complete');
    return payout;
  }
}
