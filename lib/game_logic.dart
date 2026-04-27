import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models/game_state.dart';
import 'models/level.dart';
import 'letter_fragments.dart';

class GameLogic extends ChangeNotifier {
  GameState? _state;
  GameState? get state => _state;

  final Function()? onCombo;
  final Function()? onBuildComplete;
  final Function()? onGameOver;
  final Function()? onLevelComplete;
  final Function()? onWrongTap;

  GameLogic({
    this.onCombo,
    this.onBuildComplete,
    this.onGameOver,
    this.onLevelComplete,
    this.onWrongTap,
  });

  void startLevel(Level level) {
    final board = _generateBoard(level);
    final target = level.isWord 
        ? level.target.toUpperCase().split('').first 
        : level.target.toUpperCase();
    
    _state = GameState(
      level: level,
      board: board,
      currentTarget: target,
      timeRemaining: level.timeLimit,
      lives: level.maxLives,
      isPlaying: true,
    );
    notifyListeners();
  }

  List<List<CellFragment>> _generateBoard(Level level) {
    final random = Random();
    final board = <List<CellFragment>>[];
    final target = level.isWord ? level.target.toUpperCase() : level.target.toUpperCase();
    final letters = target.split('');
    
    // Collect all required fragments for all letters
    final List<String> allRequiredFragments = [];
    for (var letter in letters) {
      final frags = LetterFragments.getFragments(letter);
      allRequiredFragments.addAll(frags);
    }

    // Create pool of fragments to distribute
    final List<MapEntry<String, int>> fragmentPool = [];
    for (int i = 0; i < allRequiredFragments.length; i++) {
      fragmentPool.add(MapEntry(allRequiredFragments[i], i));
    }

    // Add distractor fragments
    final distractorSymbols = ['/', '\\', '|', '-', '_', '(', ')', '<', '>'];
    for (int i = 0; i < level.gridSize * 2; i++) {
      fragmentPool.add(MapEntry(distractorSymbols[random.nextInt(distractorSymbols.length)], -1));
    }

    // Shuffle pool
    fragmentPool.shuffle(random);

    // Fill board
    int poolIndex = 0;
    for (int row = 0; row < level.gridSize; row++) {
      final rowList = <CellFragment>[];
      for (int col = 0; col < level.gridSize; col++) {
        if (poolIndex < fragmentPool.length) {
          final entry = fragmentPool[poolIndex];
          rowList.add(CellFragment(
            id: '$row-$col',
            symbol: entry.key,
            sequenceIndex: entry.value >= 0 ? entry.value : null,
            requiredFor: entry.value >= 0 ? target : null,
          ));
          poolIndex++;
        } else {
          rowList.add(CellFragment(
            id: '$row-$col',
            symbol: distractorSymbols[random.nextInt(distractorSymbols.length)],
          ));
        }
      }
      board.add(rowList);
    }

    return board;
  }

  void onFragmentTap(int row, int col) {
    if (_state == null || !_state!.isPlaying || _state!.isPaused) return;
    
    final fragment = _state!.board[row][col];
    if (fragment.isMatched || fragment.isSelected) return;

    final targetSequence = LetterFragments.getFragments(_state!.currentTarget);
    final currentStep = _state!.selectedFragments.length;

    // Check if this fragment matches the next needed fragment
    if (currentStep < targetSequence.length && fragment.symbol == targetSequence[currentStep]) {
      // Correct tap
      _selectFragment(row, col, fragment);
      
      if (_state!.selectedFragments.length == targetSequence.length) {
        // Letter complete!
        _completeLetter();
      } else {
        // Continue building
        // notifyListeners(); // called in _selectFragment
      }
    } else {
      // Wrong tap
      _handleWrongTap(row, col);
    }
  }

  void _selectFragment(int row, int col, CellFragment fragment) {
    final newBoard = _state!.board.map((r) => List<CellFragment>.from(r)).toList();
    final selected = List<CellFragment>.from(_state!.selectedFragments);
    
    final updatedFragment = fragment.copyWith(isSelected: true, scale: 1.2);
    newBoard[row][col] = updatedFragment;
    selected.add(updatedFragment);

    // Calculate combo bonus
    int comboBonus = 0;
    int newCombo = _state!.comboCount;
    if (selected.length == LetterFragments.getFragments(_state!.currentTarget).length) {
      newCombo++;
      comboBonus = newCombo * 50;
      if (newCombo >= 2) {
        onCombo?.call();
      }
    }

    _state = _state!.copyWith(
      board: newBoard,
      selectedFragments: selected,
      score: _state!.score + 10 + comboBonus,
      comboCount: newCombo,
    );
    notifyListeners();
  }

