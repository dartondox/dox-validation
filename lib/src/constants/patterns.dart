import '../validator.dart';

/// Regular expressions shared by string rules.
class Patterns {
  /// The local part allows the same symbols as HTML5 (`+`, `'` and more),
  /// split by single dots. Each dot ends a group, so there is no ReDoS.
  static final RegExp email = RegExp(
    r"^[\w!#$%&'*+/=?^`{|}~-]+(\.[\w!#$%&'*+/=?^`{|}~-]+)*@"
    r'[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*(\.[a-zA-Z]{2,})$',
  );
  static final RegExp uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// No leading zeros (`01.1.1.1` fails), like Laravel. Some tools read
  /// `010` as octal (8), so the address would not be what it looks like.
  static final RegExp ipv4 = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$',
  );

  /// Only letters. `a-z` and `A-Z`, or Unicode letters and marks when
  /// `ValidationFlags.unicodeAlpha` is on.
  static RegExp get alpha {
    return Validator.flags.unicodeAlpha ? _unicodeAlpha : _asciiAlpha;
  }

  /// Letters, digits, `_` and `-`. Unicode letters, marks and digits when
  /// `ValidationFlags.unicodeAlpha` is on.
  static RegExp get alphaDash {
    return Validator.flags.unicodeAlpha ? _unicodeAlphaDash : _asciiAlphaDash;
  }

  /// Letters and digits. Unicode letters, marks and digits when
  /// `ValidationFlags.unicodeAlpha` is on.
  static RegExp get alphaNumeric {
    return Validator.flags.unicodeAlpha
        ? _unicodeAlphaNumeric
        : _asciiAlphaNumeric;
  }

  static final RegExp _asciiAlpha = RegExp(r'^[a-zA-Z]+$');
  static final RegExp _asciiAlphaDash = RegExp(r'^[a-zA-Z0-9_-]+$');
  static final RegExp _asciiAlphaNumeric = RegExp(r'^[a-zA-Z0-9]+$');
  static final RegExp _unicodeAlpha = RegExp(r'^[\p{L}\p{M}]+$', unicode: true);
  static final RegExp _unicodeAlphaDash = RegExp(
    r'^[\p{L}\p{M}\p{N}_-]+$',
    unicode: true,
  );
  static final RegExp _unicodeAlphaNumeric = RegExp(
    r'^[\p{L}\p{M}\p{N}]+$',
    unicode: true,
  );

  /// ISO 8601 date time, like `2024-01-31T10:00:00Z`.
  static final RegExp isoDateTime = RegExp(
    r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$',
  );
}
