import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

List<String> codes(ParseResult<Object?> result) {
  return <String>[for (ValidationIssue issue in result.issues) issue.code];
}

void main() {
  group('bail', () {
    test('without bail every rule runs', () {
      StringSchema s = v.string().min(5).email().startsWith('x');
      expect(codes(s.safeParse('ab')), <String>[
        'min_length',
        'email',
        'start_with',
      ]);
      expect(s.bails, false);
    });

    test('with bail the first failed rule stops the others', () {
      StringSchema s = v.string().min(5).email().startsWith('x').bail();
      expect(codes(s.safeParse('ab')), <String>['min_length']);
      expect(codes(v.string().bail().min(5).email().safeParse('ab')), <String>[
        'min_length',
      ]);
      expect(codes(s.safeParse('abcdef')), <String>['email']);
      expect(s.safeParse('x@dox.dev').success, true);
    });

    test('a passing rule does not stop', () {
      StringSchema s = v.string().bail().min(1).email();
      expect(codes(s.safeParse('ab')), <String>['email']);
    });

    test('superRefine with an issue counts as a failure', () {
      StringSchema s = v
          .string()
          .bail()
          .superRefine((String value, RuleContext context) {
            context.addIssue('bad');
          })
          .min(5);
      expect(codes(s.safeParse('ab')), <String>['custom']);
    });

    test('async: later async rules do not run', () async {
      int calls = 0;
      StringSchema s = v.string().bail().min(5).refineAsync((
        String value,
      ) async {
        calls++;
        return false;
      });
      ParseResult<String> result = await s.safeParseAsync('ab');
      expect(codes(result), <String>['min_length']);
      expect(calls, 0);

      StringSchema all = v.string().min(5).refineAsync((String value) async {
        calls++;
        return false;
      });
      expect(codes(await all.safeParseAsync('ab')), <String>[
        'min_length',
        'custom',
      ]);
      expect(calls, 1);
    });

    test('nested: only the rules of the schema it is set on', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'a': v.string().min(5).email(),
        'b': v.string().min(5).email().bail(),
      }).bail();
      expect(
        codes(s.safeParse(<String, Object?>{'a': 'x', 'b': 'x'})),
        <String>['min_length', 'email', 'min_length'],
      );

      ListSchema<String> list = v.list(v.string().min(5).email()).bail();
      expect(codes(list.safeParse(<String>['x'])), <String>[
        'min_length',
        'email',
      ]);
    });

    test('bail on the object stops its own rules', () {
      ObjectSchema s = v
          .object(<String, Schema<Object?>>{'a': v.string()})
          .refine((Map<String, dynamic> m) => false, message: 'one')
          .refine((Map<String, dynamic> m) => false, message: 'two')
          .bail();
      expect(s.safeParse(<String, Object?>{'a': 'x'}).issues.length, 1);
    });

    test('a type error still gives one issue', () {
      StringSchema s = v.string().min(5).email().bail();
      expect(codes(s.safeParse(5)), <String>['string']);
    });
  });

  group('excludeIf and excludeUnless', () {
    ObjectSchema schema = v.object(<String, Schema<Object?>>{
      'type': v.string(),
      'company': v.string().min(3).excludeIf('type', 'person'),
    });

    test('matched: the key is left out and not checked', () {
      Map<String, dynamic> out = schema.parse(<String, Object?>{
        'type': 'person',
        'company': 5,
      });
      expect(out, <String, dynamic>{'type': 'person'});
      expect(out.containsKey('company'), false);
      expect(
        schema.parse(<String, Object?>{'type': 'person'}),
        <String, dynamic>{'type': 'person'},
      );
    });

    test('not matched: the field is checked as usual', () {
      expect(
        codes(schema.safeParse(<String, Object?>{'type': 'shop'})),
        <String>['required'],
      );
      expect(
        codes(
          schema.safeParse(<String, Object?>{'type': 'shop', 'company': 'x'}),
        ),
        <String>['min_length'],
      );
      expect(
        schema.parse(<String, Object?>{'type': 'shop', 'company': 'Dox'}),
        <String, dynamic>{'type': 'shop', 'company': 'Dox'},
      );
    });

    test('a list of values and text matches a number', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'a': v.string().excludeIf('kind', <Object>['1', 'x']),
      });
      expect(
        s.parse(<String, Object?>{'kind': 1, 'a': 5}),
        <String, dynamic>{},
      );
      expect(s.safeParse(<String, Object?>{'kind': 2}).success, false);
    });

    test('excludeIf: the other key missing does not exclude', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'a': v.string().excludeIf('kind', null),
      });
      expect(codes(s.safeParse(<String, Object?>{})), <String>['required']);
      expect(s.parse(<String, Object?>{'kind': null}), <String, dynamic>{});
    });

    test('excludeUnless: the other key missing excludes', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'kind': v.string().optional(),
        'vat': v.string().excludeUnless('kind', 'company'),
      });
      expect(s.parse(<String, Object?>{'vat': 5}), <String, dynamic>{});
      expect(
        s.parse(<String, Object?>{'kind': 'person', 'vat': 'x'}),
        <String, dynamic>{'kind': 'person'},
      );
      expect(codes(s.safeParse(<String, Object?>{'kind': 'company'})), <String>[
        'required',
      ]);
    });

    test('reads the raw value of the other key', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'kind': v.string().transform((String t) => t.toUpperCase()),
        'a': v.string().excludeIf('kind', 'x'),
      });
      expect(s.parse(<String, Object?>{'kind': 'x', 'a': 1}), <String, dynamic>{
        'kind': 'X',
      });
    });

    test('in a list of objects each item is checked on its own', () {
      ListSchema<Map<String, dynamic>> s = v.list(schema);
      List<Map<String, dynamic>> out = s.parse(<Object?>[
        <String, Object?>{'type': 'person', 'company': 1},
        <String, Object?>{'type': 'shop', 'company': 'Dox'},
      ]);
      expect(out, <Map<String, dynamic>>[
        <String, dynamic>{'type': 'person'},
        <String, dynamic>{'type': 'shop', 'company': 'Dox'},
      ]);
      ParseResult<List<Map<String, dynamic>>> bad = s.safeParse(<Object?>[
        <String, Object?>{'type': 'person'},
        <String, Object?>{'type': 'shop'},
      ]);
      expect(bad.issues.single.path, <Object>[1, 'company']);
    });

    test('with optional, nullable and defaultTo, in any order', () {
      Map<String, Object?> excluded = <String, Object?>{'t': 'x', 'a': null};
      Map<String, Object?> missing = <String, Object?>{'t': 'x'};
      List<Schema<Object?>> fields = <Schema<Object?>>[
        v.string().excludeIf('t', 'x').optional(),
        v.string().optional().excludeIf('t', 'x'),
        v.string().excludeIf('t', 'x').nullable(),
        v.string().nullable().excludeIf('t', 'x'),
        v.string().excludeIf('t', 'x').defaultTo('d'),
        v.string().defaultTo('d').excludeIf('t', 'x'),
        v.string().excludeIf('y', 1).excludeIf('t', 'x'),
      ];
      for (Schema<Object?> field in fields) {
        ObjectSchema s = v.object(<String, Schema<Object?>>{'a': field});
        expect(s.parse(excluded), <String, dynamic>{}, reason: '$field');
        expect(s.parse(missing), <String, dynamic>{}, reason: '$field');
      }
      // not matched: the wrappers work as usual
      ObjectSchema d = v.object(<String, Schema<Object?>>{
        'a': v.string().excludeIf('t', 'x').defaultTo('d'),
      });
      expect(d.parse(<String, Object?>{'t': 'y'}), <String, dynamic>{'a': 'd'});
    });

    test('strict and passthrough do not add the key back', () {
      Map<String, Object?> input = <String, Object?>{
        'type': 'person',
        'company': 'x',
      };
      expect(schema.strict().parse(input), <String, dynamic>{'type': 'person'});
      expect(schema.passthrough().parse(input), <String, dynamic>{
        'type': 'person',
      });
      expect(
        codes(schema.strict().safeParse(<String, Object?>{...input, 'z': 1})),
        <String>['unrecognized_keys'],
      );
    });

    test('async', () async {
      int calls = 0;
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'type': v.string(),
        'email': v
            .string()
            .refineAsync((String value) async {
              calls++;
              return true;
            })
            .excludeIf('type', 'guest'),
      });
      expect(
        await s.parseAsync(<String, Object?>{'type': 'guest', 'email': 'x'}),
        <String, dynamic>{'type': 'guest'},
      );
      expect(calls, 0);
      expect(
        await s.parseAsync(<String, Object?>{'type': 'user', 'email': 'x'}),
        <String, dynamic>{'type': 'user', 'email': 'x'},
      );
      expect(calls, 1);
    });

    test('outside an object it does nothing', () {
      Schema<String> top = v.string().min(2).excludeIf('a', 1);
      expect(top.parse('ab'), 'ab');
      expect(codes(top.safeParse('a')), <String>['min_length']);
      ListSchema<String> list = v.list(v.string().excludeUnless('a', 1));
      expect(list.parse(<Object?>['x']), <String>['x']);
    });

    test('JSON Schema: the field is not required', () {
      Map<String, dynamic> json = schema.toJsonSchema();
      expect(json['required'], <String>['type']);
      expect(json['properties']['company'], <String, dynamic>{
        'type': 'string',
        'minLength': 3,
      });
    });

    test('a schema without them is the same as before', () {
      ObjectSchema plain = v.object(<String, Schema<Object?>>{
        'a': v.string(),
        'b': v.string().optional(),
      });
      expect(plain.toJsonSchema()['required'], <String>['a']);
      expect(
        plain.parse(<String, Object?>{'a': 'x', 'b': 'y'}),
        <String, dynamic>{'a': 'x', 'b': 'y'},
      );
    });
  });
}
