import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/rule.dart';

/// Finds values in a database table, for [ExistsRule] and [UniqueRule].
/// Like the Laravel presence verifier.
///
/// `dox_orm` sets [instance] when the database starts. Set it yourself to
/// use another database layer, or a fake one in tests.
///
/// An implementation must bind the values as query parameters, never put
/// them into the SQL text.
abstract class PresenceVerifier {
  const PresenceVerifier();

  /// The verifier the rules use when they have none of their own.
  static PresenceVerifier? instance;

  /// The values of [values] that are in [column] of [table], as text.
  /// When [exceptColumn] is set, rows where it equals [exceptValue] are
  /// left out. [connection] is a connection name, `null` for the default.
  Future<Set<String>> found(
    String table,
    String column,
    List<Object?> values, {
    String? exceptColumn,
    Object? exceptValue,
    String? connection,
  });

  static final RegExp _name = RegExp(
    r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)?$',
  );

  /// Throws an [ArgumentError] when [name] is not a plain table or column
  /// name (letters, digits and `_`, with one optional `schema.` part).
  /// Names go into the SQL text, so only safe names may pass.
  static String checkName(String name) {
    if (!_name.hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Not a safe table or column');
    }
    return name;
  }

  static PresenceVerifier _use(PresenceVerifier? own) {
    PresenceVerifier? verifier = own ?? instance;
    if (verifier == null) {
      throw StateError(
        'No PresenceVerifier is set. dox_orm sets it when the database '
        'starts. Or set PresenceVerifier.instance yourself.',
      );
    }
    return verifier;
  }
}

/// A row in [table] has this value in [column]. Laravel `exists`.
/// Made by `v.string().exists('teams')`. Use `parseAsync`.
class ExistsRule<T> extends AsyncRule<T> {
  const ExistsRule(
    this.table, {
    this.column = 'id',
    this.connection,
    this.verifier,
    super.message,
  });

  final String table;
  final String column;

  /// A connection name. Default: the default connection.
  final String? connection;

  /// Default: [PresenceVerifier.instance].
  final PresenceVerifier? verifier;

  @override
  String get name {
    return IssueCodes.exists;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.exists;
  }

  @override
  Future<bool> checkAsync(T value, RuleContext context) async {
    return (await failedItems(<T>[value], context)).isEmpty;
  }

  @override
  Future<List<int>> failedItems(List<T> values, RuleContext context) async {
    Set<String> found = await PresenceVerifier._use(verifier).found(
      PresenceVerifier.checkName(table),
      PresenceVerifier.checkName(column),
      values,
      connection: connection,
    );
    return <int>[
      for (int i = 0; i < values.length; i++)
        if (!found.contains('${values[i]}')) i,
    ];
  }
}

/// No row in [table] has this value in [column]. Laravel `unique`.
/// Made by `v.string().unique('users')`. Use `parseAsync`.
///
/// [column] defaults to the input key. Give [ignore] to skip one row,
/// like the row being updated: `unique('users', ignore: id)`.
class UniqueRule<T> extends AsyncRule<T> {
  const UniqueRule(
    this.table, {
    this.column,
    this.ignore,
    this.ignoreColumn = 'id',
    this.connection,
    this.verifier,
    super.message,
  });

  final String table;
  final String? column;

  /// Skip the row where [ignoreColumn] equals this value.
  final Object? ignore;
  final String ignoreColumn;

  /// A connection name. Default: the default connection.
  final String? connection;

  /// Default: [PresenceVerifier.instance].
  final PresenceVerifier? verifier;

  @override
  String get name {
    return IssueCodes.unique;
  }

  @override
  String get defaultMessage {
    return DefaultMessages.unique;
  }

  @override
  Future<bool> checkAsync(T value, RuleContext context) async {
    return (await failedItems(<T>[value], context)).isEmpty;
  }

  @override
  Future<List<int>> failedItems(List<T> values, RuleContext context) async {
    Object? skip = ignore;
    Set<String> taken = await PresenceVerifier._use(verifier).found(
      PresenceVerifier.checkName(table),
      PresenceVerifier.checkName(column ?? context.field),
      values,
      exceptColumn: skip == null
          ? null
          : PresenceVerifier.checkName(ignoreColumn),
      exceptValue: skip,
      connection: connection,
    );
    return <int>[
      for (int i = 0; i < values.length; i++)
        if (taken.contains('${values[i]}')) i,
    ];
  }
}
