import 'parse_state.dart';
import 'sentinels.dart';

/// The converted values of the fields of each object in one parse.
///
/// `requiredIf` / `requiredWith` read the other field from here, so they
/// see the value the app gets (after `trim()`, `toLowerCase()` and so on),
/// not the raw input. Not exported: only this package uses it.
class ConvertedValues {
  const ConvertedValues._();

  /// Per parse: dotted object path -> field key -> converted value.
  static final Expando<Map<String, Map<Object?, Object?>>> _byState =
      Expando<Map<String, Map<Object?, Object?>>>('convertedValues');

  /// Use [values] as the converted values of the object at [path]. The
  /// object schema gives its output map, which fills while it parses.
  static void track(
    ParseState state,
    List<Object> path,
    Map<Object?, Object?> values,
  ) {
    Map<String, Map<Object?, Object?>> all = _byState[state] ??=
        <String, Map<Object?, Object?>>{};
    all[path.join('.')] = values;
  }

  /// Keep the converted [value] of [key] in the object at [path].
  /// A failed value ([invalid]) is not kept, so the raw input is used.
  static void keep(
    ParseState state,
    List<Object> path,
    Object key,
    Object? value,
  ) {
    if (value is Invalid) return;
    Map<String, Map<Object?, Object?>> all = _byState[state] ??=
        <String, Map<Object?, Object?>>{};
    (all[path.join('.')] ??= <Object?, Object?>{})[key] = value;
  }

  /// [parent] (the raw object at [path]) with each field that has a
  /// converted value replaced by it. An enum value becomes its name, like
  /// in the raw input.
  static Object? parent(ParseState state, List<Object> path, Object? parent) {
    Map<Object?, Object?>? values = _byState[state]?[path.join('.')];
    if (values == null || values.isEmpty || parent is! Map) return parent;
    Map<Object?, Object?> view = <Object?, Object?>{...parent};
    for (MapEntry<Object?, Object?> entry in values.entries) {
      Object? value = entry.value;
      if (value is Undefined) value = null;
      if (value is Enum) value = value.name;
      view[entry.key] = value;
    }
    return view;
  }
}
