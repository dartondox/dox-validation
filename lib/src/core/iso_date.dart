/// Reads ISO 8601 text without the "roll over" of `DateTime.tryParse`.
class IsoDate {
  const IsoDate._();

  static final RegExp _parts = RegExp(
    r'^([+-]?\d{4,6})-?(\d{2})-?(\d{2})(?:[ Tt](\d{2})(?::?(\d{2})(?::?(\d{2}))?)?)?',
  );

  /// Like `DateTime.tryParse`, but `null` when a written part is out of
  /// range. `2024-02-31` and `10:61` are `null`, not a later date.
  static DateTime? parse(String text) {
    RegExpMatch? match = _parts.firstMatch(text);
    if (match != null && !_inRange(match)) return null;
    return DateTime.tryParse(text);
  }

  static bool _inRange(RegExpMatch match) {
    int year = int.parse(match[1]!);
    int month = int.parse(match[2]!);
    int day = int.parse(match[3]!);
    if (month < 1 || month > 12) return false;
    // Day 0 of the next month is the last day of this month.
    if (day < 1 || day > DateTime.utc(year, month + 1, 0).day) return false;
    return _atMost(match[4], 23) &&
        _atMost(match[5], 59) &&
        _atMost(match[6], 59);
  }

  static bool _atMost(String? part, int max) {
    return part == null || int.parse(part) <= max;
  }
}
