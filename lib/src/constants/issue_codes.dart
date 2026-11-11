/// Codes used in [ValidationIssue.code].
///
/// The same codes work for DTOs and fluent schemas, so one message map
/// works for both.
class IssueCodes {
  static const String required = 'required';
  static const String string = 'string';
  static const String integer = 'integer';
  static const String numeric = 'numeric';
  static const String double = 'double';
  static const String boolean = 'boolean';
  static const String date = 'date';
  static const String array = 'array';
  static const String object = 'object';
  static const String json = 'json';
  static const String file = 'file';
  static const String image = 'image';
  static const String inList = 'in';
  static const String notIn = 'not_in';
  static const String literal = 'literal';
  static const String union = 'union';
  static const String unrecognizedKeys = 'unrecognized_keys';
  static const String custom = 'custom';

  static const String minLength = 'min_length';
  static const String maxLength = 'max_length';
  static const String length = 'length';
  static const String lengthBetween = 'length_between';
  static const String email = 'email';
  static const String url = 'url';
  static const String uuid = 'uuid';
  static const String ip = 'ip';
  static const String regex = 'regex';
  static const String startWith = 'start_with';
  static const String endWith = 'end_with';
  static const String includes = 'includes';
  static const String alpha = 'alpha';
  static const String alphaDash = 'alpha_dash';
  static const String alphaNumeric = 'alpha_numeric';
  static const String datetime = 'datetime';

  static const String min = 'min';
  static const String max = 'max';
  static const String between = 'between';
  static const String greaterThan = 'greater_than';
  static const String lessThan = 'less_than';
  static const String multipleOf = 'multiple_of';

  static const String minItems = 'min_items';
  static const String maxItems = 'max_items';
  static const String uniqueItems = 'unique_items';

  static const String after = 'after';
  static const String before = 'before';

  static const String maxSize = 'max_size';
  static const String mimes = 'mimes';
  static const String minSize = 'min_size';
  static const String mimeTypes = 'mime_types';
  static const String dimensions = 'dimensions';

  static const String afterOrEqual = 'after_or_equal';
  static const String beforeOrEqual = 'before_or_equal';

  static const String same = 'same';
  static const String confirmed = 'confirmed';
  static const String requiredIf = 'required_if';
  static const String requiredWith = 'required_with';
  static const String exists = 'exists';
  static const String unique = 'unique';
  static const String digits = 'digits';
  static const String digitsBetween = 'digits_between';
  static const String hexColor = 'hex_color';
  static const String dateFormat = 'date_format';
  static const String password = 'password';

  static const String requiredUnless = 'required_unless';
  static const String requiredWithout = 'required_without';
  static const String requiredWithoutAll = 'required_without_all';
  static const String filled = 'filled';
  static const String present = 'present';
  static const String accepted = 'accepted';
  static const String declined = 'declined';
  static const String prohibited = 'prohibited';
  static const String prohibitedIf = 'prohibited_if';
  static const String different = 'different';
  static const String ulid = 'ulid';

  /// The Laravel rule name of each code that has another name in Dox.
  /// Only the lookup of custom messages uses it, and only when
  /// `ValidationFlags.laravelMessageKeys` is on: `name.min` finds a
  /// message for the `min_length` issue of `name`. The issue code stays
  /// `min_length`. A key with the Dox code wins over the Laravel name.
  static const Map<String, String> laravel = <String, String>{
    minLength: 'min',
    maxLength: 'max',
    length: 'size',
    lengthBetween: 'between',
    startWith: 'starts_with',
    endWith: 'ends_with',
    alphaNumeric: 'alpha_num',
    greaterThan: 'gt',
    lessThan: 'lt',
    minItems: 'min',
    maxItems: 'max',
    uniqueItems: 'distinct',
    minSize: 'min',
    maxSize: 'max',
    mimeTypes: 'mimetypes',
    datetime: 'date',
  };
}
