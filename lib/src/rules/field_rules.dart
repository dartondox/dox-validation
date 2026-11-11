import 'dart:convert';

import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/data_path.dart';
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
/// It compares the raw input of both keys, like Laravel. So a change
/// like `trim()` does not count: `' ab '` matches `' ab '`. Text matches
/// a number or a bool by text, both ways: `1234` matches `'1234'`.
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
    return matches(rawOf(context), context.sibling(other));
  }

  /// The raw input of the value being checked.
  static Object? rawOf(RuleContext context) {
    return DataPath.read(context.root, context.path);
  }

  /// `true` when the raw inputs [a] and [b] are the same.
  static bool matches(Object? a, Object? b) {
    a = _one(a, b);
    b = _one(b, a);
    if (a is Undefined || b is Undefined) return false;
    if (a == b) return true;
    if (a is String && (b is num || b is bool)) return a == '$b';
    if (b is String && (a is num || a is bool)) return b == '$a';
    return false;
  }

  /// Text input: a key that came many times is a list, and the last one
  /// is used. Only when the other side is not a list.
  static Object? _one(Object? value, Object? other) {
    if (value is List && other is! List) {
      return value.isEmpty ? undefined : value.last;
    }
    return value;
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
    return Same.matches(Same.rawOf(context), context.sibling(key));
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

final RegExp _hexColor = RegExp(r'^#[0-9a-fA-F]{6}$');
final RegExp _hexColorShort = RegExp(r'^#[0-9a-fA-F]{3}$');

/// The text must be a hex color: `#` and 6 hex digits, like `#1a2b3c`.
/// Both cases pass. `@HexColor(short: true)` also takes 3 digits (`#abc`).
/// Laravel `hex_color` takes 3, 4, 6 or 8 digits; this rule is stricter
/// on purpose, because most apps store `#rrggbb`.
class HexColor extends Rule<String> {
  const HexColor({this.short = false, super.message});

  /// `true`: `#abc` passes too.
  final bool short;

  @override
  String get name {
    return IssueCodes.hexColor;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.hexColor;
  }

  @override
  bool check(String value, RuleContext context) {
    return _hexColor.hasMatch(value) ||
        (short && _hexColorShort.hasMatch(value));
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'pattern': short
          ? r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$'
          : r'^#[0-9a-fA-F]{6}$',
    };
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
/// Format letters, like PHP `date()`:
/// - day: `d` (01-31), `j` (1-31), `D` (Mon), `l` (Monday), `N` (1-7,
///   Monday is 1), `w` (0-6, Sunday is 0), `S` (st, nd, rd, th),
///   `z` (day of the year, 0-365)
/// - month: `m` (01-12), `n` (1-12), `M` (Jan), `F` (January),
///   `t` (days in the month)
/// - year: `Y` (4 digits), `y` (2 digits), `L` (1 in a leap year, else 0)
/// - time: `a` (am, pm), `A` (AM, PM), `g` (1-12), `h` (01-12),
///   `G` (0-23), `H` (00-23), `i` (00-59), `s` (00-59), `v` (3 digit
///   milliseconds), `u` (6 digit microseconds)
/// - time zone: `e` (`Asia/Bangkok`), `T` (`UTC`, `+07`), `P` (`+07:00`),
///   `p` (`Z` or `+07:00`), `O` (`+0700`), `Z` (offset in seconds),
///   `I` (0 or 1)
/// - full: `U` (seconds since 1970), `c` (`Y-m-d\TH:i:sP`),
///   `r` (`D, d M Y H:i:s O`)
///
/// `j`, `n`, `g`, `G`, `z` and `U` take no leading zero, like Laravel:
/// `j/n/Y` rejects `01/02/2024`. `e` and `T` take any name that looks
/// like a time zone; they do not check that it is a real one.
///
/// Put `\` before a letter to use it as text. Any other letter throws an
/// [ArgumentError]. Every other character must be there as it is.
/// The date must exist (`2023-02-29` fails). Names must have the case
/// above. Day names, `S`, `z`, `t` and `L` must fit the date.
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

  static const List<String> _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const String _offset = r'[+-](?:[01]\d|2[0-3]):?[0-5]\d';

  static final Map<String, String> _parts = <String, String>{
    'd': r'(\d{2})',
    'j': r'([1-9]\d?)',
    'D': '(${_days.map(_short).join('|')})',
    'l': '(${_days.join('|')})',
    'N': '([1-7])',
    'w': '([0-6])',
    'S': '(st|nd|rd|th)',
    'z': r'(0|[1-9]\d{0,2})',
    'm': r'(\d{2})',
    'n': r'([1-9]\d?)',
    'M': '(${_months.map(_short).join('|')})',
    'F': '(${_months.join('|')})',
    't': r'(\d{2})',
    'Y': r'(\d{4})',
    'y': r'(\d{2})',
    'L': '([01])',
    'a': '(am|pm)',
    'A': '(AM|PM)',
    'g': r'([1-9]\d?)',
    'h': r'(\d{2})',
    'G': r'(\d|1\d|2[0-3])',
    'H': r'(\d{2})',
    'i': r'(\d{2})',
    's': r'(\d{2})',
    'v': r'(\d{3})',
    'u': r'(\d{6})',
    'e': r'([A-Za-z_]+(?:/[A-Za-z0-9_+-]+)*)',
    'T': '([A-Z]{1,5}|$_offset)',
    'P': '([+-](?:[01]\\d|2[0-3]):[0-5]\\d)',
    'p': '(Z|[+-](?:[01]\\d|2[0-3]):[0-5]\\d)',
    'O': '([+-](?:[01]\\d|2[0-3])[0-5]\\d)',
    'Z': r'(-?\d{1,5})',
    'I': '([01])',
    'U': r'(-?(?:0|[1-9]\d*))',
  };

  static const Map<String, String> _full = <String, String>{
    'c': r'Y-m-d\TH:i:sP',
    'r': 'D, d M Y H:i:s O',
  };

  static String _short(String name) {
    return name.substring(0, 3);
  }

  /// Throws an [ArgumentError] when [format] has a letter that is not
  /// supported (and not escaped with `\`).
  static void checkFormat(String format) {
    _compiled(format);
  }

  // ponytail: no limit, formats come from code, not from input
  static final Map<String, (RegExp, List<String>)> _cache =
      <String, (RegExp, List<String>)>{};

  static final RegExp _letter = RegExp('[a-zA-Z]');

  static (RegExp, List<String>) _compiled(String format) {
    return _cache[format] ??= _compile(format);
  }

  /// The regex for [format], and the letter of each group.
  static (RegExp, List<String>) _compile(String format) {
    StringBuffer pattern = StringBuffer('^');
    List<String> letters = <String>[];
    void add(String text) {
      for (int i = 0; i < text.length; i++) {
        String char = text[i];
        if (char == r'\' && i + 1 < text.length) {
          i++;
          pattern.write(RegExp.escape(text[i]));
          continue;
        }
        String? full = _full[char];
        if (full != null) {
          add(full);
          continue;
        }
        String? part = _parts[char];
        if (part != null) {
          pattern.write(part);
          letters.add(char);
          continue;
        }
        if (_letter.hasMatch(char)) {
          throw ArgumentError.value(
            format,
            'format',
            'The letter "$char" is not supported. Put \\ before it to use '
                'it as text',
          );
        }
        pattern.write(RegExp.escape(char));
      }
    }

    add(format);
    pattern.write(r'$');
    return (RegExp(pattern.toString()), letters);
  }

  /// `true` when [value] is a real date in [format].
  static bool matches(String value, String format) {
    (RegExp, List<String>) compiled = _compiled(format);
    List<String> letters = compiled.$2;
    RegExpMatch? match = compiled.$1.firstMatch(value);
    if (match == null) return false;
    Map<String, String> found = <String, String>{};
    for (int i = 0; i < letters.length; i++) {
      String letter = letters[i];
      String text = match[i + 1]!;
      // the same letter twice must have the same value
      if (found.containsKey(letter) && found[letter] != text) return false;
      found[letter] = text;
    }
    return _real(found);
  }

  static int? _number(Map<String, String> found, String letter) {
    String? text = found[letter];
    return text == null ? null : int.parse(text);
  }

  /// Two ways to give one part (like `m` and `M`) must agree.
  static int? _one(List<int?> values, void Function() conflict) {
    int? result;
    for (int? value in values) {
      if (value == null) continue;
      if (result != null && result != value) conflict();
      result = value;
    }
    return result;
  }

  static bool _real(Map<String, String> found) {
    bool ok = true;
    void conflict() {
      ok = false;
    }

    int? shortYear = _number(found, 'y');
    int? year = _one(<int?>[
      _number(found, 'Y'),
      if (shortYear != null)
        shortYear < 70 ? 2000 + shortYear : 1900 + shortYear,
    ], conflict);
    int? month = _one(<int?>[
      _number(found, 'm'),
      _number(found, 'n'),
      if (found['F'] != null) _months.indexOf(found['F']!) + 1,
      if (found['M'] != null)
        _months.map(_short).toList().indexOf(found['M']!) + 1,
    ], conflict);
    int? day = _one(<int?>[_number(found, 'd'), _number(found, 'j')], conflict);
    String? half = (found['a'] ?? found['A'])?.toLowerCase();
    if (found['a'] != null && found['A'] != null) {
      if (found['a'] != found['A']!.toLowerCase()) return false;
    }
    int? hour12 = _one(<int?>[
      _number(found, 'g'),
      _number(found, 'h'),
    ], conflict);
    int? hour = _one(<int?>[
      _number(found, 'G'),
      _number(found, 'H'),
      if (hour12 != null && half != null) hour12 % 12 + (half == 'pm' ? 12 : 0),
    ], conflict);
    if (!ok) return false;
    if (hour12 != null && (hour12 < 1 || hour12 > 12)) return false;
    if (hour != null && hour > 23) return false;
    if ((_number(found, 'i') ?? 0) > 59 || (_number(found, 's') ?? 0) > 59) {
      return false;
    }
    if (month != null && (month < 1 || month > 12)) return false;
    int y = year ?? 2000; // a leap year, so 29 Feb passes without a year
    int m = month ?? 1;
    int lastDay = DateTime.utc(y, m + 1, 0).day;
    if (day != null && (day < 1 || day > lastDay)) return false;
    bool leap = DateTime.utc(y, 2, 29).day == 29;
    if (year != null &&
        found['L'] != null &&
        found['L'] != (leap ? '1' : '0')) {
      return false;
    }
    int? days = _number(found, 't');
    if (days != null) {
      if (month == null ? (days < 28 || days > 31) : days != lastDay) {
        return false;
      }
    }
    int? dayOfYear = _number(found, 'z');
    if (dayOfYear != null) {
      if (dayOfYear > (leap ? 365 : 364)) return false;
      if (month != null && day != null) {
        int real = DateTime.utc(y, m, day).difference(DateTime.utc(y)).inDays;
        if (real != dayOfYear) return false;
      }
    }
    if (day == null) return true;
    String? suffix = found['S'];
    if (suffix != null && suffix != _suffix(day)) return false;
    if (year == null || month == null) return true;
    int weekday = DateTime.utc(y, m, day).weekday; // 1 = Monday
    String dayName = _days[weekday - 1];
    if (found['l'] != null && found['l'] != dayName) return false;
    if (found['D'] != null && found['D'] != _short(dayName)) return false;
    if (found['N'] != null && found['N'] != '$weekday') return false;
    if (found['w'] != null && found['w'] != '${weekday % 7}') return false;
    return true;
  }

  static String _suffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    return switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
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
      'rules': _join(<String>[
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

  /// `a and b` for two items, `a, b, and c` for more.
  static String _join(List<String> items) {
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return ListText.joinWithAnd(items);
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
          'values': <Object?>[
            for (Object? value in rule.values)
              value is Enum ? value.name : value,
          ].join(' or '),
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
    if (rule is RequiredUnless) {
      return RequiredWhenIssue._(
        IssueCodes.requiredUnless,
        DefaultMessages.requiredUnless,
        <String, Object?>{
          'other': rule.other,
          'values': _names(rule.values).join(' or '),
        },
      );
    }
    if (rule is RequiredWithout) {
      return RequiredWhenIssue._(
        IssueCodes.requiredWithout,
        DefaultMessages.requiredWithout,
        <String, Object?>{'others': rule.others.join(' or ')},
      );
    }
    if (rule is RequiredWithoutAll) {
      return RequiredWhenIssue._(
        IssueCodes.requiredWithoutAll,
        DefaultMessages.requiredWithoutAll,
        <String, Object?>{'others': rule.others.join(' or ')},
      );
    }
    if (rule is Filled) {
      return RequiredWhenIssue._(
        IssueCodes.filled,
        DefaultMessages.filled,
        const <String, Object?>{},
      );
    }
    if (rule is Present) {
      return RequiredWhenIssue._(
        IssueCodes.present,
        DefaultMessages.present,
        const <String, Object?>{},
      );
    }
    return RequiredWhenIssue._(
      IssueCodes.required,
      DefaultMessages.required,
      const <String, Object?>{},
    );
  }

  RequiredWhenIssue._(this.code, this.fallback, this.params);

  /// Each value as text: an enum value gives its name.
  static List<Object?> _names(List<Object?> values) {
    return <Object?>[
      for (Object? value in values) value is Enum ? value.name : value,
    ];
  }

  final String code;
  final String fallback;
  final Map<String, Object?> params;
}

/// The value must be `true`, `1`, `'1'`, `'true'`, `'yes'` or `'on'`:
/// `@Accepted()`. Laravel `accepted`. For a "terms" check box. Use it on
/// a `bool` field with no default, so a missing value fails too.
class Accepted<T> extends Rule<T> {
  const Accepted({super.message});

  static const List<Object> _words = <Object>[
    true,
    1,
    '1',
    'true',
    'yes',
    'on',
  ];

  @override
  String get name {
    return IssueCodes.accepted;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.accepted;
  }

  @override
  bool check(T value, RuleContext context) {
    return _words.contains(value);
  }
}

/// The value must be `false`, `0`, `'0'`, `'false'`, `'no'` or `'off'`:
/// `@Declined()`. Laravel `declined`.
class Declined<T> extends Rule<T> {
  const Declined({super.message});

  static const List<Object> _words = <Object>[
    false,
    0,
    '0',
    'false',
    'no',
    'off',
  ];

  @override
  String get name {
    return IssueCodes.declined;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.declined;
  }

  @override
  bool check(T value, RuleContext context) {
    return _words.contains(value);
  }
}

/// The field must be missing or empty: `@Prohibited()`.
/// Laravel `prohibited`. Empty: `null`, blank text, an empty list or map.
class Prohibited<T> extends Rule<T> {
  const Prohibited({super.message});

  @override
  String get name {
    return IssueCodes.prohibited;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.prohibited;
  }

  @override
  bool check(T value, RuleContext context) {
    return RequiredWhen.isEmpty(value);
  }
}

/// The field must be missing or empty when the key [other] has [value]:
/// `@ProhibitedIf('type', 'guest')`. Laravel `prohibited_if`. [other] is
/// read from the raw input and matches like in [RequiredIf].
class ProhibitedIf<T> extends Rule<T> {
  const ProhibitedIf(this.other, this.value, {super.message});

  final String other;

  /// One value, or a list of values (any of them).
  final Object? value;

  @override
  String get name {
    return IssueCodes.prohibitedIf;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.prohibitedIf;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{
      'other': other,
      'values': RequiredWhenIssue._names(RequiredWhen.listOf(value))
          .join(' or '),
    };
  }

  @override
  bool check(T value, RuleContext context) {
    List<Object> path = context.path;
    Object? parent = DataPath.read(
      context.root,
      path.isEmpty ? path : path.sublist(0, path.length - 1),
    );
    Object? raw = RequiredWhen.read(parent, other);
    if (!RequiredWhen.matches(raw, RequiredWhen.listOf(this.value))) {
      return true;
    }
    return RequiredWhen.isEmpty(value);
  }
}

/// The value must not equal the key [other] in the same object:
/// `@Different('old_password')`. Laravel `different`. It compares the
/// raw input like [Same]. A missing [other] passes.
class Different<T> extends Rule<T> {
  const Different(this.other, {super.message});

  /// A key in the same object.
  final String other;

  @override
  String get name {
    return IssueCodes.different;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.different;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'other': other};
  }

  @override
  bool check(T value, RuleContext context) {
    return !Same.matches(Same.rawOf(context), context.sibling(other));
  }
}

final RegExp _ulid = RegExp(
  r'^[0-7][0-9A-HJKMNP-TV-Z]{25}$',
  caseSensitive: false,
);

/// The text must be a ULID: 26 Crockford base32 characters, any case.
/// `@Ulid()`. Laravel `ulid`.
class Ulid extends Rule<String> {
  const Ulid({super.message});

  @override
  String get name {
    return IssueCodes.ulid;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.ulid;
  }

  @override
  bool check(String value, RuleContext context) {
    return _ulid.hasMatch(value);
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'pattern': '^[0-7][0-9A-HJKMNP-TV-Za-hjkmnp-tv-z]{25}\$',
    };
  }
}

/// Base of the rules that compare a number with the key [other] in the
/// same object, like Laravel `gt:field`. The raw [other] must be a number
/// (or number text); else the check fails, like Laravel.
abstract class FieldCompare<T extends num> extends Rule<T> {
  const FieldCompare(this.other, {super.message});

  /// A key in the same object.
  final String other;

  /// `true` when [value] passes against [other].
  bool compare(num value, num other);

  @override
  bool check(T value, RuleContext context) {
    Object? raw = context.sibling(other);
    if (raw is List) raw = raw.isEmpty ? null : raw.last;
    num? number = raw is num
        ? raw
        : raw is String
        ? num.tryParse(raw.trim())
        : null;
    if (number == null || !number.isFinite) return false;
    return compare(value, number);
  }
}

/// Greater than the key [other]: `@GreaterThanField('min_price')`.
/// Laravel `gt:field`. The code is `greater_than`.
class GreaterThanField<T extends num> extends FieldCompare<T> {
  const GreaterThanField(super.other, {super.message});

  @override
  String get name {
    return IssueCodes.greaterThan;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.greaterThan;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'min': other};
  }

  @override
  bool compare(num value, num other) {
    return value > other;
  }
}

