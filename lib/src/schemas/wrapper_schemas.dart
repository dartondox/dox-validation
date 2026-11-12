import '../core/converted_values.dart';
import '../core/data_path.dart';
import '../core/fluent_schema.dart';
import '../core/json_schema_tools.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import '../dto/dto_annotations.dart';
import '../rules/field_rules.dart';

/// The value may be missing. Made by `.optional()`.
class OptionalSchema<O> extends BaseSchema<O?>
    with FluentSchema<OptionalSchema<O>, O?> {
  OptionalSchema(this.inner, {this.requiredWhen = const <RequiredWhen>[]});

  /// The wrapped schema.
  final Schema<O> inner;

  /// When one of them applies, the value is required after all.
  final List<RequiredWhen> requiredWhen;

  /// Required when the key [other] in the same object has [value] (or
  /// one of the values, when [value] is a list).
  OptionalSchema<O> requiredIf(String other, Object? value, {String? message}) {
    return _addRequiredWhen(RequiredIf(other, value, message: message));
  }

  /// Required when any of the keys [others] in the same object is present
  /// and not empty.
  OptionalSchema<O> requiredWith(List<String> others, {String? message}) {
    return _addRequiredWhen(RequiredWith(others, message: message));
  }

  /// Required unless the key [other] in the same object has [value].
  OptionalSchema<O> requiredUnless(
    String other,
    Object? value, {
    String? message,
  }) {
    return _addRequiredWhen(RequiredUnless(other, value, message: message));
  }

  /// Required when any of the keys [others] in the same object is missing
  /// or empty.
  OptionalSchema<O> requiredWithout(List<String> others, {String? message}) {
    return _addRequiredWhen(RequiredWithout(others, message: message));
  }

  /// Required when all of the keys [others] in the same object are
  /// missing or empty.
  OptionalSchema<O> requiredWithoutAll(List<String> others, {String? message}) {
    return _addRequiredWhen(RequiredWithoutAll(others, message: message));
  }

  /// When the key is sent, it must have a value.
  OptionalSchema<O> filled({String? message}) {
    return _addRequiredWhen(Filled(message: message));
  }

  /// The key must be sent, maybe with an empty value. Add `.nullable()`
  /// to allow `null`.
  OptionalSchema<O> present({String? message}) {
    return _addRequiredWhen(Present(message: message));
  }

  /// The key must be missing, or blank text.
  OptionalSchema<O> prohibited({String? message}) {
    return _addRequiredWhen(Prohibited(message: message));
  }

  /// Like [prohibited], when the key [other] in the same object has
  /// [value].
  OptionalSchema<O> prohibitedIf(
    String other,
    Object? value, {
    String? message,
  }) {
    return _addRequiredWhen(ProhibitedIf(other, value, message: message));
  }

  OptionalSchema<O> _addRequiredWhen(RequiredWhen rule) {
    return copyBaseInto(
      OptionalSchema<O>(
        inner,
        requiredWhen: <RequiredWhen>[...requiredWhen, rule],
      ),
    );
  }

  /// Add an issue and give `true` when [input] is empty but a
  /// [requiredWhen] rule applies.
  bool _missingButRequired(Object? input, ParseState state, List<Object> path) {
    if (requiredWhen.isEmpty) return false;
    bool empty = input is Undefined || RequiredWhen.isEmpty(input);
    // a value: only rules like `prohibited` run, so skip the work
    if (!empty && !requiredWhen.any(_checksValues)) return false;
    List<Object> parentPath = path.isEmpty
        ? path
        : path.sublist(0, path.length - 1);
    Object? raw = DataPath.read(state.root, parentPath);
    // the other fields as the app gets them, not the raw input
    Object? parent = ConvertedValues.parent(state, parentPath, raw);
    Object key = path.isEmpty ? '' : path.last;
    for (RequiredWhen rule in requiredWhen) {
      if (!empty && !rule.checksValues) continue;
      if (!rule.appliesToField(parent, raw, key)) continue;
      RequiredWhenIssue issue = RequiredWhenIssue(rule);
      state.addIssue(
        path: path,
        code: issue.code,
        fallback: issue.fallback,
        value: input,
        params: issue.params,
        message: rule.message,
        others: issue.others,
      );
      return true;
    }
    return false;
  }

  static bool _checksValues(RequiredWhen rule) {
    return rule.checksValues;
  }

  @override
  bool get isOptional {
    return true;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (_missingButRequired(input, state, path)) {
      return invalid;
    }
    if (input is Undefined) {
      return undefined;
    }
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(output, before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (_missingButRequired(input, state, path)) {
      return invalid;
    }
    if (input is Undefined) {
      return undefined;
    }
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(output, before, state, path);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return inner.parseType(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return inner.toJsonSchema();
  }

  @override
  OptionalSchema<O> copySchema() {
    return copyBaseInto(OptionalSchema<O>(inner, requiredWhen: requiredWhen));
  }
}

/// The value may be `null`. Made by `.nullable()`.
class NullableSchema<O> extends BaseSchema<O?>
    with FluentSchema<NullableSchema<O>, O?> {
  NullableSchema(this.inner);

  /// The wrapped schema.
  final Schema<O> inner;

  @override
  bool get isOptional {
    return inner.isOptional;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (input == null) {
      return _nullOrMissing(state, path);
    }
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(output, before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input == null) {
      return _nullOrMissing(state, path);
    }
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(output, before, state, path);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return inner.parseType(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return JsonSchemaTools.makeNullable(inner.toJsonSchema());
  }

  /// `null` passes, unless an inner `.optional()` has a `requiredIf` /
  /// `requiredWith` rule that applies. It looks through every wrapper,
  /// so `.optional().requiredIf(...).transform(...).nullable()` and
  /// `.nullable().nullable()` do not let `null` through.
  Object? _nullOrMissing(ParseState state, List<Object> path) {
    Schema<Object?> current = inner;
    while (true) {
      if (current is OptionalSchema) {
        if ((current as OptionalSchema<Object?>)._missingButRequired(
          null,
          state,
          path,
        )) {
          return invalid;
        }
        current = current.inner;
      } else if (current is NullableSchema) {
        current = current.inner;
      } else if (current is DefaultSchema) {
        current = current.inner;
      } else if (current is TransformSchema) {
        current = current.inner;
      } else {
        return null;
      }
    }
  }

  @override
  NullableSchema<O> copySchema() {
    return copyBaseInto(NullableSchema<O>(inner));
  }
}

/// Uses a default value when the input is missing. Made by `.defaultTo()`.
class DefaultSchema<O> extends BaseSchema<O>
    with FluentSchema<DefaultSchema<O>, O> {
  DefaultSchema(this.inner, this.defaultValue);

  /// The wrapped schema.
  final Schema<O> inner;

  /// Value used when the input is missing.
  final O defaultValue;

  @override
  bool get isOptional {
    return true;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    if (input is Undefined) {
      return defaultValue;
    }
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(output, before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input is Undefined) {
      return defaultValue;
    }
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(output, before, state, path);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return inner.parseType(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    Map<String, dynamic> json = inner.toJsonSchema();
    json['default'] = JsonSchemaTools.toJsonValue(defaultValue);
    return json;
  }

  @override
  DefaultSchema<O> copySchema() {
    return copyBaseInto(DefaultSchema<O>(inner, defaultValue));
  }
}

/// Changes the output after the inner schema passes.
/// Made by `.transform()`. JSON Schema shows the input shape.
class TransformSchema<I, O> extends BaseSchema<O>
    with FluentSchema<TransformSchema<I, O>, O> {
  TransformSchema(this.inner, this.transformer);

  /// The wrapped schema.
  final Schema<I> inner;

  /// Function that makes the new output.
  final O Function(I value) transformer;

  @override
  bool get isOptional {
    return inner.isOptional;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(_apply(output, before, state), before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(_apply(output, before, state), before, state, path);
  }

  Object? _apply(Object? output, int before, ParseState state) {
    if (output is Invalid || output is Undefined) {
      return output;
    }
    if (state.issues.length > before) {
      return invalid;
    }
    return transformer(output as I);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return parseValue(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return inner.toJsonSchema();
  }

  @override
  TransformSchema<I, O> copySchema() {
    return copyBaseInto(TransformSchema<I, O>(inner, transformer));
  }
}

/// Leaves the key out of an object when [condition] applies. Made by
/// `.excludeIf()` and `.excludeUnless()`. The object schema checks
/// [condition] before the field, so the wrappers around it do not
/// matter. Anywhere else it only runs [inner].
class ExcludeSchema<O> extends BaseSchema<O>
    with FluentSchema<ExcludeSchema<O>, O> {
  ExcludeSchema(this.inner, this.condition);

  /// The wrapped schema.
  final Schema<O> inner;

  /// When it applies to the raw object, the key is left out.
  final ExcludeWhen condition;

  /// The conditions of every [ExcludeSchema] in [schema] and the
  /// wrappers around it. Empty when there is none.
  static List<ExcludeWhen> conditionsOf(Schema<Object?> schema) {
    List<ExcludeWhen> found = <ExcludeWhen>[];
    Schema<Object?> current = schema;
    while (true) {
      if (current is ExcludeSchema) {
        found.add(current.condition);
        current = current.inner;
      } else if (current is OptionalSchema) {
        current = current.inner;
      } else if (current is NullableSchema) {
        current = current.inner;
      } else if (current is DefaultSchema) {
        current = current.inner;
      } else if (current is TransformSchema) {
        current = current.inner;
      } else {
        return found;
      }
    }
  }

  @override
  bool get isOptional {
    return inner.isOptional;
  }

  @override
  bool get isAsync {
    return super.isAsync || inner.isAsync;
  }

  @override
  Object? parseValue(Object? input, ParseState state, List<Object> path) {
    int before = state.issues.length;
    Object? output = inner.parseValue(input, state, path);
    return runRules(output, before, state, path);
  }

  @override
  Future<Object?> parseValueAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    int before = state.issues.length;
    Object? output = await inner.parseValueAsync(input, state, path);
    return runRulesAsync(output, before, state, path);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    return inner.parseType(input, state, path);
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return inner.toJsonSchema();
  }

  @override
  ExcludeSchema<O> copySchema() {
    return copyBaseInto(ExcludeSchema<O>(inner, condition));
  }
}
