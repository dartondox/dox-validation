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
  ///
  /// Each isolate has its own static value. So set it where every isolate
  /// runs it, like a provider's `setup()`. dox_orm sets it when the
  /// database driver is set.
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

  /// The indexes of [values] that [find] found in the database.
  ///
  /// The found values come back as text, and first they are matched to
  /// the items as text. But the database can match more: MySQL ignores
  /// case, and `1.0` finds the row `1`. So when the database found
  /// something and some items did not match, those items are asked again
  /// in one query. Only when that query finds something, the items are
  /// split in two halves, and each half is asked again, down to one item.
  /// So the database answer is used, and the number of queries stays
  /// small: 2 in the usual case, and about `2 * log2(n)` more for each
  /// item that only the database matches. Never one query per item.
  static Future<Set<int>> foundItems<T>(
    List<T> values,
    Future<Set<String>> Function(List<T> values) find,
  ) async {
    Set<String> found = await find(values);
    Set<int> hits = <int>{};
    for (int i = 0; i < values.length; i++) {
      if (found.contains('${values[i]}')) hits.add(i);
    }
    if (found.isEmpty || hits.length == values.length) return hits;
    List<int> rest = <int>[
      for (int i = 0; i < values.length; i++)
        if (!hits.contains(i)) i,
    ];
    await _split(values, rest, find, hits);
    return hits;
  }

  /// Ask for the items at [rest] in one query. When the database finds
  /// something, split them in two halves and ask again, down to one item.
  static Future<void> _split<T>(
    List<T> values,
    List<int> rest,
    Future<Set<String>> Function(List<T> values) find,
    Set<int> hits,
  ) async {
    if ((await find(<T>[for (int i in rest) values[i]])).isEmpty) return;
    if (rest.length == 1) {
      hits.add(rest.single);
      return;
    }
    int mid = rest.length ~/ 2;
    await _split(values, rest.sublist(0, mid), find, hits);
    await _split(values, rest.sublist(mid), find, hits);
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

  /// Many values: see [PresenceVerifier.foundItems].
  @override
  Future<List<int>> failedItems(List<T> values, RuleContext context) async {
    Set<int> found = await PresenceVerifier.foundItems(values, _found);
    return <int>[
      for (int i = 0; i < values.length; i++)
        if (!found.contains(i)) i,
    ];
  }
}

/// No row in [table] has this value in [column]. Laravel `unique`.
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

  /// Many values: see [PresenceVerifier.foundItems].
  @override
  Future<List<int>> failedItems(List<T> values, RuleContext context) async {
    Set<int> taken = await PresenceVerifier.foundItems(values, _found);
    return taken.toList()..sort();
  }
}
