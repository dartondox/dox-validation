import '../constants/default_messages.dart';
import '../validator.dart';
import 'issue.dart';
import 'message_resolver.dart';
import 'sentinels.dart';

/// Data shared by every schema during one parse call.
class ParseState {
  ParseState({
    required this.root,
    MessageResolver? resolver,
    List<ValidationIssue>? issues,
    this.params = const <String, String>{},
    this.locale,
  }) : resolver = resolver ?? MessageResolver.global,
       issues = issues ?? <ValidationIssue>[];

  /// The whole input given to `parse`. Rules use it to read other fields.
  final Object? root;

  /// Builds messages.
  final MessageResolver resolver;

  /// Issues found so far.
  final List<ValidationIssue> issues;

  /// Path params of the request, like `{'id': '5'}`.
  /// `@Unique(ignoreParam: 'id')` reads them.
  final Map<String, String> params;

  /// The language of the request, like `th`. Given to the
  /// [MessageResolver] in [MessageRequest.locale].
  final String? locale;

  /// A fresh state with the same root and resolver. Used by unions to
  /// try each option without keeping the failed issues.
  ParseState fork() {
    return ParseState(
      root: root,
      resolver: resolver,
      params: params,
      locale: locale,
    );
  }

  /// Add one issue and build its message.
  void addIssue({
    required List<Object> path,
    required String code,
    required String fallback,
    Object? value,
    Map<String, Object?> params = const <String, Object?>{},
    String? message,
  }) {
    Map<String, Object?> allParams = <String, Object?>{
      'field': attributeName(path) ?? fieldName(path),
      'value': value is Undefined ? null : value,
      ...params,
    };
    _otherNames(allParams, path);
    if (Validator.flags.shortInMessage && fallback == DefaultMessages.inList) {
      fallback = DefaultMessages.inListShort;
    }
    // a message set on the rule wins over the resolver
    String text = message != null
        ? resolver.format(message, allParams)
        : resolver.resolve(
            MessageRequest(
              code: code,
              path: path,
              params: allParams,
              fallback: fallback,
              locale: locale,
            ),
          );
    issues.add(
      ValidationIssue(
        path: List<Object>.unmodifiable(path),
        code: code,
        message: text,
        params: allParams,
      ),
    );
  }

  /// The name shown for the value at [path], or `null` to show the key.
  /// See [MessageResolver.attributeName].
  String? attributeName(List<Object> path) {
    return resolver.attributeName(path);
  }

  /// `{other}` and `{others}` are keys next to [path]. Show their names,
  /// like Laravel. With no names set, nothing changes.
  void _otherNames(Map<String, Object?> params, List<Object> path) {
    List<Object> parent = path.isEmpty
        ? path
        : path.sublist(0, path.length - 1);
    Object? other = params['other'];
    if (other is String) {
      params['other'] = attributeName(<Object>[...parent, other]) ?? other;
    }
    Object? others = params['others'];
    if (others is String) {
      // ponytail: the keys come joined with ' or ' (RequiredWhenIssue)
      params['others'] = <String>[
        for (String key in others.split(' or '))
          attributeName(<Object>[...parent, key]) ?? key,
      ].join(' or ');
    }
  }

  /// The name used for `{field}`: the last text key in the path.
  static String fieldName(List<Object> path) {
    for (int i = path.length - 1; i >= 0; i--) {
      Object part = path[i];
      if (part is String) {
        return part;
      }
    }
    return 'value';
  }
}
