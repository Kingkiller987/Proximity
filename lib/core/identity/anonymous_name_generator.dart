import 'dart:math' as math;

/// Generates collision-safe, immutable `AdjectiveNoun` anonymous handles
/// (e.g., `QuietFalcon`, `CosmicOtter`).
class AnonymousNameGenerator {
  const AnonymousNameGenerator._();

  static const List<String> adjectives = <String>[
    'Quiet',
    'Cosmic',
    'Misty',
    'Solar',
    'Velvet',
    'Swift',
    'Amber',
    'Lunar',
    'Cedar',
    'Frost',
    'Echo',
    'Cobalt',
    'Silver',
    'Crimson',
    'Golden',
    'Breezy',
    'Dusk',
    'Dawn',
    'Tidal',
    'Mossy',
    'Pine',
    'Cloudy',
    'Starry',
    'Hidden',
    'Wandering',
    'Serene',
    'Nimble',
    'Gentle',
    'Brisk',
    'Glacial',
    'Verdant',
    'Radiant',
  ];

  static const List<String> nouns = <String>[
    'Falcon',
    'Otter',
    'Heron',
    'Fox',
    'Owl',
    'Lynx',
    'Comet',
    'Sparrow',
    'Harbor',
    'Quartz',
    'Raven',
    'Badger',
    'Finch',
    'Crane',
    'Wolf',
    'Deer',
    'Kestrel',
    'Seal',
    'Robin',
    'Wren',
    'Coyote',
    'Osprey',
    'Puffin',
    'Marten',
    'Beacon',
    'Willow',
    'Cypress',
    'Glacier',
    'Canyon',
    'Meadow',
    'Ridge',
    'Brook',
  ];

  static final RegExp _handlePattern = RegExp(
    r'^[A-Z][a-z]+[A-Z][a-z]+(\d{3})?$',
  );

  static String _capitalize(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }

  static bool isValidHandle(String candidate) {
    final trimmed = candidate.trim();
    if (!_handlePattern.hasMatch(trimmed)) return false;
    final match = RegExp(r'^([A-Z][a-z]+)([A-Z][a-z]+)(\d{3})?$')
        .firstMatch(trimmed);
    if (match == null) return false;
    final adj = match.group(1)!;
    final noun = match.group(2)!;
    final normalizedAdjs = adjectives.map(_capitalize).toSet();
    final normalizedNouns = nouns.map(_capitalize).toSet();
    return normalizedAdjs.contains(adj) && normalizedNouns.contains(noun);
  }

  /// Generates a unique `AdjectiveNoun` handle not present in `existingHandles`.
  /// If all tried base combinations are already taken, appends a collision-safe
  /// 3-digit numeric suffix (`100..999`, e.g., `QuietFalcon482`).
  static String generate({required Set<String> existingHandles, int? seed}) {
    final rng = seed != null ? math.Random(seed) : math.Random.secure();
    final adjList = adjectives.map(_capitalize).toList(growable: false);
    final nounList = nouns.map(_capitalize).toList(growable: false);

    // 1. Try up to 32 random base AdjectiveNoun candidates
    for (var i = 0; i < 32; i++) {
      final adj = adjList[rng.nextInt(adjList.length)];
      final noun = nounList[rng.nextInt(nounList.length)];
      final candidate = '$adj$noun';
      if (!existingHandles.contains(candidate)) {
        return candidate;
      }
    }

    // 2. Deterministic scan of remaining base combinations starting from random offset
    final totalBase = adjList.length * nounList.length;
    final startIdx = rng.nextInt(totalBase);
    for (var offset = 0; offset < totalBase; offset++) {
      final idx = (startIdx + offset) % totalBase;
      final adj = adjList[idx ~/ nounList.length];
      final noun = nounList[idx % nounList.length];
      final candidate = '$adj$noun';
      if (!existingHandles.contains(candidate)) {
        return candidate;
      }
    }

    // 3. Base pool saturated: append 3-digit non-colliding suffix (100..999)
    final baseAdj = adjList[rng.nextInt(adjList.length)];
    final baseNoun = nounList[rng.nextInt(nounList.length)];
    final startSuffix = 100 + rng.nextInt(900);
    for (var offset = 0; offset < 900; offset++) {
      final suffix = 100 + ((startSuffix - 100 + offset) % 900);
      final candidate = '$baseAdj$baseNoun$suffix';
      if (!existingHandles.contains(candidate)) {
        return candidate;
      }
    }

    throw StateError('Unable to allocate unique anonymous handle.');
  }
}
