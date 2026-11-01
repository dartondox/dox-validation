import 'dart:convert';

import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/message_resolver.dart';
import '../core/rule.dart';
import '../core/sentinels.dart';
import '../dto/dto_annotations.dart';

// These rules have `const` constructors, so each one works two ways:
// - as a DTO annotation: `@Json()`, `@Same('password')`
// - in a fluent schema: `v.string().json()`, `v.string().same('password')`

/// The value must equal the key [other] in the same object:
/// `@Same('password')`. Laravel `same`.
///
/// It compares with the raw input of [other]. Text and numbers match by
/// text, so `5` matches `'5'` (form data).
class Same<T> extends Rule<T> {
  const Same(this.other, {super.message});

  /// A key in the same object.
  final String other;

  @override
  String get name {
    return IssueCodes.same;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.same;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'other': other};
  }

  @override
  bool check(T value, RuleContext context) {
    return matches(value, context.sibling(other));
  }

  /// `true` when [value] equals the raw input [other].
  static bool matches(Object? value, Object? other) {
    if (other is List && value is! List) {
      // text input: a key that came many times, the last one is used
      other = other.isEmpty ? undefined : other.last;
    }
    if (other is Undefined) return false;
    if (value == other) return true;
    return other is String && value is! String && '$value' == other;
  }
}

/// The key `<field>_confirmation` must have the same value:
/// `@Confirmed()` on `password` needs `password_confirmation`.
/// Laravel `confirmed`. Give [other] to use another key.
///
/// The error is on this field, not on the confirmation key.
class Confirmed<T> extends Rule<T> {
  const Confirmed({this.other, super.message});

  /// The key to compare with. Default: `<field>_confirmation`.
  final String? other;

  @override
  String get name {
    return IssueCodes.confirmed;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.confirmed;
  }

  @override
  bool check(T value, RuleContext context) {
    String key = other ?? '${context.field}_confirmation';
    return Same.matches(value, context.sibling(key));
  }
}

/// The text must be valid JSON: `@Json()`. Laravel `json`.
class Json extends Rule<String> {
  const Json({super.message});

  @override
  String get name {
    return IssueCodes.json;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.json;
  }

  @override
  bool check(String value, RuleContext context) {
    try {
      jsonDecode(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'contentMediaType': 'application/json'};
  }
}

final RegExp _digits = RegExp(r'^[0-9]+$');

/// The text must be only digits (0-9), exactly [length] of them:
/// `@Digits(6)`. Laravel `digits`. Use a `String` field, so leading
/// zeros are kept.
class Digits extends Rule<String> {
  const Digits(this.length, {super.message});

  final int length;

  @override
  String get name {
    return IssueCodes.digits;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.digits;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'digits': length};
  }

  @override
  bool check(String value, RuleContext context) {
    return value.length == length && _digits.hasMatch(value);
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'pattern': '^[0-9]{$length}\$'};
  }
}

/// The text must be only digits (0-9), from [min] to [max] of them:
/// `@DigitsBetween(4, 6)`. Laravel `digits_between`.
class DigitsBetween extends Rule<String> {
  const DigitsBetween(this.min, this.max, {super.message});

  final int min;
  final int max;

  @override
  String get name {
    return IssueCodes.digitsBetween;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.digitsBetween;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'min': min, 'max': max};
  }

  @override
  bool check(String value, RuleContext context) {
    return value.length >= min &&
        value.length <= max &&
        _digits.hasMatch(value);
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'pattern': '^[0-9]{$min,$max}\$'};
  }
}

/// The text must be a real date in [format]: `@DateFormatted('Y-m-d')`.
/// Laravel `date_format`. (Not named `DateFormat`, so it does not clash
/// with `package:intl`.)
///
/// Format letters, like PHP:
/// - `Y` year (4 digits), `y` year (2 digits)
/// - `m` month (01-12), `n` month (1-12)
/// - `d` day (01-31), `j` day (1-31)
/// - `H` hour (00-23), `G` hour (0-23)
/// - `i` minutes (00-59), `s` seconds (00-59)
/// - `v` milliseconds (3 digits), `u` microseconds (6 digits)
/// - `P` time zone like `+07:00`, `O` time zone like `+0700`
///
/// Put `\` before a letter to use it as text. Every other character must
/// be there as it is. The date must exist: `2024-02-30` fails.
class DateFormatted extends Rule<String> {
  const DateFormatted(this.format, {super.message});

  final String format;

