import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'models/game_state.dart';
import 'models/level.dart';
import 'letter_fragments.dart';
import 'sound_manager.dart';

class GameLogic extends ChangeNotifier {
  GameState? _state;
  Timer? _timer;
  final _rng = Random();
  int _failCount = 0;
  int _completeCount = 0;

  GameState? get state => _state;
  int get failCount => _failCount;
  int get completeCount => _completeCount;

  // ─── Init ──────────────────────────────────────────────────────────────────
  void startLevel(Level level) {
    _timer?.cancel();
    _failCount = 0;
    _completeCount = 0;
    final build = LetterBuild(
      letter: level.targets[0][0].toUpperCase(),
    );
    _state = GameState(
      level: level,
      lives: level.maxLives,
      timeRemaining: level.timeLimitSecs,
      isPlaying: true,
      letterBuild: build,
      board: _buildBoard(level, 0, 0),
    );
    notifyListeners();
    _startTimer();
  }

  // ─── Board builder ─────────────────────────────────────────────────────────
  // Guarantees at least one piece of the current letter on the board.
  // Rest are random distractor letters.
  List<List<CellTile>> _buildBoard(
      Level level, int targetIdx, int letterIdx) {
    final size = level.gridSize;
    final currentWord = level.targets[targetIdx];
    final currentLetter = currentWord[letterIdx].toUpperCase();
    final pieceCount = LetterFragments.pieceCount(currentLetter);

    // All available distractor letters (A-Z minus current)
    final all = List.generate(26, (i) => String.fromCharCode(65 + i))
      ..remove(currentLetter);
    all.shuffle(_rng);
    final distractors = all.take(8).toList();

    // Piece slots: one per piece of current letter
    final pieceSlots = <_Slot>[];
    for (int i = 0; i < pieceCount; i++) {
      pieceSlots.add(_Slot(letter: currentLetter, pieceIndex: i));
    }

    // Fill remaining cells
    final totalCells = size * size;
    final fillers = <_Slot>[];
    for (int i = pieceSlots.length; i < totalCells; i++) {
      final dl = distractors[_rng.nextInt(distractors.length)];
      final dp = _rng.nextInt(LetterFragments.pieceCount(dl));
      fillers.add(_Slot(letter: dl, pieceIndex: dp));
    }

    final all2 = [...pieceSlots, ...fillers]..shuffle(_rng);

    return List.generate(size, (r) {
      return List.generate(size, (c) {
        final s = all2[r * size + c];
        return CellTile(
          id: '$r-$c',
          letter: s.letter,
          pieceIndex: s.pieceIndex,
        );
      });
    });
  }

