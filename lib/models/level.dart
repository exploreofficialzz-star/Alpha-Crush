class Level {
  final int id;
  final String target;
  final bool isWord;
  final int gridSize;
  final int timeLimit;
  final int starThreshold1;
  final int starThreshold2;
  final int starThreshold3;
  final bool shuffleOnWrong;
  final int maxLives;

  Level({
    required this.id,
    required this.target,
    this.isWord = false,
    this.gridSize = 8,
    this.timeLimit = 60,
    this.starThreshold1 = 100,
    this.starThreshold2 = 250,
    this.starThreshold3 = 400,
    this.shuffleOnWrong = false,
    this.maxLives = 3,
  });

  String get displayTarget => isWord ? target : target;

  static List<Level> getAllLevels() {
    return [
      // Stage 1: Simple Letters
      Level(id: 1, target: 'A', gridSize: 6, timeLimit: 45, starThreshold1: 50, starThreshold2: 120, starThreshold3: 200),
      Level(id: 2, target: 'L', gridSize: 6, timeLimit: 45, starThreshold1: 60, starThreshold2: 140, starThreshold3: 220),
      Level(id: 3, target: 'T', gridSize: 6, timeLimit: 40, starThreshold1: 70, starThreshold2: 150, starThreshold3: 240),
      Level(id: 4, target: 'V', gridSize: 6, timeLimit: 40, starThreshold1: 80, starThreshold2: 160, starThreshold3: 260),
      Level(id: 5, target: 'X', gridSize: 6, timeLimit: 35, starThreshold1: 90, starThreshold2: 180, starThreshold3: 280),
      
      // Stage 2: Medium Letters
      Level(id: 6, target: 'K', gridSize: 7, timeLimit: 50, starThreshold1: 100, starThreshold2: 200, starThreshold3: 320),
      Level(id: 7, target: 'Y', gridSize: 7, timeLimit: 50, starThreshold1: 110, starThreshold2: 220, starThreshold3: 340),
      Level(id: 8, target: 'Z', gridSize: 7, timeLimit: 50, starThreshold1: 120, starThreshold2: 240, starThreshold3: 360),
      Level(id: 9, target: 'H', gridSize: 7, timeLimit: 45, starThreshold1: 130, starThreshold2: 260, starThreshold3: 380, shuffleOnWrong: true),
      Level(id: 10, target: 'W', gridSize: 7, timeLimit: 45, starThreshold1: 140, starThreshold2: 280, starThreshold3: 400, shuffleOnWrong: true),
      
      // Stage 3: Complex Letters
      Level(id: 11, target: 'M', gridSize: 8, timeLimit: 55, starThreshold1: 150, starThreshold2: 300, starThreshold3: 450),
      Level(id: 12, target: 'N', gridSize: 8, timeLimit: 55, starThreshold1: 160, starThreshold2: 320, starThreshold3: 480, shuffleOnWrong: true),
      Level(id: 13, target: 'E', gridSize: 8, timeLimit: 55, starThreshold1: 170, starThreshold2: 340, starThreshold3: 500, shuffleOnWrong: true),
      Level(id: 14, target: 'F', gridSize: 8, timeLimit: 50, starThreshold1: 180, starThreshold2: 360, starThreshold3: 520, shuffleOnWrong: true),
      Level(id: 15, target: 'B', gridSize: 8, timeLimit: 50, starThreshold1: 200, starThreshold2: 380, starThreshold3: 550, shuffleOnWrong: true),
      
      // Stage 4: Words
      Level(id: 16, target: 'CAT', isWord: true, gridSize: 8, timeLimit: 90, starThreshold1: 250, starThreshold2: 500, starThreshold3: 750),
      Level(id: 17, target: 'DOG', isWord: true, gridSize: 8, timeLimit: 90, starThreshold1: 280, starThreshold2: 550, starThreshold3: 800),
      Level(id: 18, target: 'SUN', isWord: true, gridSize: 8, timeLimit: 85, starThreshold1: 300, starThreshold2: 600, starThreshold3: 900),
      Level(id: 19, target: 'STAR', isWord: true, gridSize: 8, timeLimit: 100, starThreshold1: 350, starThreshold2: 700, starThreshold3: 1000, shuffleOnWrong: true),
      Level(id: 20, target: 'MOON', isWord: true, gridSize: 8, timeLimit: 100, starThreshold1: 400, starThreshold2: 800, starThreshold3: 1200, shuffleOnWrong: true),
    ];
  }

  static Level getLevel(int id) {
    return getAllLevels().firstWhere((l) => l.id == id);
  }
}