  @override
  String get name {
    return IssueCodes.dateFormat;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.dateFormat;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'format': format};
  }

  @override
  bool check(String value, RuleContext context) {
    return matches(value, format);
  }

  static const Map<String, String> _parts = <String, String>{
    'Y': r'(\d{4})',
    'y': r'(\d{2})',
    'm': r'(\d{2})',
    'n': r'(\d{1,2})',
    'd': r'(\d{2})',
    'j': r'(\d{1,2})',
    'H': r'(\d{2})',
    'G': r'(\d{1,2})',
    'i': r'(\d{2})',
    's': r'(\d{2})',
    'v': r'(\d{3})',
    'u': r'(\d{6})',
    'P': r'([+-](?:[01]\d|2[0-3]):[0-5]\d)',
    'O': r'([+-](?:[01]\d|2[0-3])[0-5]\d)',
  };

  /// `true` when [value] is a real date in [format].
  static bool matches(String value, String format) {
    StringBuffer pattern = StringBuffer('^');
    List<String> letters = <String>[];
    for (int i = 0; i < format.length; i++) {
      String char = format[i];
      if (char == r'\' && i + 1 < format.length) {
        i++;
        pattern.write(RegExp.escape(format[i]));
        continue;
      }
      String? part = _parts[char];
      if (part == null) {
        pattern.write(RegExp.escape(char));
        continue;
      }
      pattern.write(part);
      letters.add(char);
    }
    pattern.write(r'$');
    RegExpMatch? match = RegExp(pattern.toString()).firstMatch(value);
    if (match == null) return false;
    Map<String, int> found = <String, int>{};
    for (int i = 0; i < letters.length; i++) {
      String letter = letters[i];
      int? number = int.tryParse(match[i + 1]!);
      if (number == null) continue; // a time zone
      // the same letter twice must have the same value
      if (found.containsKey(letter) && found[letter] != number) return false;
      found[letter] = number;
    }
    int year = found['Y'] ?? (found['y'] == null ? 2000 : 2000 + found['y']!);
    int month = found['m'] ?? found['n'] ?? 1;
    int day = found['d'] ?? found['j'] ?? 1;
    int hour = found['H'] ?? found['G'] ?? 0;
    if (month < 1 || month > 12 || day < 1 || hour > 23) return false;
    if ((found['i'] ?? 0) > 59 || (found['s'] ?? 0) > 59) return false;
    // DateTime moves Feb 30 to Mar 1, so check the day did not move
    return DateTime.utc(year, month, day).day == day;
  }
}

/// A strong password, like Laravel
/// `Password::min(8)->letters()->mixedCase()->numbers()->symbols()`:
///
/// ```dart
/// @Password(min: 8, mixedCase: true, numbers: true, symbols: true)
/// final String password;
///
/// v.string().password(min: 8, mixedCase: true, numbers: true)
/// ```
/// Letters, numbers and symbols use Unicode classes, so `é` is a letter.
/// It does not check leaked passwords (Laravel `uncompromised`).
class Password extends Rule<String> {
  const Password({
    this.min = 8,
    this.letters = false,
    this.mixedCase = false,
    this.numbers = false,
    this.symbols = false,
    super.message,
  });

  /// At least this many characters.
  final int min;

  /// At least one letter.
  final bool letters;

  /// At least one upper case and one lower case letter.
  final bool mixedCase;

  /// At least one number.
  final bool numbers;

  /// At least one symbol, like `!` or `@`.
  final bool symbols;

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _upper = RegExp(r'\p{Lu}', unicode: true);
  static final RegExp _lower = RegExp(r'\p{Ll}', unicode: true);
  static final RegExp _number = RegExp(r'\p{N}', unicode: true);
  static final RegExp _symbol = RegExp(r'[\p{Z}\p{S}\p{P}]', unicode: true);

  @override
  String get name {
    return IssueCodes.password;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.password;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{
      'min': min,
      'rules': ListText.joinWithAnd(<String>[
        'at least $min characters',
        if (mixedCase)
          'one upper case and one lower case letter'
        else if (letters)
          'one letter',
        if (numbers) 'one number',
        if (symbols) 'one symbol',
      ]),
    };
  }

  @override
  bool check(String value, RuleContext context) {
    if (value.runes.length < min) return false;
    if (letters && !_letter.hasMatch(value)) return false;
    if (mixedCase && !(_upper.hasMatch(value) && _lower.hasMatch(value))) {
      return false;
    }
    if (numbers && !_number.hasMatch(value)) return false;
    return !symbols || _symbol.hasMatch(value);
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'minLength': min};
  }
}

/// The issue of a failed [RequiredIf] or [RequiredWith]: code, default
/// message and params. DTOs and `.optional().requiredIf()` share it.
class RequiredWhenIssue {
  factory RequiredWhenIssue(RequiredWhen rule) {
    if (rule is RequiredIf) {
      return RequiredWhenIssue._(
        IssueCodes.requiredIf,
        DefaultMessages.requiredIf,
        <String, Object?>{
          'other': rule.other,
          'values': rule.values.join(' or '),
        },
      );
    }
    if (rule is RequiredWith) {
      return RequiredWhenIssue._(
        IssueCodes.requiredWith,
        DefaultMessages.requiredWith,
        <String, Object?>{'others': rule.others.join(' or ')},
      );
    }
    return RequiredWhenIssue._(
      IssueCodes.required,
      DefaultMessages.required,
      const <String, Object?>{},
    );
  }

  RequiredWhenIssue._(this.code, this.fallback, this.params);

  final String code;
  final String fallback;
  final Map<String, Object?> params;
}
