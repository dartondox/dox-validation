import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

// Runtime parts of `@Dto(trim:, coerce:, attributes:)`, the Laravel names
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
      // like Laravel: the words are case sensitive
      expect(_messages(run(v.any().accepted(), 'Yes')), <String>[
        'The a must be accepted',
      ]);
    });

    test('prohibited and prohibitedIf', () {
      Schema<Object?> field = v.any().optional().prohibited();
      expect(run(field, 'x').issues.single.message, 'The a is prohibited');
      expect(run(field, '  ').success, isTrue);
      expect(run(field, <String>[]).success, isTrue);
      expect(run(field, undefined).success, isTrue);
      Schema<Object?> when = v.any().optional().prohibitedIf('type', 'guest');
      expect(run(when, 'x').success, isTrue);
      ParseResult<Object?> result = run(when, 'x', <String, dynamic>{
        'type': 'guest',
      });
      expect(_codes(result), <String>['prohibited_if']);
      expect(_messages(result), <String>[
        'The a is prohibited when type is guest',
      ]);
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
      // like Laravel: a missing other fails
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
