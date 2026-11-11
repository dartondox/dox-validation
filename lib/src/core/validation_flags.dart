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
  });

  /// Every flag on.
  const ValidationFlags.all()
    : emptyStringsToNull = true,
      unicodeAlpha = true,
      shortInMessage = true;

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
}
