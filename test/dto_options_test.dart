import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

// Runtime parts of `@Dto(trim:, coerce:, attributes:)`, the alternate names
// in the message lookup, and the new rules.

const Map<String, String> _none = <String, String>{};
const List<Object> _top = <Object>[];

List<String> _messages(ParseResult<Object?> result) {
  return <String>[for (ValidationIssue i in result.issues) i.message];
}

List<String> _codes(ParseResult<Object?> result) {
  return <String>[for (ValidationIssue i in result.issues) i.code];
}

/// Run [rule] through `s.requiredWhen` on a missing value of `field`.
List<ValidationIssue> _requiredWhen(
  RequiredWhen rule,
  Map<String, dynamic> input, {
  Object? value = undefined,
}) {
  DtoState s = DtoState(root: input);
  s.requiredWhen(rule, value, input, _top, 'field', _none);
  return s.issues;
}

void main() {
  group('@Dto(trim:)', () {
    test('read: blank text gives null only with trim', () {
      DtoState s = DtoState(root: null);
      Map<String, dynamic> input = <String, dynamic>{'a': '  ', 'b': ''};
      expect(s.read(input, 'a', emptyToNull: true), '  ');
      expect(s.read(input, 'a', emptyToNull: true, trim: true), isNull);
      expect(s.read(input, 'b', emptyToNull: true), isNull);
      expect(s.read(input, 'a', trim: true), '  ');
      expect(s.read(input, 'c', emptyToNull: true, trim: true), undefined);
    });

    test('string: blank text is missing when trimmed', () {
      DtoState s = DtoState(root: null);
      expect(s.string('   ', _top, 'a', _none), '   ');
      expect(s.string('   ', _top, 'a', _none, trim: true), undefined);
    });
  });

  group('@Dto(coerce:)', () {
    test('JSON is strict by default', () {
      DtoState s = DtoState(root: null);
      expect(s.integer('18', _top, 'a', _none), invalid);
      expect(s.decimal('4.5', _top, 'b', _none), invalid);
      expect(s.number('18', _top, 'c', _none), invalid);
      expect(s.boolean('true', _top, 'd', _none), invalid);
      expect(s.boolean(1, _top, 'e', _none), invalid);
      expect(
        <String>[for (ValidationIssue i in s.issues) i.code],
        <String>['integer', 'numeric', 'numeric', 'boolean', 'boolean'],
      );
    });

    test('coerce reads text and 1 / 0 in JSON', () {
      DtoState s = DtoState(root: null);
      expect(s.integer('18', _top, 'a', _none, coerce: true), 18);
      expect(s.decimal('4.5', _top, 'b', _none, coerce: true), 4.5);
      expect(s.number('18', _top, 'c', _none, coerce: true), 18);
      expect(s.number('4.5', _top, 'c', _none, coerce: true), 4.5);
      expect(s.boolean('1', _top, 'd', _none, coerce: true), true);
      expect(s.boolean('off', _top, 'd', _none, coerce: true), false);
      expect(s.boolean(1, _top, 'd', _none, coerce: true), true);
      expect(s.boolean(0, _top, 'd', _none, coerce: true), false);
      expect(s.issues, isEmpty);
      expect(s.integer('4.5', _top, 'a', _none, coerce: true), invalid);
      expect(s.boolean(2, _top, 'd', _none, coerce: true), invalid);
      expect(s.boolean('maybe', _top, 'd', _none, coerce: true), invalid);
      expect(s.integer('', _top, 'a', _none, coerce: true), undefined);
    });
  });

  group('attribute names', () {
    test('no names: the key, as before', () {
      DtoState s = DtoState(root: null);
      s.required(_top, 'first_name', _none);
      expect(s.issues.single.message, 'The first_name is required');
      expect(s.issues.single.params['field'], 'first_name');
    });

    test('global names in the MessageResolver', () {
      MessageResolver names = MessageResolver(
        attributes: <String, String>{
          'first_name': 'first name',
          'items.*.qty': 'quantity',
        },
      );
      DtoState s = DtoState(root: null, resolver: names);
      s.required(_top, 'first_name', _none);
      s.required(<Object>['items', 0], 'qty', _none);
      s.required(<Object>['user'], 'first_name', _none);
      s.required(_top, 'email', _none);
      expect(
        <String>[for (ValidationIssue i in s.issues) i.message],
        <String>[
          'The first name is required',
          'The quantity is required',
          'The first name is required',
          'The email is required',
        ],
      );
      // the path still has the key
      expect(s.issues.first.dottedPath, 'first_name');
    });

    test('setAttributes adds names', () {
      MessageResolver names = MessageResolver()
        ..setAttributes(<String, String>{'dob': 'date of birth'});
      expect(names.attributes, <String, String>{'dob': 'date of birth'});
      expect(names.attributeName(<Object>['dob']), 'date of birth');
      expect(names.attributeName(<Object>['other']), isNull);
    });

    test('fluent schemas use the global names', () {
      ObjectSchema schema = v.object(<String, Schema<Object?>>{
        'first_name': v.string().min(3),
      });
      ParseResult<Object?> result = schema.safeParse(
        <String, dynamic>{'first_name': 'ab'},
        messages: MessageResolver(
          attributes: <String, String>{'first_name': 'first name'},
        ),
      );
      expect(_messages(result), <String>[
        'The first name must be at least 3 characters',
      ]);
    });

    test('DTO names win over global names, nested DTOs too', () {
      MessageResolver global = MessageResolver(
        attributes: <String, String>{'city': 'town', 'zip': 'post code'},
      );
      DtoState s = DtoState(root: null, resolver: global);
      s.attributes(_top, const <String, String>{
        'first_name': 'first name',
        'address.zip': 'ZIP',
      });
      s.attributes(
        <Object>['address'],
        const <String, String>{'city': 'city name'},
      );
      s.attributes(
        <Object>['items', 3],
        const <String, String>{'qty': 'quantity'},
      );
      s.required(_top, 'first_name', _none);
      s.required(<Object>['address'], 'city', _none);
      s.required(<Object>['address'], 'zip', _none);
      s.required(<Object>['items', 0], 'qty', _none);
      s.required(_top, 'other', _none);
      // a message from the annotation gets the name too
      s.fail(_top, 'first_name', 'x', 'y', null, message: '{field}!');
      expect(
        <String>[for (ValidationIssue i in s.issues) i.message],
        <String>[
          'The first name is required',
          'The city name is required',
          'The ZIP is required',
          'The quantity is required',
          'The other is required',
          'first name!',
        ],
      );
    });
  });

  group('names for {other} and {others}', () {
    test('no names: the keys, as before', () {
      List<ValidationIssue> issues = _requiredWhen(
        const RequiredWith(<String>['first_name', 'phone']),
        <String, dynamic>{'first_name': 'x'},
      );
      expect(
        issues.single.message,
        'The field is required when first_name or phone is present',
      );
      expect(issues.single.params['others'], 'first_name or phone');
    });

    test('a key with " or " in it keeps its own name', () {
      Map<String, dynamic> input = <String, dynamic>{'this or that': 'x'};
      DtoState s = DtoState(
        root: input,
        resolver: MessageResolver(
          attributes: <String, String>{'this or that': 'choice'},
        ),
      );
      s.requiredWhen(
        const RequiredWith(<String>['this or that']),
        undefined,
        input,
        _top,
        'vat',
        _none,
      );
      expect(
        s.issues.single.message,
        'The vat is required when choice is present',
      );
    });

    test('global and DTO names', () {
      Map<String, dynamic> input = <String, dynamic>{'account_type': 'x'};
      DtoState s = DtoState(
        root: input,
        resolver: MessageResolver(
          attributes: <String, String>{'phone': 'phone number'},
        ),
      );
      s.attributes(_top, const <String, String>{'account_type': 'account'});
      s.requiredWhen(
        const RequiredIf('account_type', 'x'),
        undefined,
        input,
        _top,
        'company',
        _none,
      );
      s.requiredWhen(
        const RequiredWith(<String>['account_type', 'phone']),
        undefined,
        input,
        _top,
        'vat',
        _none,
      );
      expect(
        <String>[for (ValidationIssue i in s.issues) i.message],
        <String>[
          'The company is required when account is x',
          'The vat is required when account or phone number is present',
        ],
      );
    });

    test('fluent rules show the name of the other key', () {
      ParseResult<Object?> result = v
          .object(<String, Schema<Object?>>{
            'old_password': v.string(),
            'password': v.string().different('old_password'),
          })
          .safeParse(
            <String, dynamic>{'old_password': 'a', 'password': 'a'},
            messages: MessageResolver(
              attributes: <String, String>{'old_password': 'old password'},
            ),
          );
      expect(_messages(result), <String>[
        'The password and old password must be different',
      ]);
    });
  });

  group('Laravel names in the message lookup, flag off', () {
    test('name.min does not match a min_length error', () {
      MessageResolver messages = MessageResolver(
        messages: <String, String>{'name.min': 'laravel', 'min': 'number'},
      );
      ParseResult<Object?> result = v
          .object(<String, Schema<Object?>>{
            'name': v.string().min(3),
            'tags': v.list(v.string()).min(2),
          })
          .safeParse(<String, dynamic>{
            'name': 'ab',
            'tags': <String>['x'],
          }, messages: messages);
      expect(_codes(result), <String>['min_length', 'min_items']);
      expect(_messages(result), <String>[
        'The name must be at least 3 characters',
        'The tags must have at least 2 items',
      ]);
    });

    test('DTO messages match only the Dox code', () {
      DtoState s = DtoState(root: null);
      const Map<String, String> m = <String, String>{
        'name.min': 'laravel',
        'gt': 'laravel',
        'age.greater_than': 'age dox',
      };
      s.fail(_top, 'name', IssueCodes.minLength, 'default', 'ab', messages: m);
      s.fail(_top, 'price', IssueCodes.greaterThan, 'default', 0, messages: m);
      s.fail(_top, 'age', IssueCodes.greaterThan, 'x', 0, messages: m);
      expect(
        <String>[for (ValidationIssue i in s.issues) i.message],
        <String>['default', 'default', 'age dox'],
      );
    });
  });

  group('Laravel names in the message lookup, flag on', () {
    setUp(() {
      Validator.flags = const ValidationFlags(laravelMessageKeys: true);
    });

    tearDown(() {
      Validator.flags = const ValidationFlags();
    });

    test('ValidationFlags.all() turns it on', () {
      expect(const ValidationFlags.all().laravelMessageKeys, isTrue);
      expect(const ValidationFlags().laravelMessageKeys, isFalse);
    });

    test('the code does not change', () {
      ParseResult<Object?> result = v
          .object(<String, Schema<Object?>>{'name': v.string().min(3)})
          .safeParse(<String, dynamic>{'name': 'ab'});
      expect(_codes(result), <String>['min_length']);
      expect(_messages(result), <String>[
        'The name must be at least 3 characters',
      ]);
    });

    test('global messages find the Laravel name', () {
      ObjectSchema schema = v.object(<String, Schema<Object?>>{
        'name': v.string().min(3).startsWith('a'),
        'tags': v.list(v.string()).min(2),
      });
      ParseResult<Object?> result = schema.safeParse(
        <String, dynamic>{
          'name': 'ab',
          'tags': <String>['x'],
        },
        messages: MessageResolver(
          messages: <String, String>{
            'name.min': 'Name: {min} or more',
            'min': 'At least {min}',
          },
        ),
      );
      expect(_codes(result), <String>['min_length', 'min_items']);
      expect(_messages(result), <String>['Name: 3 or more', 'At least 2']);
    });

    test('a Dox key wins over a Laravel name at the same step', () {
      MessageResolver messages = MessageResolver(
        messages: <String, String>{
          'name.min': 'laravel',
          'name.min_length': 'dox',
          'starts_with': 'laravel prefix',
        },
      );
      ParseResult<Object?> result = v
          .object(<String, Schema<Object?>>{'name': v.string().min(3)})
          .safeParse(<String, dynamic>{'name': 'ab'}, messages: messages);
      expect(_messages(result), <String>['dox']);
      result = v
          .object(<String, Schema<Object?>>{'name': v.string().startsWith('x')})
          .safeParse(<String, dynamic>{'name': 'ab'}, messages: messages);
      expect(_messages(result), <String>['laravel prefix']);
    });

    test('DTO messages find the Laravel name', () {
      DtoState s = DtoState(root: null);
      const Map<String, String> m = <String, String>{
        'name.min': 'name laravel',
        'tags.*.max': 'tag laravel',
        'gt': 'gt laravel',
        'age.greater_than': 'age dox',
        'age.gt': 'age laravel',
      };
      s.fail(_top, 'name', IssueCodes.minLength, 'x', 'ab', messages: m);
      s.fail(<Object>['tags'], 1, IssueCodes.maxLength, 'x', 'ab', messages: m);
      s.fail(_top, 'price', IssueCodes.greaterThan, 'x', 0, messages: m);
      s.fail(_top, 'age', IssueCodes.greaterThan, 'x', 0, messages: m);
      s.fail(_top, 'other', IssueCodes.minLength, 'default', '', messages: m);
      expect(
        <String>[for (ValidationIssue i in s.issues) i.message],
        <String>[
          'name laravel',
          'tag laravel',
          'gt laravel',
          'age dox',
          'default',
        ],
      );
      expect(s.issues.first.code, 'min_length');
    });
  });

  group('Required* rules', () {
    test('RequiredUnless', () {
      RequiredUnless rule = const RequiredUnless('type', <String>[
        'guest',
        'bot',
      ]);
      expect(_requiredWhen(rule, <String, dynamic>{'type': 'guest'}), isEmpty);
      expect(
        _requiredWhen(rule, <String, dynamic>{}).single.message,
        ('The field is required unless type is guest or bot'),
      );
      List<ValidationIssue> issues = _requiredWhen(rule, <String, dynamic>{
        'type': 'user',
      });
      expect(issues.single.code, 'required_unless');
    });

    test('RequiredWithout and RequiredWithoutAll', () {
      RequiredWithout without = const RequiredWithout(<String>['a', 'b']);
      RequiredWithoutAll all = const RequiredWithoutAll(<String>['a', 'b']);
      Map<String, dynamic> both = <String, dynamic>{'a': 1, 'b': 'x'};
      Map<String, dynamic> one = <String, dynamic>{'a': 1, 'b': ' '};
      Map<String, dynamic> none = <String, dynamic>{'a': null};
      expect(_requiredWhen(without, both), isEmpty);
      expect(_requiredWhen(without, one).single.code, 'required_without');
      expect(
        _requiredWhen(without, one).single.message,
        'The field is required when a or b is not present',
      );
      expect(_requiredWhen(all, one), isEmpty);
      expect(_requiredWhen(all, none).single.code, 'required_without_all');
      expect(
        _requiredWhen(all, none).single.message,
        'The field is required when none of a or b are present',
      );
    });

    test('Filled: a sent key needs a value', () {
      expect(_requiredWhen(const Filled(), <String, dynamic>{}), isEmpty);
      List<ValidationIssue> issues = _requiredWhen(
        const Filled(),
        <String, dynamic>{'field': ''},
      );
      expect(issues.single.code, 'filled');
      expect(issues.single.message, 'The field must have a value');
      expect(
        _requiredWhen(const Filled(), <String, dynamic>{
          'field': null,
        }, value: null).single.code,
        'filled',
      );
    });

    test('Present: the key must be sent', () {
      expect(
        _requiredWhen(const Present(), <String, dynamic>{
          'field': null,
        }, value: null),
        isEmpty,
      );
      expect(
        _requiredWhen(const Present(), <String, dynamic>{'field': ''}),
        isEmpty,
      );
      List<ValidationIssue> issues = _requiredWhen(
        const Present(),
        <String, dynamic>{},
      );
      expect(issues.single.code, 'present');
      expect(issues.single.message, 'The field must be present');
    });

    test('Present does not apply to list items', () {
      ParseResult<Object?> result = v
          .object(<String, Schema<Object?>>{
            't': v.list(v.string().optional().present()),
          })
          .safeParse(<String, dynamic>{
            't': <String>[''],
          });
      expect(_codes(result), isNot(contains('present')));
    });

    test('fluent .optional() rules', () {
      ObjectSchema schema = v.object(<String, Schema<Object?>>{
        'email': v.string().optional().requiredWithout(<String>['phone']),
        'phone': v.string().optional(),
        'code': v.string().optional().requiredUnless('type', 'guest'),
        'type': v.string().optional(),
        'nick': v.string().optional().filled(),
        'note': v.string().optional().present().nullable(),
        'fax': v.string().optional().requiredWithoutAll(<String>[
          'email',
          'phone',
        ]),
      });
      ParseResult<Object?> result = schema.safeParse(<String, dynamic>{
        'type': 'guest',
        'nick': null,
      });
      expect(_codes(result), <String>[
        'required_without',
        'filled',
        'present',
        'required_without_all',
      ]);
      result = schema.safeParse(<String, dynamic>{
        'phone': '1',
        'type': 'user',
        'code': 'x',
        'note': null,
      });
      expect(result.success, isTrue, reason: '${result.issues}');
    });
  });

  group('ExcludeIf and ExcludeUnless', () {
    test('ExcludeIf needs the other key', () {
      ExcludeIf rule = const ExcludeIf('type', 'person');
      expect(rule.appliesTo(<String, dynamic>{'type': 'person'}), isTrue);
      expect(rule.appliesTo(<String, dynamic>{'type': 'company'}), isFalse);
      expect(rule.appliesTo(<String, dynamic>{}), isFalse);
      expect(const ExcludeIf('a', null).appliesTo(<String, dynamic>{}), false);
      expect(
        const ExcludeIf('a', null).appliesTo(<String, dynamic>{'a': null}),
        isTrue,
      );
    });

    test('ExcludeUnless: a missing key is null', () {
      ExcludeUnless rule = const ExcludeUnless('type', <String>['company']);
      expect(rule.appliesTo(<String, dynamic>{'type': 'company'}), isFalse);
      expect(rule.appliesTo(<String, dynamic>{'type': 'person'}), isTrue);
      expect(rule.appliesTo(<String, dynamic>{}), isTrue);
      expect(rule.appliesTo(<String, dynamic>{'type': 1}), isTrue);
    });
  });

  group('new rules', () {
    ParseResult<Object?> run(
      Schema<Object?> field,
      Object? value, [
      Map<String, dynamic> more = const <String, dynamic>{},
    ]) {
      return v
          .object(<String, Schema<Object?>>{
            'a': field,
            'b': v.any().optional(),
            'type': v.any().optional(),
          })
          .safeParse(<String, dynamic>{'a': value, ...more});
    }

    test('accepted and declined', () {
      for (Object value in <Object>[true, 1, '1', 'true', 'yes', 'on']) {
        expect(
          run(v.any().accepted(), value).success,
          isTrue,
          reason: '$value',
        );
        expect(_codes(run(v.any().declined(), value)), <String>['declined']);
      }
      for (Object value in <Object>[false, 0, '0', 'false', 'no', 'off']) {
        expect(
          run(v.any().declined(), value).success,
          isTrue,
          reason: '$value',
        );
        expect(_codes(run(v.any().accepted(), value)), <String>['accepted']);
      }
      // the words are case sensitive
      expect(_messages(run(v.any().accepted(), 'Yes')), <String>[
        'The a must be accepted',
      ]);
    });

    test('prohibited: like Laravel 9.37', () {
      ObjectSchema schema = v.object(<String, Schema<Object?>>{
        'a': v.any().optional().prohibited(),
      });
      List<String> codes(Map<String, dynamic> input) {
        return _codes(schema.safeParse(input));
      }

      // missing and blank text pass
      expect(codes(<String, dynamic>{}), isEmpty);
      expect(codes(<String, dynamic>{'a': ''}), isEmpty);
      expect(codes(<String, dynamic>{'a': '  '}), isEmpty);
      // every other sent value fails, also null and empty ones
      for (Object? value in <Object?>[
        null,
        <String>[],
        <String, dynamic>{},
        0,
        false,
        'x',
      ]) {
        expect(codes(<String, dynamic>{'a': value}), <String>[
          'prohibited',
        ], reason: '$value');
      }
      expect(
        schema.safeParse(<String, dynamic>{'a': 'x'}).issues.single.message,
        'The a is prohibited',
      );
    });

    test('prohibitedIf: only when the other key matches', () {
      ObjectSchema schema = v.object(<String, Schema<Object?>>{
        'type': v.string().optional(),
        'a': v.any().optional().prohibitedIf('type', 'guest'),
      });
      expect(schema.safeParse(<String, dynamic>{'a': 'x'}).success, isTrue);
      // an empty value passes
      for (Object? value in <Object?>[
        null,
        '',
        '  ',
        <String>[],
        <String, dynamic>{},
      ]) {
        expect(
          schema.safeParse(<String, dynamic>{
            'type': 'guest',
            'a': value,
          }).success,
          isTrue,
          reason: '$value',
        );
      }
      for (Object? value in <Object?>[0, false, 'x']) {
        ParseResult<Object?> result = schema.safeParse(<String, dynamic>{
          'type': 'guest',
          'a': value,
        });
        expect(_codes(result), <String>['prohibited_if'], reason: '$value');
        expect(_messages(result), <String>[
          'The a is prohibited when type is guest',
        ]);
      }
    });

    test('DTO: prohibitedIf passes null and fails 0', () {
      Map<String, dynamic> input = <String, dynamic>{
        'type': 'guest',
        'a': null,
        'b': 0,
        'c': <String>[],
        'd': false,
      };
      DtoState s = DtoState(root: input);
      for (String key in <String>['a', 'b', 'c', 'd']) {
        s.requiredWhen(
          const ProhibitedIf('type', 'guest'),
          input[key],
          input,
          _top,
          key,
          _none,
        );
      }
      expect(
        <String>[for (ValidationIssue i in s.issues) i.dottedPath],
        <String>['b', 'd'],
      );
    });

    test('DTO: prohibited runs for sent values too', () {
      Map<String, dynamic> input = <String, dynamic>{
        'a': 5,
        'b': null,
        'c': '',
      };
      DtoState s = DtoState(root: input);
      s.requiredWhen(const Prohibited(), 5, input, _top, 'a', _none);
      s.requiredWhen(const Prohibited(), null, input, _top, 'b', _none);
      s.requiredWhen(const Prohibited(), undefined, input, _top, 'c', _none);
      s.requiredWhen(const Prohibited(), undefined, input, _top, 'd', _none);
      expect(
        <String>[for (ValidationIssue i in s.issues) i.dottedPath],
        <String>['a', 'b'],
      );
    });

    test('different', () {
      Schema<Object?> field = v.any().different('b');
      expect(run(field, 'x').success, isTrue);
      expect(run(field, 'x', <String, dynamic>{'b': 'y'}).success, isTrue);
      expect(_messages(run(field, 'x', <String, dynamic>{'b': 'x'})), <String>[
        'The a and b must be different',
      ]);
      expect(_codes(run(field, 1, <String, dynamic>{'b': '1'})), <String>[
        'different',
      ]);
    });

    test('ulid', () {
      Schema<Object?> field = v.string().ulid();
      expect(run(field, '01ARZ3NDEKTSV4RRFFQ69G5FAV').success, isTrue);
      expect(run(field, '01arz3ndektsv4rrffq69g5fav').success, isTrue);
      expect(_codes(run(field, '81ARZ3NDEKTSV4RRFFQ69G5FAV')), <String>[
        'ulid',
      ]);
      expect(_codes(run(field, '01ARZ3NDEKTSV4RRFFQ69G5FAU1')), <String>[
        'ulid',
      ]);
      expect(_messages(run(field, '01ARZ3NDEKTSV4RRFFQ69G5FIL')), <String>[
        'The a must be a valid ULID',
      ]);
    });

    test('compare with another field', () {
      expect(
        run(v.int().gtField('b'), 5, <String, dynamic>{'b': 4}).success,
        isTrue,
      );
      expect(
        _messages(run(v.int().gtField('b'), 4, <String, dynamic>{'b': 4})),
        <String>['The a must be greater than b'],
      );
      expect(
        _codes(run(v.int().gtField('b'), 4, <String, dynamic>{'b': 4})),
        <String>['greater_than'],
      );
      // a missing other fails
      expect(_codes(run(v.int().gtField('b'), 5)), <String>['greater_than']);
      // text from a form
      expect(
        run(v.int().gteField('b'), 4, <String, dynamic>{'b': '4'}).success,
        isTrue,
      );
      expect(
        _codes(run(v.num().ltField('b'), 4.5, <String, dynamic>{'b': 4})),
        <String>['less_than'],
      );
      expect(
        run(v.int().lteField('b'), 4, <String, dynamic>{'b': 4}).success,
        isTrue,
      );
      expect(
        _messages(run(v.int().lteField('b'), 5, <String, dynamic>{'b': 4})),
        <String>['The a must be less than or equal b'],
      );
    });
  });
}
