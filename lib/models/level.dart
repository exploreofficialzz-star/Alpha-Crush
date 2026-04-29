class Level {
  final int id;
  final List<String> targets; // exactly 3 per level
  final int gridSize;
  final int timeLimitSecs; // flat 90s all levels
  final int maxLives;
  final int starThreshold1;
  final int starThreshold2;
  final int starThreshold3;
  final int stageNumber;

  const Level({
    required this.id,
    required this.targets,
    required this.stageNumber,
    this.gridSize = 5,
    this.timeLimitSecs = 90,
    this.maxLives = 3,
    this.starThreshold1 = 150,
    this.starThreshold2 = 350,
    this.starThreshold3 = 600,
  });

  static Level byId(int id) => all.firstWhere((l) => l.id == id);

  static const List<Level> all = [

    // ════════════════════════════════════════════════════════════
    // STAGE 1 — SINGLE LETTERS  (Levels 1–3)
    // ════════════════════════════════════════════════════════════
    Level(id: 1, stageNumber: 1, targets: ['A', 'B', 'C'],
          gridSize: 5,
          starThreshold1: 120, starThreshold2: 260, starThreshold3: 420),
    Level(id: 2, stageNumber: 1, targets: ['D', 'E', 'F'],
          gridSize: 5,
          starThreshold1: 125, starThreshold2: 270, starThreshold3: 435),
    Level(id: 3, stageNumber: 1, targets: ['G', 'H', 'I'],
          gridSize: 5,
          starThreshold1: 130, starThreshold2: 280, starThreshold3: 450),

    // ════════════════════════════════════════════════════════════
    // STAGE 2 — 2-LETTER WORDS  (Levels 4–6)
    // ════════════════════════════════════════════════════════════
    Level(id: 4, stageNumber: 2, targets: ['DO', 'GO', 'NO'],
          gridSize: 5,
          starThreshold1: 200, starThreshold2: 420, starThreshold3: 650),
    Level(id: 5, stageNumber: 2, targets: ['BE', 'HE', 'ME'],
          gridSize: 5,
          starThreshold1: 210, starThreshold2: 440, starThreshold3: 670),
    Level(id: 6, stageNumber: 2, targets: ['IF', 'IT', 'IS'],
          gridSize: 5,
          starThreshold1: 220, starThreshold2: 460, starThreshold3: 690),

    // ════════════════════════════════════════════════════════════
    // STAGE 3 — 3-LETTER WORDS  (Levels 7–9)
    // ════════════════════════════════════════════════════════════
    Level(id: 7, stageNumber: 3, targets: ['CAT', 'DOG', 'SUN'],
          gridSize: 5,
          starThreshold1: 280, starThreshold2: 560, starThreshold3: 840),
    Level(id: 8, stageNumber: 3, targets: ['BED', 'RED', 'FUN'],
          gridSize: 5,
          starThreshold1: 290, starThreshold2: 580, starThreshold3: 870),
    Level(id: 9, stageNumber: 3, targets: ['BOX', 'FOX', 'HOT'],
          gridSize: 5,
          starThreshold1: 300, starThreshold2: 600, starThreshold3: 900),

    // ════════════════════════════════════════════════════════════
    // STAGE 4 — 4-LETTER WORDS  (Levels 10–12)
    // ════════════════════════════════════════════════════════════
    Level(id: 10, stageNumber: 4, targets: ['STAR', 'MOON', 'FIRE'],
          gridSize: 6,
          starThreshold1: 380, starThreshold2: 750, starThreshold3: 1120),
    Level(id: 11, stageNumber: 4, targets: ['BEAR', 'DEAR', 'FEAR'],
          gridSize: 6,
          starThreshold1: 390, starThreshold2: 770, starThreshold3: 1150),
    Level(id: 12, stageNumber: 4, targets: ['CAKE', 'LAKE', 'MAKE'],
          gridSize: 6,
          starThreshold1: 400, starThreshold2: 790, starThreshold3: 1180),

    // ════════════════════════════════════════════════════════════
    // STAGE 5 — 5-LETTER WORDS  (Levels 13–15)
    // ════════════════════════════════════════════════════════════
    Level(id: 13, stageNumber: 5, targets: ['APPLE', 'BRAVE', 'CHESS'],
          gridSize: 6,
          starThreshold1: 470, starThreshold2: 940, starThreshold3: 1400),
    Level(id: 14, stageNumber: 5, targets: ['FLAME', 'GLOBE', 'HEART'],
          gridSize: 6,
          starThreshold1: 480, starThreshold2: 960, starThreshold3: 1440),
    Level(id: 15, stageNumber: 5, targets: ['LIGHT', 'MUSIC', 'NIGHT'],
          gridSize: 6,
          starThreshold1: 490, starThreshold2: 980, starThreshold3: 1470),

    // ════════════════════════════════════════════════════════════
    // STAGE 6 — 6-LETTER WORDS  (Levels 16–18)
    // ════════════════════════════════════════════════════════════
    Level(id: 16, stageNumber: 6, targets: ['CASTLE', 'FLOWER', 'JUNGLE'],
          gridSize: 6,
          starThreshold1: 560, starThreshold2: 1120, starThreshold3: 1680),
    Level(id: 17, stageNumber: 6, targets: ['BATTLE', 'GARDEN', 'MIRROR'],
          gridSize: 6,
          starThreshold1: 575, starThreshold2: 1150, starThreshold3: 1720),
    Level(id: 18, stageNumber: 6, targets: ['PENCIL', 'ROCKET', 'SILVER'],
          gridSize: 6,
          starThreshold1: 590, starThreshold2: 1180, starThreshold3: 1760),

    // ════════════════════════════════════════════════════════════
    // STAGE 7 — 7-LETTER WORDS  (Levels 19–21)
    // ════════════════════════════════════════════════════════════
    Level(id: 19, stageNumber: 7, targets: ['CHICKEN', 'LIBRARY', 'MONSTER'],
          gridSize: 7,
          starThreshold1: 650, starThreshold2: 1300, starThreshold3: 1950),
    Level(id: 20, stageNumber: 7, targets: ['CAPTAIN', 'FOREVER', 'MILLION'],
          gridSize: 7,
          starThreshold1: 665, starThreshold2: 1330, starThreshold3: 1995),
    Level(id: 21, stageNumber: 7, targets: ['PATTERN', 'SHELTER', 'THUNDER'],
          gridSize: 7,
          starThreshold1: 680, starThreshold2: 1360, starThreshold3: 2040),

    // ════════════════════════════════════════════════════════════
    // STAGE 8 — 8-LETTER WORDS  (Levels 22–24)
    // ════════════════════════════════════════════════════════════
    Level(id: 22, stageNumber: 8, targets: ['BIRTHDAY', 'COMPUTER', 'BACKYARD'],
          gridSize: 7,
          starThreshold1: 750, starThreshold2: 1500, starThreshold3: 2250),
    Level(id: 23, stageNumber: 8, targets: ['CHAMPION', 'ELEPHANT', 'THOUSAND'],
          gridSize: 7,
          starThreshold1: 765, starThreshold2: 1530, starThreshold3: 2295),
    Level(id: 24, stageNumber: 8, targets: ['FOOTBALL', 'GREATEST', 'HIGHLAND'],
          gridSize: 7,
          starThreshold1: 780, starThreshold2: 1560, starThreshold3: 2340),

    // ════════════════════════════════════════════════════════════
    // STAGE 9 — 9-LETTER WORDS  (Levels 25–27)
    // ════════════════════════════════════════════════════════════
    Level(id: 25, stageNumber: 9, targets: ['CHOCOLATE', 'BUTTERFLY', 'PINEAPPLE'],
          gridSize: 7,
          starThreshold1: 840, starThreshold2: 1680, starThreshold3: 2520),
    Level(id: 26, stageNumber: 9, targets: ['ADVENTURE', 'CAREFULLY', 'DANGEROUS'],
          gridSize: 7,
          starThreshold1: 860, starThreshold2: 1720, starThreshold3: 2580),
    Level(id: 27, stageNumber: 9, targets: ['YESTERDAY', 'BEAUTIFUL', 'BRILLIANT'],
          gridSize: 7,
          starThreshold1: 880, starThreshold2: 1760, starThreshold3: 2640),

    // ════════════════════════════════════════════════════════════
    // STAGE 10 — 10-LETTER WORDS  (Levels 28–30)
    // ════════════════════════════════════════════════════════════
    Level(id: 28, stageNumber: 10, targets: ['STRAWBERRY', 'BASKETBALL', 'WATERMELON'],
          gridSize: 8,
          starThreshold1: 950, starThreshold2: 1900, starThreshold3: 2850),
    Level(id: 29, stageNumber: 10, targets: ['ACCOMPLISH', 'BIRTHPLACE', 'CALCULATED'],
          gridSize: 8,
          starThreshold1: 975, starThreshold2: 1950, starThreshold3: 2925),
    Level(id: 30, stageNumber: 10, targets: ['EVERYTHING', 'FOUNDATION', 'GENERATION'],
          gridSize: 8,
          starThreshold1: 1000, starThreshold2: 2000, starThreshold3: 3000),

    // ════════════════════════════════════════════════════════════
    // STAGE 11 — COMPOUND WORDS  (Levels 31–33)
    // ════════════════════════════════════════════════════════════
    Level(id: 31, stageNumber: 11, targets: ['BEDROOM', 'SUNBURN', 'RAINBOW'],
          gridSize: 7,
          starThreshold1: 650, starThreshold2: 1300, starThreshold3: 1950),
    Level(id: 32, stageNumber: 11, targets: ['SUNSHINE', 'BIRTHDAY', 'BACKPACK'],
          gridSize: 7,
          starThreshold1: 780, starThreshold2: 1560, starThreshold3: 2340),
    Level(id: 33, stageNumber: 11, targets: ['CLASSROOM', 'BREAKFAST', 'AFTERNOON'],
          gridSize: 7,
          starThreshold1: 860, starThreshold2: 1720, starThreshold3: 2580),

    // ════════════════════════════════════════════════════════════
    // STAGE 12 — TECH & CODE WORDS  (Levels 34–36)
    // ════════════════════════════════════════════════════════════
    Level(id: 34, stageNumber: 12, targets: ['PIXEL', 'BYTES', 'CACHE'],
          gridSize: 6,
          starThreshold1: 490, starThreshold2: 980, starThreshold3: 1470),
    Level(id: 35, stageNumber: 12, targets: ['SYSTEM', 'SCREEN', 'ONLINE'],
          gridSize: 6,
          starThreshold1: 590, starThreshold2: 1180, starThreshold3: 1760),
    Level(id: 36, stageNumber: 12, targets: ['NETWORK', 'BROWSER', 'PROGRAM'],
          gridSize: 7,
          starThreshold1: 680, starThreshold2: 1360, starThreshold3: 2040),

    // ════════════════════════════════════════════════════════════
    // STAGE 13 — SCIENCE TERMS  (Levels 37–39)
    // ════════════════════════════════════════════════════════════
    Level(id: 37, stageNumber: 13, targets: ['ATOM', 'CELL', 'GENE'],
          gridSize: 6,
          starThreshold1: 400, starThreshold2: 790, starThreshold3: 1180),
    Level(id: 38, stageNumber: 13, targets: ['ENERGY', 'FUSION', 'PROTON'],
          gridSize: 6,
          starThreshold1: 590, starThreshold2: 1180, starThreshold3: 1760),
    Level(id: 39, stageNumber: 13, targets: ['QUANTUM', 'GRAVITY', 'NUCLEUS'],
          gridSize: 7,
          starThreshold1: 680, starThreshold2: 1360, starThreshold3: 2040),

    // ════════════════════════════════════════════════════════════
    // STAGE 14 — GEOGRAPHY  (Levels 40–42)
    // ════════════════════════════════════════════════════════════
    Level(id: 40, stageNumber: 14, targets: ['CHINA', 'JAPAN', 'INDIA'],
          gridSize: 6,
          starThreshold1: 490, starThreshold2: 980, starThreshold3: 1470),
    Level(id: 41, stageNumber: 14, targets: ['FRANCE', 'BRAZIL', 'MEXICO'],
          gridSize: 6,
          starThreshold1: 590, starThreshold2: 1180, starThreshold3: 1760),
    Level(id: 42, stageNumber: 14, targets: ['ENGLAND', 'NIGERIA', 'GERMANY'],
          gridSize: 7,
          starThreshold1: 680, starThreshold2: 1360, starThreshold3: 2040),

    // ════════════════════════════════════════════════════════════
    // STAGE 15 — NATURE & ANIMALS  (Levels 43–45)
    // ════════════════════════════════════════════════════════════
    Level(id: 43, stageNumber: 15, targets: ['FOREST', 'DESERT', 'CANYON'],
          gridSize: 6,
          starThreshold1: 590, starThreshold2: 1180, starThreshold3: 1760),
    Level(id: 44, stageNumber: 15, targets: ['OCTOPUS', 'LEOPARD', 'PENGUIN'],
          gridSize: 7,
          starThreshold1: 680, starThreshold2: 1360, starThreshold3: 2040),
    Level(id: 45, stageNumber: 15, targets: ['ELEPHANT', 'DOLPHINS', 'FLAMINGO'],
          gridSize: 7,
          starThreshold1: 780, starThreshold2: 1560, starThreshold3: 2340),

    // ════════════════════════════════════════════════════════════
    // STAGE 16 — BODY & MIND  (Levels 46–48)
    // ════════════════════════════════════════════════════════════
    Level(id: 46, stageNumber: 16, targets: ['HEART', 'BRAIN', 'SPINE'],
          gridSize: 6,
          starThreshold1: 490, starThreshold2: 980, starThreshold3: 1470),
    Level(id: 47, stageNumber: 16, targets: ['STOMACH', 'EYEBROW', 'FINGERS'],
          gridSize: 7,
          starThreshold1: 680, starThreshold2: 1360, starThreshold3: 2040),
    Level(id: 48, stageNumber: 16, targets: ['SKELETON', 'MOLECULE', 'MEMBRANE'],
          gridSize: 7,
          starThreshold1: 780, starThreshold2: 1560, starThreshold3: 2340),

    // ════════════════════════════════════════════════════════════
    // STAGE 17 — GRAND MASTER  (Levels 49–50)
    // ════════════════════════════════════════════════════════════
    Level(id: 49, stageNumber: 17, targets: ['ACCOMPLISH', 'BIRTHRIGHT', 'CALCULATED'],
          gridSize: 8,
          starThreshold1: 975, starThreshold2: 1950, starThreshold3: 2925),
    Level(id: 50, stageNumber: 17, targets: ['UNDERSTAND', 'EVERYWHERE', 'FRIENDSHIP'],
          gridSize: 8,
          starThreshold1: 1000, starThreshold2: 2000, starThreshold3: 3000),
  ];
}