  void _handleWrongTap(int row, int col) {
    final newBoard = _state!.board.map((r) => List<CellFragment>.from(r)).toList();
    
    // Flash the wrong fragment red
    final wrongFragment = newBoard[row][col];
    newBoard[row][col] = wrongFragment.copyWith(isAnimating: true, scale: 0.8);

    int newLives = _state!.lives - 1;
    int newScore = _state!.score - 20;
    if (newScore < 0) newScore = 0;

    // Reset combo
    int newCombo = 0;

    // Clear selection if shuffle mode
    List<CellFragment> newSelected = List<CellFragment>.from(_state!.selectedFragments);
    if (_state!.level.shuffleOnWrong) {
      for (var f in newSelected) {
        final parts = f.id.split('-');
        final r = int.parse(parts[0]);
        final c = int.parse(parts[1]);
        newBoard[r][c] = newBoard[r][c].copyWith(isSelected: false);
      }
      newSelected = [];
    }

    _state = _state!.copyWith(
      board: newBoard,
      lives: newLives,
      score: newScore,
      comboCount: newCombo,
      selectedFragments: newSelected,
    );

    onWrongTap?.call();
    notifyListeners();

    // Reset animation after delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_state != null) {
        final resetBoard = _state!.board.map((r) => List<CellFragment>.from(r)).toList();
        resetBoard[row][col] = resetBoard[row][col].copyWith(isAnimating: false, scale: 1.0);
        _state = _state!.copyWith(board: resetBoard);
        notifyListeners();
      }
    });

    if (newLives <= 0) {
      _gameOver();
    }
  }

  void _completeLetter() {
    onBuildComplete?.call();
    
    final target = _state!.level.isWord ? _state!.level.target.toUpperCase() : _state!.level.target.toUpperCase();
    final letters = target.split('');
    
    // Mark matched fragments and clear them
    final newBoard = _state!.board.map((r) => List<CellFragment>.from(r)).toList();
    for (var fragment in _state!.selectedFragments) {
      final parts = fragment.id.split('-');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      newBoard[row][col] = newBoard[row][col].copyWith(isMatched: true, isSelected: false);
    }

    _state = _state!.copyWith(
      board: newBoard,
      selectedFragments: [],
      totalMatches: _state!.totalMatches + 1,
    );
    notifyListeners();

    // Animate fall after delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _animateAndFillBoard();
      
      // Move to next letter if word mode
      if (_state!.level.isWord) {
        final newIndex = _state!.currentLetterIndex + 1;
        if (newIndex < letters.length) {
          _state = _state!.copyWith(
            currentLetterIndex: newIndex,
            currentTarget: letters[newIndex],
          );
          notifyListeners();
        } else {
          _levelComplete();
        }
      } else {
        _levelComplete();
      }
    });
  }

  void _animateAndFillBoard() {
    if (_state == null) return;

    final random = Random();
    final size = _state!.level.gridSize;
    final newBoard = _state!.board.map((r) => List<CellFragment>.from(r)).toList();
    final distractorSymbols = ['/', '\\', '|', '-', '_', '(', ')', '<', '>'];

    // Collect current target's required fragments to ensure they're placed
    final targetFrags = LetterFragments.getFragments(_state!.currentTarget);
    int targetFragIndex = 0;

    // Remove matched, let others fall, fill top
    for (int col = 0; col < size; col++) {
      // Collect non-matched from bottom to top
      final List<CellFragment> survivors = [];
      for (int row = size - 1; row >= 0; row--) {
        if (!newBoard[row][col].isMatched) {
          survivors.add(newBoard[row][col]);
        }
      }

      // Fill from bottom
      for (int row = size - 1; row >= 0; row--) {
        if (survivors.isNotEmpty) {
          final frag = survivors.removeAt(0);
          newBoard[row][col] = frag.copyWith(
            id: '$row-$col',
            isMatched: false,
            isSelected: false,
            isAnimating: false,
            scale: 1.0,
          );
        } else {
          // Inject required fragments for current target to ensure playability
          String symbol;
          if (targetFragIndex < targetFrags.length) {
            symbol = targetFrags[targetFragIndex];
            targetFragIndex++;
          } else {
            symbol = distractorSymbols[random.nextInt(distractorSymbols.length)];
          }
          newBoard[row][col] = CellFragment(
            id: '$row-$col',
            symbol: symbol,
          );
        }
      }
    }

    _state = _state!.copyWith(board: newBoard);
    notifyListeners();
  }

  void _gameOver() {
    _state = _state!.copyWith(
      isPlaying: false,
      isGameOver: true,
    );
    onGameOver?.call();
    notifyListeners();
  }

  void _levelComplete() {
    final timeBonus = _state!.timeRemaining * 5;
    final livesBonus = _state!.lives * 100;
    
    _state = _state!.copyWith(
      isPlaying: false,
      isLevelComplete: true,
      score: _state!.score + timeBonus + livesBonus,
    );
    onLevelComplete?.call();
    notifyListeners();
  }

  void tickTimer() {
    if (_state == null || !_state!.isPlaying || _state!.isPaused) return;
    
    final newTime = _state!.timeRemaining - 1;
    _state = _state!.copyWith(timeRemaining: newTime);
    
    if (newTime <= 0) {
      _gameOver();
    } else {
      notifyListeners();
    }
  }

  void pause() {
    if (_state != null && _state!.isPlaying) {
      _state = _state!.copyWith(isPaused: true);
      notifyListeners();
    }
  }

  void resume() {
    if (_state != null && _state!.isPaused) {
      _state = _state!.copyWith(isPaused: false);
      notifyListeners();
    }
  }

  void restart() {
    if (_state != null) {
      startLevel(_state!.level);
    }
  }

  void continueWithLives(int bonusLives) {
    if (_state != null) {
      _state = _state!.copyWith(
        lives: _state!.lives + bonusLives,
        isPlaying: true,
        isGameOver: false,
      );
      notifyListeners();
    }
  }

  void disposeState() {
    _state = null;
  }
}
