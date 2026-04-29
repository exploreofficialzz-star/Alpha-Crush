class Level {
  final int id;
  final List<String> targets; // exactly 3 per level
  final int gridSize;
  final int timeLimitSecs; // flat 90s all levels
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
    this.starThreshold1 = 200,
    this.starThreshold2 = 400,
    this.starThreshold3 = 600,
  });

  String get stageLabel {
    if (id <= 10) return 'SINGLE LETTERS';
    if (id <= 20) return '2-LETTER WORDS';
    if (id <= 35) return '3-LETTER WORDS';
    return '4-LETTER WORDS';
  }

  int get stageIndex {
    if (id <= 10) return 0;
    if (id <= 20) return 1;
    if (id <= 35) return 2;
    return 3;
  }

  static const List<Level> all = [

    // ══════════════════════════════════════════════════════════════
    // STAGE 1 — SINGLE LETTERS  (Levels 1–10)
    // Grid 5×5 · 90s · 3 letters per level
    // ══════════════════════════════════════════════════════════════
    Level(id:  1, targets: ['A', 'B', 'C'], gridSize: 5,
          starThreshold1: 150, starThreshold2: 320, starThreshold3: 500),
    Level(id:  2, targets: ['D', 'E', 'F'], gridSize: 5,
          starThreshold1: 155, starThreshold2: 330, starThreshold3: 510),
    Level(id:  3, targets: ['G', 'H', 'I'], gridSize: 5,
          starThreshold1: 160, starThreshold2: 340, starThreshold3: 520),
    Level(id:  4, targets: ['J', 'K', 'L'], gridSize: 5,
          starThreshold1: 165, starThreshold2: 350, starThreshold3: 530),
    Level(id:  5, targets: ['M', 'N', 'O'], gridSize: 5,
          starThreshold1: 170, starThreshold2: 360, starThreshold3: 540),
    Level(id:  6, targets: ['P', 'Q', 'R'], gridSize: 5,
          starThreshold1: 175, starThreshold2: 370, starThreshold3: 550),
    Level(id:  7, targets: ['S', 'T', 'U'], gridSize: 5,
          starThreshold1: 180, starThreshold2: 380, starThreshold3: 560),
    Level(id:  8, targets: ['V', 'W', 'X'], gridSize: 5,
          starThreshold1: 185, starThreshold2: 390, starThreshold3: 570),
    Level(id:  9, targets: ['Y', 'Z', 'A'], gridSize: 5,
          starThreshold1: 190, starThreshold2: 400, starThreshold3: 580),
    Level(id: 10, targets: ['E', 'M', 'S'], gridSize: 5,
          starThreshold1: 195, starThreshold2: 410, starThreshold3: 590),

    // ══════════════════════════════════════════════════════════════
    // STAGE 2 — 2-LETTER WORDS  (Levels 11–20)
    // Grid 5×5 · 90s · 3 words per level
    // ══════════════════════════════════════════════════════════════
    Level(id: 11, targets: ['DO', 'GO', 'NO'], gridSize: 5,
          starThreshold1: 250, starThreshold2: 500, starThreshold3: 750),
    Level(id: 12, targets: ['TO', 'SO', 'HO'], gridSize: 5,
          starThreshold1: 260, starThreshold2: 520, starThreshold3: 770),
    Level(id: 13, targets: ['BE', 'HE', 'ME'], gridSize: 5,
          starThreshold1: 270, starThreshold2: 540, starThreshold3: 790),
    Level(id: 14, targets: ['WE', 'IT', 'IF'], gridSize: 5,
          starThreshold1: 280, starThreshold2: 560, starThreshold3: 810),
    Level(id: 15, targets: ['IS', 'IN', 'UP'], gridSize: 5,
          starThreshold1: 290, starThreshold2: 580, starThreshold3: 830),
    Level(id: 16, targets: ['ON', 'AT', 'AN'], gridSize: 5,
          starThreshold1: 300, starThreshold2: 600, starThreshold3: 850),
    Level(id: 17, targets: ['AS', 'BY', 'MY'], gridSize: 5,
          starThreshold1: 310, starThreshold2: 620, starThreshold3: 870),
    Level(id: 18, targets: ['OR', 'OF', 'HI'], gridSize: 5,
          starThreshold1: 320, starThreshold2: 640, starThreshold3: 890),
    Level(id: 19, targets: ['OX', 'OH', 'AM'], gridSize: 5,
          starThreshold1: 330, starThreshold2: 660, starThreshold3: 910),
    Level(id: 20, targets: ['US', 'EX', 'AX'], gridSize: 5,
          starThreshold1: 340, starThreshold2: 680, starThreshold3: 930),

    // ══════════════════════════════════════════════════════════════
    // STAGE 3 — 3-LETTER WORDS  (Levels 21–35)
    // Grid 6×6 · 90s · 3 words per level
    // ══════════════════════════════════════════════════════════════
    Level(id: 21, targets: ['CAT', 'DOG', 'SUN'], gridSize: 6,
          starThreshold1: 350, starThreshold2: 700, starThreshold3: 1050),
    Level(id: 22, targets: ['RUN', 'FUN', 'GUN'], gridSize: 6,
          starThreshold1: 360, starThreshold2: 720, starThreshold3: 1070),
    Level(id: 23, targets: ['BED', 'RED', 'TED'], gridSize: 6,
          starThreshold1: 370, starThreshold2: 740, starThreshold3: 1090),
    Level(id: 24, targets: ['SAD', 'MAD', 'DAD'], gridSize: 6,
          starThreshold1: 380, starThreshold2: 760, starThreshold3: 1110),
    Level(id: 25, targets: ['BOX', 'FOX', 'HOT'], gridSize: 6,
          starThreshold1: 390, starThreshold2: 780, starThreshold3: 1130),
    Level(id: 26, targets: ['TOP', 'HOP', 'MOP'], gridSize: 6,
          starThreshold1: 400, starThreshold2: 800, starThreshold3: 1150),
    Level(id: 27, targets: ['ARM', 'CAR', 'FAR'], gridSize: 6,
          starThreshold1: 410, starThreshold2: 820, starThreshold3: 1170),
    Level(id: 28, targets: ['JAR', 'BAR', 'TAR'], gridSize: 6,
          starThreshold1: 420, starThreshold2: 840, starThreshold3: 1190),
    Level(id: 29, targets: ['FOR', 'AND', 'BUT'], gridSize: 6,
          starThreshold1: 430, starThreshold2: 860, starThreshold3: 1210),
    Level(id: 30, targets: ['NOT', 'GET', 'LET'], gridSize: 6,
          starThreshold1: 440, starThreshold2: 880, starThreshold3: 1230),
    Level(id: 31, targets: ['SET', 'WET', 'MET'], gridSize: 6,
          starThreshold1: 450, starThreshold2: 900, starThreshold3: 1250),
    Level(id: 32, targets: ['HIT', 'SIT', 'FIT'], gridSize: 6,
          starThreshold1: 460, starThreshold2: 920, starThreshold3: 1270),
    Level(id: 33, targets: ['CUT', 'BUT', 'PUT'], gridSize: 6,
          starThreshold1: 470, starThreshold2: 940, starThreshold3: 1290),
    Level(id: 34, targets: ['OWL', 'COW', 'HOW'], gridSize: 6,
          starThreshold1: 480, starThreshold2: 960, starThreshold3: 1310),
    Level(id: 35, targets: ['SKY', 'FLY', 'DRY'], gridSize: 6,
          starThreshold1: 490, starThreshold2: 980, starThreshold3: 1330),

    // ══════════════════════════════════════════════════════════════
    // STAGE 4 — 4-LETTER WORDS  (Levels 36–50)
    // Grid 7×7 · 90s · 3 words per level
    // ══════════════════════════════════════════════════════════════
    Level(id: 36, targets: ['STAR', 'MOON', 'FIRE'], gridSize: 7,
          starThreshold1: 550, starThreshold2: 1100, starThreshold3: 1650),
    Level(id: 37, targets: ['WIND', 'RAIN', 'SNOW'], gridSize: 7,
          starThreshold1: 560, starThreshold2: 1120, starThreshold3: 1680),
    Level(id: 38, targets: ['BEAR', 'DEAR', 'FEAR'], gridSize: 7,
          starThreshold1: 570, starThreshold2: 1140, starThreshold3: 1710),
    Level(id: 39, targets: ['GEAR', 'NEAR', 'YEAR'], gridSize: 7,
          starThreshold1: 580, starThreshold2: 1160, starThreshold3: 1740),
    Level(id: 40, targets: ['CAKE', 'LAKE', 'MAKE'], gridSize: 7,
          starThreshold1: 590, starThreshold2: 1180, starThreshold3: 1770),
    Level(id: 41, targets: ['TAKE', 'WAKE', 'BAKE'], gridSize: 7,
          starThreshold1: 600, starThreshold2: 1200, starThreshold3: 1800),
    Level(id: 42, targets: ['BOOK', 'COOK', 'HOOK'], gridSize: 7,
          starThreshold1: 610, starThreshold2: 1220, starThreshold3: 1830),
    Level(id: 43, targets: ['LOOK', 'TOOK', 'ROOK'], gridSize: 7,
          starThreshold1: 620, starThreshold2: 1240, starThreshold3: 1860),
    Level(id: 44, targets: ['BLUE', 'CLUE', 'GLUE'], gridSize: 7,
          starThreshold1: 630, starThreshold2: 1260, starThreshold3: 1890),
    Level(id: 45, targets: ['TRUE', 'FLEW', 'BLEW'], gridSize: 7,
          starThreshold1: 640, starThreshold2: 1280, starThreshold3: 1920),
    Level(id: 46, targets: ['BOLD', 'COLD', 'FOLD'], gridSize: 7,
          starThreshold1: 650, starThreshold2: 1300, starThreshold3: 1950),
    Level(id: 47, targets: ['GOLD', 'HOLD', 'MOLD'], gridSize: 7,
          starThreshold1: 660, starThreshold2: 1320, starThreshold3: 1980),
    Level(id: 48, targets: ['BEST', 'FEST', 'NEST'], gridSize: 7,
          starThreshold1: 670, starThreshold2: 1340, starThreshold3: 2010),
    Level(id: 49, targets: ['REST', 'TEST', 'VEST'], gridSize: 7,
          starThreshold1: 680, starThreshold2: 1360, starThreshold3: 2040),
    Level(id: 50, targets: ['GLOW', 'FLOW', 'SLOW'], gridSize: 7,
          starThreshold1: 700, starThreshold2: 1400, starThreshold3: 2100),
  ];

  static Level byId(int id) => all.firstWhere((l) => l.id == id);
}
