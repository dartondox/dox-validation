// Annotations for DTO classes. `dox_builder` reads them and writes the
// checks. They do nothing at runtime by themselves.
//
// ```dart
// @Dto()
// class CreateUser {
//   @Length(min: 3, max: 50)
//   final String name;
//
//   const CreateUser({required this.name});
//
//   static const DtoSchema<CreateUser> schema = $CreateUserDto;
// }
// ```

/// Where a DTO reads its input.
enum Source {
  /// `GET`, `HEAD` and `DELETE` read the query, the others the body.
  auto,

  /// Always the query string.
  query,

  /// Always the body.
  body,
}

/// How a field name becomes the input key.
enum KeyCase {
  /// `firstName` reads `first_name`. The default.
  snake,

  /// `firstName` reads `firstName`.
  field,
}

/// Marks a class as a DTO: typed, checked input.
class Dto {
  const Dto({
    this.source = Source.auto,
    this.keyCase = KeyCase.snake,
    this.strict = false,
    this.messages = const <String, String>{},
    this.emptyStringsToNull = false,
  });

  /// Where to read the input. See [Source].
  final Source source;

  /// How field names become keys. See [KeyCase].
  final KeyCase keyCase;

  /// `true`: an unknown key is an error. `false`: it is dropped.
  final bool strict;

  /// Messages by `code` or by `key.code`, like `email.required`.
  final Map<String, String> messages;

  /// `true`: a key with `""` is read as `null`, like Laravel's
  /// `ConvertEmptyStringsToNull`. So `{"note": ""}` clears a
  /// `Maybe<String?>` field (present, `null`) instead of leaving it out.
  /// A required field still gets `required`.
  ///
  /// `false` (the default): `""` counts as missing.
  /// It works on the keys of this DTO, not on a nested DTO or list items.
  final bool emptyStringsToNull;
}

/// The input key of this field. Default: the field name in snake_case.
class Name {
  const Name(this.key);

  final String key;
}

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

/// Number of characters: `@Length(min: 3, max: 50)`. Give one or both.
class Length {
  const Length({this.min, this.max, this.message});

  final int? min;
  final int? max;
  final String? message;
}

/// At least [value] characters.
class MinLength {
  const MinLength(this.value, {this.message});

  final int value;
  final String? message;
}

/// At most [value] characters.
class MaxLength {
  const MaxLength(this.value, {this.message});

  final int value;
  final String? message;
}

/// An email address.
class Email {
  const Email({this.message});

  final String? message;
}

/// An `http` or `https` url with a host.
class Url {
  const Url({this.message});

  final String? message;
}

/// A UUID, any version.
class Uuid {
  const Uuid({this.message});

  final String? message;
}

/// An IPv4 or IPv6 address.
class Ip {
  const Ip({this.message});

  final String? message;
}

/// The whole text must match [pattern]. No `^` and `$` needed.
class Regex {
  const Regex(this.pattern, {this.message});

  final String pattern;
  final String? message;
}

/// One of [values]. Works for text and numbers.
class In {
  const In(this.values, {this.message});

  final List<Object> values;
  final String? message;
}

/// Not one of [values]. Works for text and numbers.
class NotIn {
  const NotIn(this.values, {this.message});

  final List<Object> values;
  final String? message;
}

/// The text starts with [prefix].
class StartsWith {
  const StartsWith(this.prefix, {this.message});

  final String prefix;
  final String? message;
}

/// The text ends with [suffix].
class EndsWith {
  const EndsWith(this.suffix, {this.message});

  final String suffix;
  final String? message;
}

/// Only ASCII letters.
class Alpha {
  const Alpha({this.message});

  final String? message;
}

/// Only ASCII letters and digits.
class AlphaNumeric {
  const AlphaNumeric({this.message});

  final String? message;
}

/// Only ASCII letters, `-` and `_`.
class AlphaDash {
  const AlphaDash({this.message});

  final String? message;
}

// ---------------------------------------------------------------------------
// Change text
// ---------------------------------------------------------------------------

/// Remove spaces at the start and the end.
class Trim {
  const Trim();
}

/// Make the text lower case.
class Lowercase {
  const Lowercase();
}

/// Make the text upper case.
class Uppercase {
  const Uppercase();
}

/// Keep `""` as a value. Without it, `""` counts as missing.
class AllowEmpty {
  const AllowEmpty();
}

/// A bad value gives the default of the field (or `null`), not an error.
/// For query strings that old links may get wrong, like `?page=abc`.
///
/// Type errors and the rules of this field both count, so
/// `@OrDefault() @NotIn(<int>[0]) final int days;` with `this.days = 30`
/// in the constructor turns `days=0` and `days=abc` into `30`. The field
/// needs a default in the constructor or must be nullable.
class OrDefault {
  const OrDefault();
}

// ---------------------------------------------------------------------------
// Numbers
// ---------------------------------------------------------------------------

/// At least [value].
class Min {
  const Min(this.value, {this.message});

  final num value;
  final String? message;
}

/// At most [value].
class Max {
  const Max(this.value, {this.message});

  final num value;
  final String? message;
}