  // ─── Timer ─────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == null || !_state!.isPlaying || _state!.isPaused) return;
      final t = _state!.timeRemaining - 1;
      if (t <= 0) {
        _state = _state!.copyWith(
          timeRemaining: 0,
          isPlaying: false,
          isGameOver: true,
        );
        _timer?.cancel();
      } else {
        _state = _state!.copyWith(timeRemaining: t);
      }
      notifyListeners();
    });
  }

  // ─── Tap handler ───────────────────────────────────────────────────────────
  void onTileTapped(int row, int col) {
    final s = _state;
    if (s == null || !s.isPlaying || s.isPaused) return;
    final tile = s.board[row][col];
    if (tile.isCollected) return;

    final isCorrect = tile.letter == s.currentLetter;

    if (isCorrect) {
      _handleCorrect(row, col, tile);
    } else {
      _handleWrong(row, col);
    }
  }

  void _handleCorrect(int row, int col, CellTile tile) {
    final s = _state!;

    // Mark collected
    final newBoard = s.board
        .map((r) => List<CellTile>.from(r))
        .toList();
    newBoard[row][col] = tile.copyWith(isCollected: true);

    // Add piece to build
    final newBuild = s.letterBuild.withPiece(tile.pieceIndex);
    final combo = s.comboCount + 1;
    final pts = (50 + combo * 10).clamp(50, 200);

    if (combo > 1) {
      SoundManager().playCombo();
    } else {
      SoundManager().playCorrect();
    }

    // Is the current letter now complete?
    if (newBuild.isComplete) {
      _onLetterComplete(s, newBoard, combo + 1, pts);
    } else {
      _state = s.copyWith(
        board: newBoard,
        letterBuild: newBuild,
        score: s.score + pts,
        comboCount: combo,
      );
      notifyListeners();
    }
  }

  void _onLetterComplete(
      GameState s, List<List<CellTile>> board, int combo, int pts) {
    const wordBonus = 100;
    final newScore = s.score + pts + wordBonus;

    final word = s.currentWord;
    final nextLetterIdx = s.letterIndex + 1;

    if (nextLetterIdx >= word.length) {
      // ── Word complete ────────────────────────────────────────────
      SoundManager().playBuildComplete();
      final nextTargetIdx = s.targetIndex + 1;

      if (nextTargetIdx >= s.level.targets.length) {
        // All words done → level complete
        _timer?.cancel();
        _completeCount++;
        _state = s.copyWith(
          board: board,
          score: newScore,
          comboCount: 0,
          isPlaying: false,
          isLevelComplete: true,
        );
      } else {
        // Next word — RESET timer to full 100s
        final nextLetter =
            s.level.targets[nextTargetIdx][0].toUpperCase();
        _state = s.copyWith(
          board: _buildBoard(s.level, nextTargetIdx, 0),
          letterBuild: LetterBuild(letter: nextLetter),
          score: newScore,
          comboCount: 0,
          targetIndex: nextTargetIdx,
          letterIndex: 0,
          timeRemaining: s.level.timeLimitSecs, // ← reset per word
        );
        // Restart timer fresh for the new word
        _timer?.cancel();
        _startTimer();
      }
    } else {
      // ── Next letter in SAME word — timer keeps counting ──────────
      final nextLetter = word[nextLetterIdx].toUpperCase();
      _state = s.copyWith(
        board: _buildBoard(s.level, s.targetIndex, nextLetterIdx),
        letterBuild: LetterBuild(letter: nextLetter),
        score: newScore,
        comboCount: 0,
        letterIndex: nextLetterIdx,
        // timeRemaining NOT touched — continues from where it was
      );
    }
    notifyListeners();
  }

  void _handleWrong(int row, int col) {
    final s = _state!;
    final tile = s.board[row][col];

    SoundManager().playWrong();
    _failCount++;

    // Flash shake
    final newBoard =
        s.board.map((r) => List<CellTile>.from(r)).toList();
    newBoard[row][col] = tile.copyWith(isShaking: true);

    final newLives = s.lives - 1;
    const newCombo = 0;

    if (newLives <= 0) {
      _timer?.cancel();
      _state = s.copyWith(
        board: newBoard,
        lives: 0,
        comboCount: newCombo,
        isPlaying: false,
        isGameOver: true,
      );
    } else {
      _state = s.copyWith(
        board: newBoard,
        lives: newLives,
        comboCount: newCombo,
      );
      // Clear shake after 400ms
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_state == null) return;
        final b = _state!.board
            .map((r) => List<CellTile>.from(r))
            .toList();
        b[row][col] = b[row][col].copyWith(isShaking: false);
        _state = _state!.copyWith(board: b);
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // ─── Pause / resume ────────────────────────────────────────────────────────
  void pause() {
    if (_state == null || !_state!.isPlaying) return;
    _state = _state!.copyWith(isPaused: true);
    notifyListeners();
  }

  void resume() {
    if (_state == null || !_state!.isPlaying) return;
    _state = _state!.copyWith(isPaused: false);
    notifyListeners();
  }

  // ─── Hint: pulses all correct tiles ───────────────────────────────────────
  void useHint() {
    final s = _state;
    if (s == null || !s.isPlaying) return;

    final b = s.board.map((r) => List<CellTile>.from(r)).toList();
    for (int r = 0; r < b.length; r++) {
      for (int c = 0; c < b[r].length; c++) {
        if (b[r][c].letter == s.currentLetter && !b[r][c].isCollected) {
          b[r][c] = b[r][c].copyWith(isPulsing: true);
        }
      }
    }
    _state = s.copyWith(board: b);
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_state == null) return;
      final b2 = _state!.board
          .map((r) => r.map((c) => c.copyWith(isPulsing: false)).toList())
          .toList();
      _state = _state!.copyWith(board: b2);
      notifyListeners();
    });
  }

  // ─── Add time (rewarded ad) ────────────────────────────────────────────────
  void addTime(int seconds) {
    if (_state == null) return;
    _state = _state!.copyWith(
      timeRemaining: _state!.timeRemaining + seconds,
      isPlaying: true,
      isGameOver: false,
    );
    if (!(_state!.isPlaying)) _startTimer();
    notifyListeners();
  }

  // ─── Continue after game over (rewarded ad) ────────────────────────────────
  void continueGame() {
    if (_state == null) return;
    _state = _state!.copyWith(
      lives: 3,
      timeRemaining: max(30, _state!.timeRemaining),
      isPlaying: true,
      isGameOver: false,
    );
    _startTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _Slot {
  final String letter;
  final int pieceIndex;
  _Slot({required this.letter, required this.pieceIndex});
}
