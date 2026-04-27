import 'level.dart';

class GameState {
  final Level level;
  int score;
  int lives;
  int timeRemaining;
  int currentLetterIndex;
  int comboCount;
  int totalMatches;
  bool isPlaying;
  bool isPaused;
  bool isGameOver;
  bool isLevelComplete;
  List<List<CellFragment>> board;
  List<CellFragment> selectedFragments;
  String currentTarget;

  GameState({
    required this.level,
    this.score = 0,
    this.lives = 3,
    this.timeRemaining = 60,
    this.currentLetterIndex = 0,
    this.comboCount = 0,
    this.totalMatches = 0,
    this.isPlaying = false,
    this.isPaused = false,
    this.isGameOver = false,
    this.isLevelComplete = false,
    required this.board,
    this.selectedFragments = const [],
    required this.currentTarget,
  });

  GameState copyWith({
    int? score,
    int? lives,
    int? timeRemaining,
    int? currentLetterIndex,
    int? comboCount,
    int? totalMatches,
    bool? isPlaying,
    bool? isPaused,
    bool? isGameOver,
    bool? isLevelComplete,
    List<List<CellFragment>>? board,
    List<CellFragment>? selectedFragments,
    String? currentTarget,
  }) {
    return GameState(
      level: level,
      score: score ?? this.score,
      lives: lives ?? this.lives,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      currentLetterIndex: currentLetterIndex ?? this.currentLetterIndex,
      comboCount: comboCount ?? this.comboCount,
      totalMatches: totalMatches ?? this.totalMatches,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isGameOver: isGameOver ?? this.isGameOver,
      isLevelComplete: isLevelComplete ?? this.isLevelComplete,
      board: board ?? this.board.map((row) => List<CellFragment>.from(row)).toList(),
      selectedFragments: selectedFragments ?? List<CellFragment>.from(this.selectedFragments),
      currentTarget: currentTarget ?? this.currentTarget,
    );
  }

  int getStars() {
    if (score >= level.starThreshold3) return 3;
    if (score >= level.starThreshold2) return 2;
    if (score >= level.starThreshold1) return 1;
    return 0;
  }
}

class CellFragment {
  final String id;
  final String symbol;
  final String? requiredFor;
  final int? sequenceIndex;
  bool isSelected;
  bool isMatched;
  bool isAnimating;
  double scale;

  CellFragment({
    required this.id,
    required this.symbol,
    this.requiredFor,
    this.sequenceIndex,
    this.isSelected = false,
    this.isMatched = false,
    this.isAnimating = false,
    this.scale = 1.0,
  });

  CellFragment copyWith({
    String? id,
    String? symbol,
    String? requiredFor,
    int? sequenceIndex,
    bool? isSelected,
    bool? isMatched,
    bool? isAnimating,
    double? scale,
  }) {
    return CellFragment(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      requiredFor: requiredFor ?? this.requiredFor,
      sequenceIndex: sequenceIndex ?? this.sequenceIndex,
      isSelected: isSelected ?? this.isSelected,
      isMatched: isMatched ?? this.isMatched,
      isAnimating: isAnimating ?? this.isAnimating,
      scale: scale ?? this.scale,
    );
  }
}