/// From [min] to [max].
class Range {
  const Range(this.min, this.max, {this.message});

  final num min;
  final num max;
  final String? message;
}

/// Greater than 0.
class Positive {
  const Positive({this.message});

  final String? message;
}

/// Greater than [value] (exclusive).
class GreaterThan {
  const GreaterThan(this.value, {this.message});

  final num value;
  final String? message;
}

/// Less than [value] (exclusive).
class LessThan {
  const LessThan(this.value, {this.message});

  final num value;
  final String? message;
}

// ---------------------------------------------------------------------------
// Lists
// ---------------------------------------------------------------------------

/// At least [value] items.
class MinItems {
  const MinItems(this.value, {this.message});

  final int value;
  final String? message;
}

/// At most [value] items.
class MaxItems {
  const MaxItems(this.value, {this.message});

  final int value;
  final String? message;
}

/// No item twice.
class UniqueItems {
  const UniqueItems({this.message});

  final String? message;
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

/// After [date] (exclusive). An ISO 8601 date, or `'now'`.
class After {
  const After(this.date, {this.message});

  final String date;
  final String? message;
}

/// Before [date] (exclusive). An ISO 8601 date, or `'now'`.
class Before {
  const Before(this.date, {this.message});

  final String date;
  final String? message;
}

// ---------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------

/// At most [size], like `'2MB'`. Units: `B`, `KB`, `MB`, `GB`.
class MaxSize {
  const MaxSize(this.size, {this.message});

  final String size;
  final String? message;
}

/// One of the file types [types] (extensions, like `pdf`).
/// The real type comes from the first bytes of the file.
class Mimes {
  const Mimes(this.types, {this.message});

  final List<String> types;
  final String? message;
}

/// An image: jpg, jpeg, png, gif, webp or bmp. Not svg.
class Image {
  const Image({this.message});

  final String? message;
}

/// At least [size], like `'10KB'`. Units: `B`, `KB`, `MB`, `GB`.
class MinSize {
  const MinSize(this.size, {this.message});

  final String size;
  final String? message;
}

/// One of the MIME types [types], like `image/png` or `image/*`.
/// The real type comes from the first bytes of the file, not from the
/// content type the client sent.
class MimeTypes {
  const MimeTypes(this.types, {this.message});

  final List<String> types;
  final String? message;
}

/// A PNG, GIF, WebP or JPEG image whose width and height (in pixels) fit
/// every limit given. [ratio] is width / height, like `3 / 2`.
class Dimensions {
  const Dimensions({
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.ratio,
    this.message,
  });

  final int? width;
  final int? height;
  final int? minWidth;
  final int? maxWidth;
  final int? minHeight;
  final int? maxHeight;
  final double? ratio;
  final String? message;
}

// ---------------------------------------------------------------------------
// Required when
// ---------------------------------------------------------------------------

/// Base of [RequiredIf] and [RequiredWith]. The field is required only
/// when [appliesTo] is `true`. Use them on a nullable field, a `Maybe`
/// field or a field with a default.
abstract class RequiredWhen {
  const RequiredWhen({this.message});

  final String? message;

  /// `true` when the field is required. [parent] is the raw input
  /// object that holds the field.
  bool appliesTo(Object? parent);

  /// The raw value of [key] in [parent], or `null`. In text input a key
  /// can come many times; then it is a list and the last one is used.
  static Object? read(Object? parent, String key) {
    if (parent is! Map) return null;
    Object? value = parent[key];
    if (value is List) return value.isEmpty ? null : value.last;
    return value;
  }

  /// `true` when [value] counts as missing: `null`, blank text or an
  /// empty list or map.
  static bool isEmpty(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }
}

/// Required when the key [other] has [value]:
/// `@RequiredIf('type', 'company')`. Give a list for many values:
/// `@RequiredIf('type', ['company', 'shop'])`.
///
/// [other] is a key in the same object. Text and numbers match by text,
/// so `'1'` matches `1` and `'true'` matches `true`. An enum value
/// matches its name: `Kind.company` matches `'company'`.
class RequiredIf extends RequiredWhen {
  const RequiredIf(this.other, this.value, {super.message});

  final String other;

  /// One value, or a list of values (any of them).
  final Object? value;

  /// [value] as a list.
  List<Object?> get values {
    Object? one = value;
    return one is List ? one : <Object?>[one];
  }

  @override
  bool appliesTo(Object? parent) {
    Object? raw = RequiredWhen.read(parent, other);
    for (Object? value in values) {
      Object? item = value is Enum ? value.name : value;
      if (item == raw) return true;
      if (raw != null && item != null && '$item' == '$raw') return true;
    }
    return false;
  }
}

/// Required when any of the keys [others] is present and not empty:
/// `@RequiredWith(['phone'])`. [others] are keys in the same object.
class RequiredWith extends RequiredWhen {
  const RequiredWith(this.others, {super.message});

  final List<String> others;

  @override
  bool appliesTo(Object? parent) {
    for (String key in others) {
      if (!RequiredWhen.isEmpty(RequiredWhen.read(parent, key))) return true;
    }
    return false;
  }
}