/// Greater than or equal to the key [other]:
/// `@GreaterThanOrEqualField('min_price')`. Laravel `gte:field`.
/// The code is `min`.
class GreaterThanOrEqualField<T extends num> extends FieldCompare<T> {
  const GreaterThanOrEqualField(super.other, {super.message});

  @override
  String get name {
    return IssueCodes.min;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.min;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'min': other};
  }

  @override
  bool compare(num value, num other) {
    return value >= other;
  }
}

/// Less than the key [other]: `@LessThanField('max_price')`.
/// Laravel `lt:field`. The code is `less_than`.
class LessThanField<T extends num> extends FieldCompare<T> {
  const LessThanField(super.other, {super.message});

  @override
  String get name {
    return IssueCodes.lessThan;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.lessThan;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'max': other};
  }

  @override
  bool compare(num value, num other) {
    return value < other;
  }
}

/// Less than or equal to the key [other]:
/// `@LessThanOrEqualField('max_price')`. Laravel `lte:field`.
/// The code is `max`.
class LessThanOrEqualField<T extends num> extends FieldCompare<T> {
  const LessThanOrEqualField(super.other, {super.message});

  @override
  String get name {
    return IssueCodes.max;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.max;
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'max': other};
  }

  @override
  bool compare(num value, num other) {
    return value <= other;
  }
}
