import '../dto/file_types.dart';
import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/rule.dart';
import 'built_in_rule.dart';

/// List must have at least [min] items.
class MinItemsRule<T> extends BuiltInRule<List<T>> {
  MinItemsRule(this.min, {super.message})
    : super(
        IssueCodes.minItems,
        DefaultMessages.minItems,
        params: <String, Object?>{'min': min},
        json: <String, dynamic>{'minItems': min},
      );

  final int min;

  @override
  bool check(List<T> value, RuleContext context) {
    return value.length >= min;
  }
}

/// List may have at most [max] items.
class MaxItemsRule<T> extends BuiltInRule<List<T>> {
  MaxItemsRule(this.max, {super.message})
    : super(
        IssueCodes.maxItems,
        DefaultMessages.maxItems,
        params: <String, Object?>{'max': max},
        json: <String, dynamic>{'maxItems': max},
      );

  final int max;

  @override
  bool check(List<T> value, RuleContext context) {
    return value.length <= max;
  }
}

/// Date must be on or after [date].
class AfterOrEqualRule extends BuiltInRule<DateTime> {
  AfterOrEqualRule(this.date, {super.message})
    : super(
        IssueCodes.afterOrEqual,
        DefaultMessages.afterOrEqual,
        params: <String, Object?>{'date': date},
      );

  final DateTime date;

  @override
  bool check(DateTime value, RuleContext context) {
    return !value.isBefore(date);
  }
}

/// Date must be on or before [date].
class BeforeOrEqualRule extends BuiltInRule<DateTime> {
  BeforeOrEqualRule(this.date, {super.message})
    : super(
        IssueCodes.beforeOrEqual,
        DefaultMessages.beforeOrEqual,
        params: <String, Object?>{'date': date},
      );

  final DateTime date;

  @override
  bool check(DateTime value, RuleContext context) {
    return !value.isAfter(date);
  }
}

/// The file must be one of the types [extensions], like `['pdf']`.
/// The real type comes from the first bytes of the file (see [FileTypes]).
class FileExtensionRule extends BuiltInRule<FileInput> {
  FileExtensionRule(
    this.extensions, {
    String code = IssueCodes.file,
    super.message,
  }) : super(
         code,
         DefaultMessages.fileExtension,
         params: <String, Object?>{'extensions': extensions.join(', ')},
       );

  final List<String> extensions;

  @override
  bool check(FileInput value, RuleContext context) {
    return FileTypes.matches(value, extensions);
  }
}

/// A file size as short text for messages, like `2MB` or `1500B`.
String _sizeText(int bytes) {
  const List<String> units = <String>['GB', 'MB', 'KB'];
  for (int i = 0; i < units.length; i++) {
    int unit = 1 << (10 * (units.length - i));
    if (bytes >= unit && bytes % unit == 0) {
      return '${bytes ~/ unit}${units[i]}';
    }
  }
  return '${bytes}B';
}

/// The file may be at most [bytes] long.
class MaxSizeRule extends BuiltInRule<FileInput> {
  MaxSizeRule(this.bytes, {super.message})
    : super(
        IssueCodes.maxSize,
        DefaultMessages.maxSize,
        params: <String, Object?>{'max': _sizeText(bytes)},
        json: <String, dynamic>{'maxLength': bytes},
      );

  final int bytes;

  @override
  bool check(FileInput value, RuleContext context) {
    return value.length <= bytes;
  }
}

/// The file must be at least [bytes] long.
class MinSizeRule extends BuiltInRule<FileInput> {
  MinSizeRule(this.bytes, {super.message})
    : super(
        IssueCodes.minSize,
        DefaultMessages.minSize,
        params: <String, Object?>{'min': _sizeText(bytes)},
        json: <String, dynamic>{'minLength': bytes},
      );

  final int bytes;

  @override
  bool check(FileInput value, RuleContext context) {
    return value.length >= bytes;
  }
}

/// The file must be one of [types] (extensions, like `pdf`). Same check
/// as [FileExtensionRule], with the `mimes` code and message of `@Mimes`.
class MimesRule extends BuiltInRule<FileInput> {
  MimesRule(this.types, {super.message})
    : super(
        IssueCodes.mimes,
        DefaultMessages.mimes,
        params: <String, Object?>{'types': types.join(', ')},
      );

  final List<String> types;

  @override
  bool check(FileInput value, RuleContext context) {
    return FileTypes.matches(value, types);
  }
}

/// The file must be one of [mimeTypes], like `image/png` or `image/*`.
/// The real type comes from the first bytes of the file, not from the
/// content type the client sent (see [FileTypes.matchesMimeTypes]).
class MimeTypesRule extends BuiltInRule<FileInput> {
  MimeTypesRule(this.mimeTypes, {super.message})
    : super(
        IssueCodes.mimeTypes,
        DefaultMessages.mimes,
        params: <String, Object?>{'types': mimeTypes.join(', ')},
        json: <String, dynamic>{'contentMediaType': mimeTypes.join(', ')},
      );

  final List<String> mimeTypes;

  @override
  bool check(FileInput value, RuleContext context) {
    return FileTypes.matchesMimeTypes(value, mimeTypes);
  }
}

/// The file must be a PNG, GIF, WebP or JPEG image whose size fits every
/// limit given. See [ImageSize.fits].
class DimensionsRule extends BuiltInRule<FileInput> {
  DimensionsRule({
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.ratio,
    super.message,
  }) : super(IssueCodes.dimensions, DefaultMessages.dimensions);

  final int? width;
  final int? height;
  final int? minWidth;
  final int? maxWidth;
  final int? minHeight;
  final int? maxHeight;
  final double? ratio;

  @override
  bool check(FileInput value, RuleContext context) {
    return ImageSize.fits(
      value,
      width: width,
      height: height,
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
      ratio: ratio,
    );
  }
}
