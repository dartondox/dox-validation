import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

// Hand-written DTO schemas in the shape of the dox_builder output.

class Address {
  const Address(this.city);
  final String city;
}

class Order {
  const Order(this.address);
  final Address address;
}

class Company {
  const Company(this.type, this.vat);
  final String? type;
  final String? vat;
}

class _AddressDto extends DtoSchema<Address> {
  const _AddressDto();

  static const Map<String, String> _m = <String, String>{
    'city.required': 'nested city',
  };

  @override
  Type get type => Address;

  @override
  String get name => 'Address';

  @override
  bool get usesRequiredWhen => false;

  @override
  Address? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    Object? c0 = s.string(s.read(input, 'city'), p, 'city', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'city', _m);
    if (s.issues.length != e) return null;
    return Address(c0 as String);
  }

  @override
  Address fromMap(Map<String, dynamic> input) {
    return Address(input['city'] as String);
  }

  @override
  Map<String, dynamic> toMap(Address value) {
    return <String, dynamic>{'city': value.city};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'type': 'object'};
  }
}

class _OrderDto extends DtoSchema<Order> {
  const _OrderDto();

  static const Map<String, String> _m = <String, String>{
    'address.city.required': 'root city',
  };

  @override
  Type get type => Order;

  @override
  String get name => 'Order';

  @override
  bool get usesRequiredWhen => false;

  @override
  Order? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    Object? c0 = s.object(s.read(input, 'address'), p, 'address', _m);
    if (c0 is Map) {
      c0 =
          const _AddressDto().convert(c0, s, <Object>[...p, 'address']) ??
          invalid;
    }
    if (c0 == null || c0 is Undefined) s.required(p, 'address', _m);
    if (s.issues.length != e) return null;
    return Order(c0 as Address);
  }

  @override
  Order fromMap(Map<String, dynamic> input) {
    return Order(
      const _AddressDto().fromMap(input['address'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toMap(Order value) {
    return <String, dynamic>{
      'address': const _AddressDto().toMap(value.address),
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'type': 'object'};
  }
}

/// `vat` is required when the trimmed, lower case `type` is `company`.
/// [withRules] is what dox_builder knows: `false` is a wrong flag, to show
/// that the flag turns off the kept values.
class _CompanyDto extends DtoSchema<Company> {
  const _CompanyDto({this.withRules = true});

  final bool withRules;

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => Company;

  @override
  String get name => 'Company';

  @override
  bool get usesRequiredWhen => withRules;

  @override
  Company? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    Object? c0 = s.string(
      s.read(input, 'type'),
      p,
      'type',
      _m,
      trim: true,
      textCase: 1,
    );
    Object? c1 = s.string(s.read(input, 'vat'), p, 'vat', _m);
    s.requiredWhen(
      const RequiredIf('type', 'company'),
      c1,
      input,
      p,
      'vat',
      _m,
    );
    if (s.issues.length != e) return null;
    return Company(
      c0 is Undefined ? null : c0 as String?,
      c1 is Undefined ? null : c1 as String?,
    );
  }

  @override
  Company fromMap(Map<String, dynamic> input) {
    return Company(input['type'] as String?, input['vat'] as String?);
  }

  @override
  Map<String, dynamic> toMap(Company value) {
    return <String, dynamic>{'type': value.type, 'vat': value.vat};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'type': 'object'};
  }
}

void main() {
  group('DTO schema |', () {
    test('a nested DTO message beats the full path in the root', () async {
      ParseResult<Order> result = await const _OrderDto().safeValidateMap(
        <String, dynamic>{'address': <String, dynamic>{}},
      );
      expect(result.issues.single.dottedPath, 'address.city');
      expect(result.issues.single.message, 'nested city');
    });

    test('@RequiredIf reads the converted value of the other field', () async {
      ParseResult<Company> result = await const _CompanyDto().safeValidateMap(
        <String, dynamic>{'type': ' Company '},
      );
      expect(result.issues.single.code, IssueCodes.requiredIf);
    });

    test('usesRequiredWhen false: the converted values are not kept', () async {
      DtoState state = DtoState(root: <String, dynamic>{'type': ' Company '});
      ParseResult<Company> result = await const _CompanyDto(withRules: false)
          .run(<String, dynamic>{'type': ' Company '}, state);
      expect(state.keepValues, isFalse);
      // the raw ' Company ' is read, so the rule does not apply
      expect(result.success, isTrue);
    });

    test('run turns keepValues back on in a reused state', () async {
      DtoState state = DtoState(root: <String, dynamic>{});
      await const _CompanyDto(withRules: false)
          .run(<String, dynamic>{'type': 'person'}, state);
      expect(state.keepValues, isFalse);
      ParseResult<Company> result = await const _CompanyDto().run(
        <String, dynamic>{'type': ' Company '},
        state,
      );
      expect(state.keepValues, isTrue);
      expect(result.issues.single.code, IssueCodes.requiredIf);
    });

    test('a DTO with the rules turns keepValues back on', () async {
      DtoState state = DtoState(root: <String, dynamic>{}, keepValues: false);
      Object? value = const _CompanyDto().parseType(
        <String, dynamic>{'type': ' Company '},
        state,
        const <Object>[],
      );
      expect(state.keepValues, isTrue);
      expect(value, same(invalid));
      expect(state.issues.single.code, IssueCodes.requiredIf);
    });

    test('a DTO in a fluent schema keeps the values it needs', () {
      ObjectSchema schema = v.object(<String, Schema<Object?>>{
        'company': const _CompanyDto(),
      });
      ParseResult<Map<String, Object?>> result = schema.safeParse(
        <String, dynamic>{
          'company': <String, dynamic>{'type': ' Company '},
        },
      );
      expect(result.issues.single.dottedPath, 'company.vat');
    });
  });
}
