import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/rule.dart';

/// Finds values in a database table, for [ExistsRule] and [UniqueRule].
///
/// `dox_orm` sets [instance] when the database starts. Set it yourself to
/// use another database layer, or a fake one in tests.
///
/// An implementation must bind the values as query parameters, never put
/// them into the SQL text.
abstract class PresenceVerifier {
  const PresenceVerifier();

  /// The verifier the rules use when they have none of their own.
  ///
  /// Each isolate has its own static value. So set it where every isolate
  /// runs it, like a provider's `setup()`. dox_orm sets it when the
  /// database driver is set.
  static PresenceVerifier? instance;

  /// The values of [values] that are in [column] of [table], as text.
  /// When [exceptColumn] is set, rows where it equals [exceptValue] are
  /// left out. [connection] is a connection name, `null` for the default.
  ///
  /// A value that can not be in the column (like `abc` for a number
  /// column) is not found. When [values] has more than one item and the
  /// database can not compare them, throw [PresenceUnknown].
  Future<Set<String>> found(
    String table,
    String column,
    List<Object?> values, {
    String? exceptColumn,
    Object? exceptValue,
    String? connection,
  });

  /// The same names the dox_orm query builder takes, without `*` and
  /// `as`: Unicode letters, digits, `_` and `$`, with `.` between parts.
  static final RegExp _name = RegExp(
    r'^(?:[\p{L}\p{N}_$]+\.)*[\p{L}\p{N}_$]+$',
    unicode: true,
  );

  /// Throws an [ArgumentError] when [name] is not a plain table or column
  /// name: letters, digits, `_` and `$`, with `.` between parts, like
  /// `2fa_codes` or `public.users`. Names go into the SQL text, so only
  /// plain names may pass.
  static String checkName(String name) {
    if (!_name.hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Not a safe table or column');
    }
    return name;
  }

  /// The items of [values] that are not in the table, for `exists` on a
  /// list. It runs one query for the whole list.
  ///
  /// An item passes only when its exact text is found. So on MySQL an
  /// item that differs from the row only in case fails (the safe side;
  /// one value alone lets the database decide). A `null` item always
  /// fails. When [find] throws [PresenceUnknown], every item fails.
  static Future<List<int>> missingItems<T>(
    List<T> values,
    Future<Set<String>> Function(List<T> values) find,
  ) async {
    List<T> distinct = _distinct(values);
    List<int> all = <int>[for (int i = 0; i < values.length; i++) i];
    if (distinct.isEmpty) return all;
    Set<String> found;
    try {
      found = await find(distinct);
    } on PresenceUnknown {
      return all;
    }
    return <int>[
      for (int i = 0; i < values.length; i++)
        if (values[i] == null || !found.contains('${values[i]}')) i,
    ];
  }

  /// The items of [values] that are already in the table, for `unique` on
  /// a list. One query for the whole list.
  ///
  /// The list passes when the database finds no row. When every found row
  /// is an item by its exact text, only those items fail. When a found
  /// row matches no item by its text, the database matched in its own
  /// way (MySQL ignores case and trailing spaces), and one query can not
  /// tell which item it was: then every item fails (the safe side). A
  /// `null` item never fails. When [find] throws [PresenceUnknown], every
  /// item fails.
  static Future<List<int>> takenItems<T>(
    List<T> values,
    Future<Set<String>> Function(List<T> values) find,
  ) async {
    List<T> distinct = _distinct(values);
    if (distinct.isEmpty) return <int>[];
    List<int> all = <int>[
      for (int i = 0; i < values.length; i++)
        if (values[i] != null) i,
    ];
    Set<String> found;
    try {
      found = await find(distinct);
    } on PresenceUnknown {
      return all;
    }
    // every row is an item by its exact text: only those items are taken
    Set<String> texts = <String>{for (T value in distinct) '$value'};
    if (!texts.containsAll(found)) return all;
    return <int>[
      for (int i = 0; i < values.length; i++)
        if (values[i] != null && found.contains('${values[i]}')) i,
    ];
  }

  /// One item per text, without `null`. `1` and `'1'` are one value for
  /// the database, `1` and `1.0` are not (Postgres finds no `1.0` in a
  /// number id), and their text differs too.
  static List<T> _distinct<T>(List<T> values) {
    Map<String, T> byText = <String, T>{};
    for (T value in values) {
      if (value == null) continue;
      String text = '$value';
      if (!byText.containsKey(text)) byText[text] = value;
    }
    return byText.values.toList();
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

/// A row in [table] has this value in [column].
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

  /// One value: the database decides what matches. MySQL, for one,
  /// ignores case. So any row found means the value exists.
  @override
  Future<bool> checkAsync(T value, RuleContext context) async {
    return (await _found(<T>[value])).isNotEmpty;
  }

  Future<Set<String>> _found(List<T> values) {
    return PresenceVerifier._use(verifier).found(
      PresenceVerifier.checkName(table),
      PresenceVerifier.checkName(column),
      values,
      connection: connection,
    );
  }

  /// Many values: one query, see [PresenceVerifier.missingItems].
  @override
  Future<List<int>> failedItems(List<T> values, RuleContext context) {
    return PresenceVerifier.missingItems(values, _found);
  }
}

/// No row in [table] has this value in [column].
/// Made by `v.string().unique('users')`. Use `parseAsync`.
///
/// Give [ignore] to skip one row, like the row being updated:
/// `unique('users', column: 'email', ignore: id)`.
///
/// [column] is required. It is never taken from the input key, because a
/// key in `v.map()` comes from the user.
class UniqueRule<T> extends AsyncRule<T> {
  const UniqueRule(
    this.table, {
    required this.column,
    this.ignore,
    this.ignoreColumn = 'id',
    this.connection,
    this.verifier,
    super.message,
  });

  final String table;
  final String column;

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

  /// One value: the database decides what matches. MySQL, for one,
  /// ignores case. So any row found means the value is taken.
  @override
  Future<bool> checkAsync(T value, RuleContext context) async {
    return (await _found(<T>[value])).isEmpty;
  }

  Future<Set<String>> _found(List<T> values) {
    Object? skip = ignore;
    return PresenceVerifier._use(verifier).found(
      PresenceVerifier.checkName(table),
      PresenceVerifier.checkName(column),
      values,
      exceptColumn: skip == null
          ? null
          : PresenceVerifier.checkName(ignoreColumn),
      exceptValue: skip,
      connection: connection,
    );
  }

  /// Many values: one query, see [PresenceVerifier.takenItems].
  @override
  Future<List<int>> failedItems(List<T> values, RuleContext context) {
    return PresenceVerifier.takenItems(values, _found);
  }
}

/// Thrown by [PresenceVerifier.found] for a list when the database can not
/// compare some of the values with the column, like `abc` for a number
/// column on Postgres. One bad value fails the whole query, so it is not
/// known which items are in the table. The list rules then fail every
/// item. This is the safe side.
class PresenceUnknown implements Exception {
  const PresenceUnknown(this.message);

  final String message;

  @override
  String toString() {
    return 'PresenceUnknown: $message';
  }
}
