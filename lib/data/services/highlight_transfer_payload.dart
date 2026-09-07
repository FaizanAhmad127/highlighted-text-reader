import 'dart:math';

class HighlightTransferPayload {
  static const prefix = 'htr1:';
  static const idLength = 22;
  static const maxItems = 200;
  static const ttl = Duration(minutes: 30);
  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  static String encode(String transferId) => '$prefix$transferId';

  static String? tryParse(String raw) {
    final value = raw.trim();
    if (!value.startsWith(prefix)) return null;
    final id = value.substring(prefix.length);
    if (!_isValidId(id)) return null;
    return id;
  }

  static String newId([Random? random]) {
    final rand = random ?? Random.secure();
    return List.generate(
      idLength,
      (_) => _alphabet[rand.nextInt(_alphabet.length)],
    ).join();
  }

  static bool _isValidId(String id) {
    if (id.length != idLength) return false;
    return id.split('').every(_alphabet.contains);
  }
}
