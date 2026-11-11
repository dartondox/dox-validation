import '../constants/issue_codes.dart';
import '../constants/schema_constants.dart';
import 'parse_state.dart';

/// Everything a [MessageResolver] needs to build one message.
class MessageRequest {
  MessageRequest({
    required this.code,
    required this.path,
    required this.params,
    required this.fallback,
    this.customMessage,
    this.locale,
  });

  /// Issue code, like `required`.
  final String code;

  /// Path of the value.
  final List<Object> path;

  /// Placeholder values. Always has `field` and `value`.
  final Map<String, Object?> params;

  /// Default template from the rule.
  final String fallback;

  /// Message set on the rule itself, like `.min(3, message: '...')`.
  final String? customMessage;

  /// The language of the request, like `th`, from `Accept-Language`.
  /// `null` when there is none.
  final String? locale;
}

/// Turns issue codes into messages.
///
/// Order of lookup:
/// 1. the message set on the rule (`.min(3, message: '...')`)
/// 2. `messages['path.code']`, like `email.required` or `items.*.name.required`
/// 3. `messages['code']`, like `required`
/// 4. the default English template
///
/// In steps 2 and 3 the Dox code is tried first, then its Laravel name
/// (see [IssueCodes.laravel]): `name.min` also finds `min_length`.
///
/// [attributes] are the names shown for `{field}`, by key, like Laravel's
/// custom attributes: `{'first_name': 'first name'}`.
///
/// For i18n, extend this class and override [resolve], then set
/// [MessageResolver.global] or pass it to `safeParse(messages: ...)`.
class MessageResolver {
  MessageResolver({
    Map<String, String> messages = const <String, String>{},
    Map<String, String> attributes = const <String, String>{},
  }) : _messages = <String, String>{...messages},
       _attributes = <String, String>{...attributes};

  /// The resolver used when none is passed to `parse`.
  static MessageResolver global = MessageResolver();

  final Map<String, String> _messages;

  /// The custom templates, by key.
  Map<String, String> get messages {
    return Map<String, String>.unmodifiable(_messages);
  }

  /// Add or replace templates.
  void setMessages(Map<String, String> messages) {
    _messages.addAll(messages);
  }

  final Map<String, String> _attributes;

  /// The names shown for `{field}`, by key.
  Map<String, String> get attributes {
    return Map<String, String>.unmodifiable(_attributes);
  }

  /// Add or replace names shown for `{field}`.
  void setAttributes(Map<String, String> attributes) {
    _attributes.addAll(attributes);
  }

  /// The name shown for `{field}` of the value at [path], or `null` to
  /// show the key. Looked up in [attributes] by the dotted path, then
  /// with `*` for list indexes, then by the field name (the last text key).
  String? attributeName(List<Object> path) {
    return nameIn(_attributes, path);
  }

  /// The name of [path] in [names]: by the dotted path, then with `*` for
  /// list indexes, then by the field name. `null` when there is none.
  static String? nameIn(Map<String, String> names, List<Object> path) {
    if (names.isEmpty || path.isEmpty) return null;
    return names[path.join('.')] ??
        names[_wildcardPath(path)] ??
        names[ParseState.fieldName(path)];
  }

  /// [messages] at `prefix.code`, else at `prefix.<Laravel name>` (see
  /// [IssueCodes.laravel]). An empty [prefix] looks up the code alone.
  static String? find(
    Map<String, String> messages,
    String prefix,
    String code,
  ) {
    String start = prefix.isEmpty ? '' : '$prefix.';
    String? text = messages['$start$code'];
    if (text != null) return text;
    String? laravel = IssueCodes.laravel[code];
    return laravel == null ? null : messages['$start$laravel'];
  }

  /// Build the final message.
  String resolve(MessageRequest request) {
    String template =
        request.customMessage ??
        _findTemplate(request.code, request.path) ??
        request.fallback;
    return format(template, request.params);
  }

  /// Fill placeholders in [template].
  ///
  /// `{name}` is replaced by `params['name']`. Each `%s` is replaced by
  /// the next item in `params['args']` (old dox style messages).
  String format(String template, Map<String, Object?> params) {
    String result = template;
    for (MapEntry<String, Object?> entry in params.entries) {
      if (entry.key == 'args') {
        continue;
      }
      result = result.replaceAll('{${entry.key}}', _text(entry.value));
    }
    Object? args = params['args'];
    if (args is List<Object?>) {
      for (Object? arg in args) {
        if (!result.contains('%s')) {
          break;
        }
        result = result.replaceFirst('%s', _text(arg));
      }
    }
    return result;
  }

  String? _findTemplate(String code, List<Object> path) {
    if (path.isNotEmpty) {
      String? text =
          find(_messages, path.join('.'), code) ??
          find(_messages, _wildcardPath(path), code);
      if (text != null) return text;
    }
    return find(_messages, '', code);
  }

  static String _wildcardPath(List<Object> path) {
    List<String> parts = <String>[];
    for (Object part in path) {
      parts.add(part is int ? '*' : part.toString());
    }
    return parts.join('.');
  }

  String _text(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }
}

/// Helper to make a short, readable text from a list of values.
class ListText {
  /// Join like `a, b, and c`. Same output as the old dox `joinWithAnd`.
  static String joinWithAnd(List<Object?> values) {
    List<String> items = <String>[];
    for (Object? value in values) {
      items.add(value.toString());
    }
    if (items.length <= 1) {
      return items.join();
    }
    String last = items.removeLast();
    return '${items.join(', ')}, and $last';
  }

  /// `true` when [text] is one of the true words, like `yes` or `1`.
  static bool isTrueWord(String text) {
    return SchemaConstants.trueWords.contains(text.trim().toLowerCase());
  }

  /// `true` when [text] is one of the false words, like `no` or `0`.
  static bool isFalseWord(String text) {
    return SchemaConstants.falseWords.contains(text.trim().toLowerCase());
  }
}
