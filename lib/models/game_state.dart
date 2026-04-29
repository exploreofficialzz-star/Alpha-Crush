import 'package:flutter/material.dart';
import 'level.dart';
import '../letter_fragments.dart';

// ─── Board tile ──────────────────────────────────────────────────────────────
class CellTile {
  final String id; // "row-col"
  final String letter; // which letter this piece belongs to
  final int pieceIndex; // which piece of that letter
  final Color color; // letter's candy color
  bool isCollected; // tapped correctly and removed
  bool isShaking; // wrong-tap flash
  bool isPulsing; // hint pulse

  CellTile({
    required this.id,
    required this.letter,
    required this.pieceIndex,
    bool? isCollected,
    bool? isShaking,
    bool? isPulsing,
  })  : color = LetterFragments.colorOf(letter),
        isCollected = isCollected ?? false,
        isShaking = isShaking ?? false,
        isPulsing = isPulsing ?? false;

  CellTile copyWith({
    bool? isCollected,
    bool? isShaking,
    bool? isPulsing,
  }) =>
      CellTile(
        id: id,
        letter: letter,
        pieceIndex: pieceIndex,
        isCollected: isCollected ?? this.isCollected,
        isShaking: isShaking ?? this.isShaking,
        isPulsing: isPulsing ?? this.isPulsing,
      );
}

// ─── Per-letter build progress ────────────────────────────────────────────────
class LetterBuild {
  final String letter;
  final Set<int> collectedPieces; // which piece indices have been tapped

  LetterBuild({required this.letter, Set<int>? collected})
      : collectedPieces = collected ?? {};

  int get total => LetterFragments.pieceCount(letter);
  bool get isComplete => collectedPieces.length >= total;

  LetterBuild withPiece(int idx) => LetterBuild(
        letter: letter,
        collected: {...collectedPieces, idx},
      );
}

// ─── GameState ────────────────────────────────────────────────────────────────
class GameState {
  final Level level;
  int score;
  int lives;
  int timeRemaining;
  bool isPlaying;
  bool isPaused;
  bool isGameOver;
  bool isLevelComplete;
  int comboCount;

  // 5-challenge progress
  int targetIndex; // 0-4: which of the 5 targets we're on
  // For multi-letter words: which letter within the current word
  int letterIndex;

  // Build progress for the current letter
  LetterBuild letterBuild;

  // Board
  List<List<CellTile>> board;

  GameState({
    required this.level,
    this.score = 0,
    this.lives = 3,
    required this.timeRemaining,
    this.isPlaying = false,
    this.isPaused = false,
    this.isGameOver = false,
    this.isLevelComplete = false,
    this.comboCount = 0,
    this.targetIndex = 0,
    this.letterIndex = 0,
    required this.letterBuild,
    required this.board,
  });

  // Current word being built (e.g. "CAT")
  String get currentWord => level.targets[targetIndex];

  // Current letter being built within the word
  String get currentLetter =>
      currentWord[letterIndex].toUpperCase();

  Color get currentColor => LetterFragments.colorOf(currentLetter);

  // True once all 5 targets done
  bool get allTargetsDone => targetIndex >= level.targets.length;

  int getStars() {
    if (score >= level.starThreshold3) return 3;
    if (score >= level.starThreshold2) return 2;
    if (score >= level.starThreshold1) return 1;
    return 0;
  }

  GameState copyWith({
    int? score,
    int? lives,
    int? timeRemaining,
    bool? isPlaying,
    bool? isPaused,
    bool? isGameOver,
    bool? isLevelComplete,
    int? comboCount,
    int? targetIndex,
    int? letterIndex,
    LetterBuild? letterBuild,
    List<List<CellTile>>? board,
  }) {
    return GameState(
      level: level,
      score: score ?? this.score,
      lives: lives ?? this.lives,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isGameOver: isGameOver ?? this.isGameOver,
      isLevelComplete: isLevelComplete ?? this.isLevelComplete,
      comboCount: comboCount ?? this.comboCount,
      targetIndex: targetIndex ?? this.targetIndex,
      letterIndex: letterIndex ?? this.letterIndex,
      letterBuild: letterBuild ?? this.letterBuild,
      board: board ??
          this.board.map((r) => List<CellTile>.from(r)).toList(),
    );
  }
}
