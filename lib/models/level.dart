class Level {
  final int id;
  final List<String> targets; // 5 words / letters per level
  final int gridSize;
  final int timeLimitSecs;
  final int maxLives;
  final int starThreshold1;
  final int starThreshold2;
  final int starThreshold3;

  const Level({
    required this.id,
    required this.targets,
    this.gridSize = 5,
    this.timeLimitSecs = 90,
    this.maxLives = 3,
    this.starThreshold1 = 150,
    this.starThreshold2 = 350,
    this.starThreshold3 = 550,
  });

  String get stageLabel {
    if (id <= 5) return 'SINGLE LETTERS';
    if (id <= 10) return '2-LETTER WORDS';
    if (id <= 15) return '3-LETTER WORDS';
    return '4-LETTER WORDS';
  }

  static const List<Level> all = [
    // ── Stage 1: Single letters ──────────────────────────────────
    Level(
      id: 1, targets: ['A', 'B', 'C', 'D', 'E'],
      gridSize: 5, timeLimitSecs: 90, maxLives: 3,
      starThreshold1: 100, starThreshold2: 250, starThreshold3: 420,
    ),
    Level(
      id: 2, targets: ['F', 'G', 'H', 'I', 'J'],
      gridSize: 5, timeLimitSecs: 85, maxLives: 3,
      starThreshold1: 110, starThreshold2: 270, starThreshold3: 440,
    ),
    Level(
      id: 3, targets: ['K', 'L', 'M', 'N', 'O'],
      gridSize: 5, timeLimitSecs: 80, maxLives: 3,
      starThreshold1: 120, starThreshold2: 290, starThreshold3: 460,
    ),
    Level(
      id: 4, targets: ['P', 'Q', 'R', 'S', 'T'],
      gridSize: 5, timeLimitSecs: 75, maxLives: 3,
      starThreshold1: 130, starThreshold2: 310, starThreshold3: 480,
    ),
    Level(
      id: 5, targets: ['U', 'V', 'W', 'X', 'Y'],
      gridSize: 5, timeLimitSecs: 70, maxLives: 3,
      starThreshold1: 140, starThreshold2: 330, starThreshold3: 500,
    ),

    // ── Stage 2: 2-letter words ──────────────────────────────────
    Level(
      id: 6, targets: ['DO', 'GO', 'NO', 'SO', 'TO'],
      gridSize: 6, timeLimitSecs: 120, maxLives: 3,
      starThreshold1: 200, starThreshold2: 450, starThreshold3: 700,
    ),
    Level(
      id: 7, targets: ['BE', 'HE', 'ME', 'WE', 'IT'],
      gridSize: 6, timeLimitSecs: 115, maxLives: 3,
      starThreshold1: 220, starThreshold2: 470, starThreshold3: 730,
    ),
    Level(
      id: 8, targets: ['IF', 'IS', 'IN', 'UP', 'ON'],
      gridSize: 6, timeLimitSecs: 110, maxLives: 3,
      starThreshold1: 240, starThreshold2: 490, starThreshold3: 760,
    ),
    Level(
      id: 9, targets: ['AT', 'AN', 'AS', 'BY', 'MY'],
      gridSize: 6, timeLimitSecs: 105, maxLives: 3,
      starThreshold1: 260, starThreshold2: 510, starThreshold3: 790,
    ),
    Level(
      id: 10, targets: ['OR', 'OF', 'HI', 'OH', 'OX'],
      gridSize: 6, timeLimitSecs: 100, maxLives: 3,
      starThreshold1: 280, starThreshold2: 530, starThreshold3: 820,
    ),

    // ── Stage 3: 3-letter words ──────────────────────────────────
    Level(
      id: 11, targets: ['CAT', 'DOG', 'SUN', 'RUN', 'FUN'],
      gridSize: 6, timeLimitSecs: 150, maxLives: 3,
      starThreshold1: 350, starThreshold2: 700, starThreshold3: 1050,
    ),
    Level(
      id: 12, targets: ['BED', 'SAD', 'MAD', 'DAD', 'HAD'],
      gridSize: 6, timeLimitSecs: 145, maxLives: 3,
      starThreshold1: 370, starThreshold2: 730, starThreshold3: 1080,
    ),
    Level(
      id: 13, targets: ['BOX', 'FOX', 'TOP', 'HOP', 'MOP'],
      gridSize: 7, timeLimitSecs: 140, maxLives: 3,
      starThreshold1: 390, starThreshold2: 760, starThreshold3: 1110,
    ),
    Level(
      id: 14, targets: ['ARM', 'FAR', 'CAR', 'BAR', 'JAR'],
      gridSize: 7, timeLimitSecs: 135, maxLives: 3,
      starThreshold1: 410, starThreshold2: 790, starThreshold3: 1140,
    ),
    Level(
      id: 15, targets: ['FOR', 'AND', 'BUT', 'NOT', 'GET'],
      gridSize: 7, timeLimitSecs: 130, maxLives: 3,
      starThreshold1: 430, starThreshold2: 820, starThreshold3: 1170,
    ),

    // ── Stage 4: 4-letter words ──────────────────────────────────
    Level(
      id: 16, targets: ['STAR', 'MOON', 'FIRE', 'WIND', 'RAIN'],
      gridSize: 7, timeLimitSecs: 180, maxLives: 3,
      starThreshold1: 500, starThreshold2: 1000, starThreshold3: 1500,
    ),
    Level(
      id: 17, targets: ['BEAR', 'DEAR', 'FEAR', 'GEAR', 'NEAR'],
      gridSize: 7, timeLimitSecs: 175, maxLives: 3,
      starThreshold1: 530, starThreshold2: 1050, starThreshold3: 1550,
    ),
    Level(
      id: 18, targets: ['CAKE', 'LAKE', 'MAKE', 'TAKE', 'WAKE'],
      gridSize: 7, timeLimitSecs: 170, maxLives: 3,
      starThreshold1: 560, starThreshold2: 1100, starThreshold3: 1600,
    ),
    Level(
      id: 19, targets: ['BOOK', 'COOK', 'HOOK', 'LOOK', 'TOOK'],
      gridSize: 7, timeLimitSecs: 165, maxLives: 3,
      starThreshold1: 590, starThreshold2: 1150, starThreshold3: 1650,
    ),
    Level(
      id: 20, targets: ['BLUE', 'CLUE', 'GLUE', 'TRUE', 'FLEW'],
      gridSize: 8, timeLimitSecs: 160, maxLives: 3,
      starThreshold1: 620, starThreshold2: 1200, starThreshold3: 1700,
    ),
  ];

  static Level byId(int id) => all.firstWhere((l) => l.id == id);
}
