/// Regular expressions shared by string rules.
class Patterns {
  /// The local part allows the same symbols as HTML5 (`+`, `'` and more),
  /// split by single dots. Each dot ends a group, so there is no ReDoS.
  static final RegExp email = RegExp(
    r"^[\w!#$%&'*+/=?^`{|}~-]+(\.[\w!#$%&'*+/=?^`{|}~-]+)*@"
    r'[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*(\.[a-zA-Z]{2,})$',
  );
  static final RegExp uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp ipv4 = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
  );
  static final RegExp alpha = RegExp(r'^[a-zA-Z]+$');
  static final RegExp alphaDash = RegExp(r'^[a-zA-Z-_]+$');
  static final RegExp alphaNumeric = RegExp(r'^[a-zA-Z0-9]+$');

  /// ISO 8601 date time, like `2024-01-31T10:00:00Z`.
  static final RegExp isoDateTime = RegExp(
    r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$',
  );
}
