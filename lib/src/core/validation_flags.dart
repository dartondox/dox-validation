import '../constants/issue_codes.dart';

/// Opt-in behaviors of dox_validation. Each one is off by default.
///
/// Set them in `Validator.flags`:
///
/// ```dart
/// Validator.flags = const ValidationFlags(unicodeAlpha: true);
/// Validator.flags = const ValidationFlags.all(); // every one on
/// ```
///
/// Each isolate has its own value. In a Dox app, set it in a provider's
/// `setup()`, so every isolate runs it.
class ValidationFlags {
  const ValidationFlags({
    this.emptyStringsToNull = false,
    this.unicodeAlpha = false,
    this.shortInMessage = false,
    this.dtoAllErrors = false,
    this.dtoRejectEmptyList = false,
    this.dtoMaybeRejectsEmpty = false,
    this.laravelMessageKeys = false,
  });

  /// Every flag on.
  const ValidationFlags.all()
    : emptyStringsToNull = true,
      unicodeAlpha = true,
      shortInMessage = true,
      dtoAllErrors = true,
      dtoRejectEmptyList = true,
      dtoMaybeRejectsEmpty = true,
      laravelMessageKeys = true;

  /// Fluent schemas turn each `""` in the input into `null` before they
  /// check it, also in nested maps and lists. So `""` fails a required
  /// field, and `.nullable()` gives `null` for it. A DTO schema checked
  /// on its own is not changed; it has `@Dto(emptyStringsToNull: true)`.
  /// A DTO inside a fluent schema gets the changed input.
  final bool emptyStringsToNull;

  /// `alpha`, `alphaNumeric` and `alphaDash` accept Unicode letters
  /// and marks, like `José` or `ไทย`. `alphaNumeric` and `alphaDash` also
  /// accept Unicode digits. Off: only `a-z` and `A-Z` (and `0-9`).
  final bool unicodeAlpha;

  /// The default `in` message is `The selected {field} is invalid`. It
  /// does not list the allowed values. Off: the message lists them.
  final bool shortInMessage;

  /// A DTO runs the rules of each field that has the right type, also
  /// when another field is missing or has the wrong type. So one request
  /// gets all its errors at once. Off: when a field is missing or has the
  /// wrong type, no rule of any field runs.
  ///
  /// The order of the errors: first the type and `required` errors of all
  /// fields (with the errors of a nested DTO at its field), then the
  /// rule errors. A field with a bad item in its list or map, or a list
  /// that fails `required`, skips its rules.
  /// Needs DTO code from a dox_builder that knows it.
  final bool dtoAllErrors;

  /// A required `List` field of a DTO fails `required` on `[]`.
  /// Off: `[]` passes.
  /// Needs DTO code from a dox_builder that knows it.
  final bool dtoRejectEmptyList;

  /// A `Maybe<T>` field of a DTO (with `T` not nullable) fails `required`
  /// when the key is sent with an empty value, like `""`. A missing key
  /// still gives `Maybe.missing()`. Off: `""` counts as not sent.
  /// Needs DTO code from a dox_builder that knows it.
  final bool dtoMaybeRejectsEmpty;

  /// A custom message key can use the Laravel rule name of a code, like
  /// `name.min` for the `min_length` error (see [IssueCodes.laravel]). It
  /// works in `@Dto(messages:)` and in a `MessageResolver`. At each step
  /// of the lookup the Dox code wins. The issue code does not change.
  /// Off: only the Dox codes match.
  final bool laravelMessageKeys;
}
