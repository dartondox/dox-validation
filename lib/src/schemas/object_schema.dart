import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/converted_values.dart';
import '../core/fluent_schema.dart';
import '../core/issue.dart';
import '../core/message_resolver.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import '../dto/dto_annotations.dart';
import 'wrapper_schemas.dart';

/// `isAsync` per schema. A schema does not change after it is built,
/// so the tree is walked only once, not on every parse.
final Expando<bool> _isAsyncCache = Expando<bool>('isAsync');

/// What an [ObjectSchema] does with keys that are not in its shape.
enum UnknownKeys {
  /// Drop them from the output. This is the default.
  strip,

  /// Add an `unrecognized_keys` issue.
  strict,

  /// Keep them in the output as they are.
  passthrough,
}

/// Schema for a map with known keys. Made by `v.object()`.
/// The output is a new `Map<String, dynamic>`.
class ObjectSchema extends BaseSchema<Map<String, dynamic>>
    with FluentSchema<ObjectSchema, Map<String, dynamic>> {
  ObjectSchema(
    Map<String, Schema<Object?>> shape, {
    this.unknownKeys = UnknownKeys.strip,
  }) : shape = Map<String, Schema<Object?>>.unmodifiable(shape);

  /// Schema for each key.
  final Map<String, Schema<Object?>> shape;

  /// What to do with keys that are not in [shape].
  final UnknownKeys unknownKeys;

  @override
  bool get isAsync {
    return _isAsyncCache[this] ??= _findAsync();
  }

  bool _findAsync() {
    if (super.isAsync) {
      return true;
    }
    for (Schema<Object?> child in shape.values) {
      if (child.isAsync) {
        return true;
      }
    }
    return false;
  }

  /// Unknown keys are an error.
  ObjectSchema strict() {
    return _withShape(shape, UnknownKeys.strict);
  }

  /// Keep unknown keys in the output.
  ObjectSchema passthrough() {
    return _withShape(shape, UnknownKeys.passthrough);
  }

  /// Drop unknown keys from the output (the default).
  ObjectSchema strip() {
    return _withShape(shape, UnknownKeys.strip);
  }

  /// Add or replace keys.
  ObjectSchema extend(Map<String, Schema<Object?>> more) {
    return _withShape(<String, Schema<Object?>>{
      ...shape,
      ...more,
    }, unknownKeys);
  }

  /// Keep only [keys].
  ObjectSchema pick(List<String> keys) {
    Map<String, Schema<Object?>> next = <String, Schema<Object?>>{};
    for (String key in keys) {
      Schema<Object?>? child = shape[key];
      if (child != null) {
        next[key] = child;
      }
    }
    return _withShape(next, unknownKeys);
  }

  /// Remove [keys].
  ObjectSchema omit(List<String> keys) {
    Map<String, Schema<Object?>> next = <String, Schema<Object?>>{...shape};
    for (String key in keys) {
      next.remove(key);
    }
    return _withShape(next, unknownKeys);
  }

  /// Make every key optional. Good for PATCH requests.
  ObjectSchema partial() {
    Map<String, Schema<Object?>> next = <String, Schema<Object?>>{};
    for (MapEntry<String, Schema<Object?>> entry in shape.entries) {
      Schema<Object?> child = entry.value;
      next[entry.key] = child.isOptional
          ? child
          : OptionalSchema<Object?>(child);
    }
    return _withShape(next, unknownKeys);
  }

  ObjectSchema _withShape(
    Map<String, Schema<Object?>> nextShape,
    UnknownKeys keys,
  ) {
    return copyBaseInto(ObjectSchema(nextShape, unknownKeys: keys));
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is! Map) {
      _typeIssue(input, state, path);
      return invalid;
    }
    Map<String, dynamic> output = <String, dynamic>{};
    int before = state.issues.length;
    if (_reordered) ConvertedValues.track(state, path, output);
    for (MapEntry<String, Schema<Object?>> entry in _checkOrder) {
      if (_excludes.isNotEmpty && _excluded(input, entry.key)) continue;
      Object? value = entry.value.parseValue(
        _read(input, entry.key),
        state,
        <Object>[...path, entry.key],
      );
      _put(output, entry.key, value);
    }
    if (_reordered) output = _inShapeOrder(output, state, path, before);
    _unknown(input, output, state, path);
    return output;
  }

  @override
  Future<Object?> parseTypeAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input is! Map) {
      _typeIssue(input, state, path);
      return invalid;
    }
    Map<String, dynamic> output = <String, dynamic>{};
    int before = state.issues.length;
    if (_reordered) ConvertedValues.track(state, path, output);
    for (MapEntry<String, Schema<Object?>> entry in _checkOrder) {
      if (_excludes.isNotEmpty && _excluded(input, entry.key)) continue;
      Object? value = await entry.value.parseValueAsync(
        _read(input, entry.key),
        state,
        <Object>[...path, entry.key],
      );
      _put(output, entry.key, value);
    }
    if (_reordered) output = _inShapeOrder(output, state, path, before);
    _unknown(input, output, state, path);
    return output;
  }

  /// The `excludeIf` / `excludeUnless` conditions of each field that has
  /// one. Empty for a plain object, so it pays nothing.
  late final Map<String, List<ExcludeWhen>> _excludes = _findExcludes();

  Map<String, List<ExcludeWhen>> _findExcludes() {
    Map<String, List<ExcludeWhen>> found = <String, List<ExcludeWhen>>{};
    for (MapEntry<String, Schema<Object?>> entry in shape.entries) {
      List<ExcludeWhen> conditions = ExcludeSchema.conditionsOf(entry.value);
      if (conditions.isNotEmpty) found[entry.key] = conditions;
    }
    return found;
  }

  /// `true` when the field [key] is left out. [input] is the raw object.
  bool _excluded(Map<dynamic, dynamic> input, String key) {
    List<ExcludeWhen>? conditions = _excludes[key];
    if (conditions == null) return false;
    for (ExcludeWhen condition in conditions) {
      if (condition.appliesTo(input)) return true;
    }
    return false;
  }

  /// The fields with a `requiredIf` / `requiredWith` rule come last, so
  /// the rule sees the converted value of the other field.
  late final List<MapEntry<String, Schema<Object?>>> _checkOrder =
      _inCheckOrder();

  /// `true` when the shape has a `requiredIf` / `requiredWith` field.
  /// Only then the converted values are kept and the fields reordered,
  /// so a plain object pays nothing.
  late final bool _reordered = _hasRuleField();

  bool _hasRuleField() {
    for (Schema<Object?> child in shape.values) {
      if (_hasRequiredWhen(child)) return true;
    }
    return false;
  }

  List<MapEntry<String, Schema<Object?>>> _inCheckOrder() {
    List<MapEntry<String, Schema<Object?>>> first =
        <MapEntry<String, Schema<Object?>>>[];
    List<MapEntry<String, Schema<Object?>>> last =
        <MapEntry<String, Schema<Object?>>>[];
    for (MapEntry<String, Schema<Object?>> entry in shape.entries) {
      (_hasRequiredWhen(entry.value) ? last : first).add(entry);
    }
    return <MapEntry<String, Schema<Object?>>>[...first, ...last];
  }

  static bool _hasRequiredWhen(Schema<Object?> schema) {
    Schema<Object?> current = schema;
    while (true) {
      if (current is OptionalSchema) {
        if (current.requiredWhen.isNotEmpty) return true;
        current = current.inner;
      } else if (current is NullableSchema) {
        current = current.inner;
      } else if (current is DefaultSchema) {
        current = current.inner;
      } else if (current is TransformSchema) {
        current = current.inner;
      } else {
        return false;
      }
    }
  }

  /// [output] with its keys in the order of [shape]. The issues added
  /// since [before] are put in the order of [shape] too, so the order of
  /// the checks does not show.
  Map<String, dynamic> _inShapeOrder(
    Map<String, dynamic> output,
    ParseState state,
    List<Object> path,
    int before,
  ) {
    Map<String, dynamic> sorted = <String, dynamic>{};
    for (String key in shape.keys) {
      if (output.containsKey(key)) sorted[key] = output[key];
    }
    List<ValidationIssue> issues = state.issues;
    if (issues.length - before > 1) {
      Map<Object?, List<ValidationIssue>> byKey =
          <Object?, List<ValidationIssue>>{};
      for (ValidationIssue issue in issues.sublist(before)) {
        Object? key = issue.path.length > path.length
            ? issue.path[path.length]
            : null;
        (byKey[key] ??= <ValidationIssue>[]).add(issue);
      }
      issues.length = before;
      for (String key in shape.keys) {
        issues.addAll(byKey.remove(key) ?? const <ValidationIssue>[]);
      }
      // an issue at some other path (from a custom rule) stays at the end
      for (List<ValidationIssue> rest in byKey.values) {
        issues.addAll(rest);
      }
    }
    return sorted;
  }

  Object? _read(Map<dynamic, dynamic> input, String key) {
    if (input.containsKey(key)) {
      return input[key];
    }
    return undefined;
  }

  void _put(Map<String, dynamic> output, String key, Object? value) {
    if (value is Invalid || value is Undefined) {
      return;
    }
    output[key] = value;
  }

  void _unknown(
    Map<dynamic, dynamic> input,
    Map<String, dynamic> output,
    ParseState state,
    List<Object> path,
  ) {
    if (unknownKeys == UnknownKeys.strip) {
      return;
    }
    List<String> extra = <String>[];
    for (Object? key in input.keys) {
      String name = key.toString();
      if (!shape.containsKey(name)) {
        extra.add(name);
        if (unknownKeys == UnknownKeys.passthrough) {
          output[name] = input[key];
        }
      }
    }
    if (unknownKeys == UnknownKeys.strict && extra.isNotEmpty) {
      state.addIssue(
        path: path,
        code: IssueCodes.unrecognizedKeys,
        fallback: DefaultMessages.unrecognizedKeys,
        params: <String, Object?>{'keys': ListText.joinWithAnd(extra)},
      );
    }
  }

  void _typeIssue(Object? input, ParseState state, List<Object> path) {
    addTypeIssue(
      code: IssueCodes.object,
      fallback: DefaultMessages.object,
      input: input,
      state: state,
      path: path,
    );
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    Map<String, dynamic> properties = <String, dynamic>{};
    List<String> required = <String>[];
    for (MapEntry<String, Schema<Object?>> entry in shape.entries) {
      properties[entry.key] = entry.value.toJsonSchema();
      // a field with `excludeIf` can be left out, so it is not required
      if (!entry.value.isOptional && !_excludes.containsKey(entry.key)) {
        required.add(entry.key);
      }
    }
    Map<String, dynamic> json = <String, dynamic>{
      'type': 'object',
      'properties': properties,
    };
    if (required.isNotEmpty) {
      json['required'] = required;
    }
    if (unknownKeys == UnknownKeys.strict) {
      json['additionalProperties'] = false;
    }
    return json;
  }

  @override
  ObjectSchema copySchema() {
    return copyBaseInto(ObjectSchema(shape, unknownKeys: unknownKeys));
  }
}
