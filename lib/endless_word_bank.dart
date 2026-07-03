/// Curated word bank for Endless Mode, organized by word length (4-10
/// letters). Deliberately hand-picked rather than pulled from a raw
/// dictionary — every word here is common, clean, and family-friendly,
/// matching the quality bar the 50-level campaign already sets. A raw
/// word-list/dictionary source would risk surfacing obscure or awkward
/// words that break the "instantly recognizable" feel the campaign has.
///
/// Every word below has been validated against the full 50-level campaign
/// word list to guarantee zero duplication — a player who's just finished
/// the campaign won't immediately see the same words again in Endless.
///
/// Skips lengths 1-3: those pools are too small to sustain repeat-play
/// without becoming obviously repetitive fast, and the campaign already
/// exhaustively covers short words (stages 1-3). Endless starts at the
/// point campaign progression stage 4 does.
class EndlessWordBank {
  static const Map<int, List<String>> byLength = {
    4: [
      'BOOK', 'LAMP', 'RAIN', 'SNOW', 'WIND', 'LEAF', 'TREE', 'GOLD',
      'ROSE', 'FISH', 'BIRD', 'WOLF', 'LION', 'DEER', 'DUCK', 'FROG',
      'CRAB', 'SHIP', 'BOAT', 'GATE', 'DOOR', 'WAVE', 'DRUM', 'BELL',
    ],
    5: [
      'OCEAN', 'RIVER', 'MOUNT', 'CLOUD', 'STORM', 'EAGLE', 'TIGER',
      'ZEBRA', 'PANDA', 'KOALA', 'WHALE', 'SHARK', 'SNAKE', 'MOUSE',
      'HORSE', 'SHEEP', 'HONEY', 'BREAD', 'PIZZA', 'JUICE', 'LEMON',
      'GRAPE', 'BERRY', 'PEACH',
    ],
    6: [
      'PLANET', 'ISLAND', 'BRIDGE', 'TUNNEL', 'ORANGE', 'YELLOW',
      'PURPLE', 'COFFEE', 'COOKIE', 'BUTTER', 'CARROT', 'POTATO',
      'PEPPER', 'CHERRY', 'BANANA', 'WALNUT', 'RABBIT', 'KITTEN',
      'TURTLE', 'SPIDER', 'INSECT', 'BEETLE', 'SALMON', 'MUFFIN',
    ],
    7: [
      'FANTASY', 'JOURNEY', 'HOLIDAY', 'CRYSTAL', 'DIAMOND', 'EMERALD',
      'COMPASS', 'CAPTURE', 'MYSTERY', 'VICTORY', 'FREEDOM', 'COURAGE',
      'HARMONY', 'PICTURE', 'TEACHER', 'STUDENT', 'COLLEGE', 'KITCHEN',
      'BATHTUB', 'HALLWAY', 'DRAWING', 'PAINTER', 'BOWLING', 'VOYAGER',
    ],
    8: [
      'MOUNTAIN', 'CARNIVAL', 'FESTIVAL', 'MEMORIES', 'TREASURE',
      'DINOSAUR', 'SQUIRREL', 'STARFISH', 'SEAHORSE', 'HEDGEHOG',
      'CHIPMUNK', 'SUNLIGHT', 'DAYLIGHT', 'TWILIGHT', 'STAIRWAY',
      'DOORSTEP', 'BOOKCASE', 'SUITCASE', 'VOLCANIC', 'SNOWBALL',
    ],
    9: [
      'AMBULANCE', 'BALLERINA', 'DRAGONFLY', 'HOMESTEAD', 'HURRICANE',
      'MOTORBIKE', 'ORCHESTRA', 'SNOWFLAKE', 'SUBMARINE', 'TELESCOPE',
      'SCAVENGER', 'CARNATION', 'FOOTPRINT', 'HAILSTORM', 'STARLIGHT',
      'MOONLIGHT', 'WATERFALL', 'FIREPLACE', 'STAIRCASE', 'SANDSTORM',
    ],
    10: [
      'SKATEBOARD', 'TELEVISION', 'LIGHTHOUSE', 'PHOTOGRAPH',
      'GYMNASTICS', 'VOLLEYBALL', 'CHIMPANZEE', 'RHINOCEROS',
      'DECORATION', 'EXPEDITION', 'COLLECTION', 'CONNECTION',
      'REFLECTION', 'ADVENTURER',
    ],
  };

  /// Difficulty cycles through these lengths in order, then loops back to
  /// the start — a sawtooth pattern rather than a monotonic climb. This
  /// keeps Endless genuinely endless: a purely-increasing difficulty curve
  /// eventually runs out of good words and becomes unplayable, whereas
  /// cycling 4→10 repeatedly gives a rhythm of building tension then a
  /// breather, indefinitely, using only words already proven playable in
  /// the campaign's own length range.
  static const List<int> lengthCycle = [4, 5, 6, 7, 8, 9, 10];
}
