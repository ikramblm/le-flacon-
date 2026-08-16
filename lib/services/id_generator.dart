import 'dart:math';

/// Produces short hex ids similar in shape to AppSheet's UNIQUEID(),
/// e.g. "188374ea" — used for tables whose source ID column was text/auto.
class IdGenerator {
  static final Random _rand = Random();

  static String shortHex([int length = 8]) {
    const chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[_rand.nextInt(chars.length)]).join();
  }
}
