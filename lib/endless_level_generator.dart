import 'package:shared_preferences/shared_preferences.dart';
import 'models/level.dart';
import 'endless_word_bank.dart';

/// Generates procedural levels for Endless Mode once the 50-level campaign
/// is exhausted. The board/tile-rendering engine in GameLogic is already
/// fully letter-agnostic (works from any word list + gridSize, and every
/// A-Z letter already has its stroke-fragment art defined) — so this class
/// only has to solve the content side: which words, in what order, at what
/// difficulty.
///
/// Endless "levels" are never added to Level.all — they're built fresh at
/// runtime and given a high id offset (10000+) so they can never collide
/// with a real campaign level's saved star-progress data.
class EndlessLevelGenerator {
  static const int idOffset = 10000;
  static const String _indexKey = 'endless_index';
  static const String _deckPrefix = 'endless_deck_'; // + length

  /// Same formula the campaign's own 50 levels follow — reverse-engineered
  /// from the actual data rather than guessed: gridSize and star
  /// thresholds are a pure function of word length in the campaign (every
  /// themed stage at a given length reuses the exact same numbers as the
  /// length-progression stage at that length), so reusing it here means
  /// Endless levels feel like a continuation, not a different game.
  static int gridSizeFor(int wordLength) => 5 + ((wordLength - 1) ~/ 3);

  /// Public because DailyChallengeManager needs the exact same formula
  /// for its post-campaign deterministic pick — one source of truth for
  /// the difficulty curve, not two copies that could drift apart.
  static int threshold1For(int wordLength) => 35 + 90 * wordLength;

  /// Which length tier plays at endless-run position [index] (0-based).
  /// Cycles through the word bank's length tiers in a repeating sawtooth
  /// rather than climbing forever — see EndlessWordBank.lengthCycle for
  /// why that's the right shape for something meant to never truly end.
  static int lengthForIndex(int index) {
    final cycle = EndlessWordBank.lengthCycle;
    return cycle[index % cycle.length];
  }

  /// How many endless levels the player has cleared so far (persisted).
  /// This is completely separate from the campaign's unlocked_level/
  /// stars_$id keys — its own namespace, zero collision risk.
  static Future<int> getCurrentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_indexKey) ?? 0;
  }

  static Future<void> _setCurrentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_indexKey, index);
  }

  /// Call once when an endless level is completed, to advance the run.
  static Future<int> advanceIndex() async {
    final next = await getCurrentIndex() + 1;
    await _setCurrentIndex(next);
    return next;
  }

  /// Resets the endless run back to the start. Not currently wired to any
  /// UI button — available for a future "restart my endless run" option
  /// without needing another round of plumbing later.
  static Future<void> resetRun() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_indexKey, 0);
    for (final length in EndlessWordBank.byLength.keys) {
      await prefs.remove('$_deckPrefix$length');
    }
  }

  /// Draws 3 words from a given length tier using a shuffled "deck": once
  /// dealt, a word won't repeat until every other word at that length has
  /// also been dealt, then the deck reshuffles and continues. This avoids
  /// the visible back-to-back repeats a pure-random pick would risk, even
  /// though with 14-24 words per tier a true repeat is already many plays
  /// away — combined with the board's own fresh distractor-tile shuffle
  /// every single time, even a repeated word still feels like a new puzzle.
  static Future<List<String>> _drawWords(int length) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_deckPrefix$length';
    List<String> deck = prefs.getStringList(key) ?? [];

    final pool = List<String>.from(EndlessWordBank.byLength[length]!);
    final drawn = <String>[];

    while (drawn.length < 3) {
      if (deck.isEmpty) {
        deck = List<String>.from(pool)..shuffle();
      }
      // Guard against a pool smaller than 3 (shouldn't happen given the
      // curated bank's minimums, but never risk an infinite loop over it).
      if (deck.isEmpty) break;
      drawn.add(deck.removeLast());
    }

    await prefs.setStringList(key, deck);
    return drawn;
  }

  /// Builds the Level for endless-run position [index]. This is the only
  /// method the rest of the app needs to call.
  static Future<Level> generateLevel(int index) async {
    final length = lengthForIndex(index);
    final words = await _drawWords(length);
    final t1 = threshold1For(length);

    return Level(
      id: idOffset + index,
      stageNumber: 0, // endless levels don't belong to a campaign stage
      targets: words,
      gridSize: gridSizeFor(length),
      starThreshold1: t1,
      starThreshold2: t1 * 2,
      starThreshold3: t1 * 3,
      // timeLimitSecs and maxLives intentionally left at Level's own
      // defaults (30s, 3 lives) — the campaign never overrides these
      // either, at any word length, so there's no formula to reproduce.
    );
  }

  /// Convenience for callers that just want "today's next endless level"
  /// without manually tracking the index themselves (home screen card,
  /// daily challenge extension).
  static Future<Level> generateNext() async {
    final index = await getCurrentIndex();
    return generateLevel(index);
  }
}
