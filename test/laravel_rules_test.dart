import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

/// A fake database: table.column => values.
class FakeVerifier extends PresenceVerifier {
  FakeVerifier(this.rows, {this.ignoreCase = false});

  /// Like MySQL: `TAKEN@dox.dev` finds the row `taken@dox.dev`.
  final bool ignoreCase;

  /// `users.email` => the rows, each row is `{column: value}`.
  final Map<String, List<Map<String, Object?>>> rows;

  final List<String> calls = <String>[];

  @override
  Future<Set<String>> found(
    String table,
    String column,
    List<Object?> values, {
    String? exceptColumn,
    Object? exceptValue,
    String? connection,
  }) async {
    calls.add('$table.$column except $exceptColumn=$exceptValue');
    String key(Object? value) {
      // like SQL: 1.0 = 1
      if (value is double && value == value.truncateToDouble()) {
        value = value.toInt();
      }
      return ignoreCase ? '$value'.toLowerCase() : '$value';
    }

    Set<String> wanted = <String>{for (Object? value in values) key(value)};
    Set<String> result = <String>{};
    for (Map<String, Object?> row in rows[table] ?? <Map<String, Object?>>[]) {
      if (exceptColumn != null && '${row[exceptColumn]}' == '$exceptValue') {
        continue;
      }
      String value = '${row[column]}';
      if (wanted.contains(key(value))) result.add(value);
    }
    return result;
  }
}

/// Like Postgres with `abc` in a list for a number column.
class UnknownVerifier extends PresenceVerifier {
  @override
  Future<Set<String>> found(
    String table,
    String column,
    List<Object?> values, {
    String? exceptColumn,
    Object? exceptValue,
    String? connection,
  }) async {
    throw const PresenceUnknown('abc is not a number');
  }
}

enum Kind { person, company }

ValidationIssue only(ParseResult<Object?> result) {
  expect(result.success, false);
  expect(result.issues, hasLength(1));
  return result.issues.first;
}

void main() {
  group('same and confirmed |', () {
    ObjectSchema form = v.object(<String, Schema<Object?>>{
      'password': v.string().confirmed(),
      'email': v.string(),
      'email_again': v.string().same('email'),
    });

    test('pass when the values match', () {
      expect(
        form.safeParse(<String, dynamic>{
          'password': 'secret',
          'password_confirmation': 'secret',
          'email': 'a@dox.dev',
          'email_again': 'a@dox.dev',
        }).success,
        true,
      );
    });

    test('confirmed fails on a wrong or missing confirmation', () {
      ValidationIssue issue = only(
        form.safeParse(<String, dynamic>{
          'password': 'secret',
          'password_confirmation': 'other',
          'email': 'a@dox.dev',
          'email_again': 'a@dox.dev',
        }),
      );
      expect(issue.code, IssueCodes.confirmed);
      expect(issue.dottedPath, 'password');
      expect(issue.message, 'The password confirmation does not match');
      expect(
        form.safeParse(<String, dynamic>{
          'password': 'secret',
          'email': 'a@dox.dev',
          'email_again': 'a@dox.dev',
        }).success,
        false,
      );
    });

    test('same fails with its message', () {
      ValidationIssue issue = only(
        form.safeParse(<String, dynamic>{
          'password': 'secret',
          'password_confirmation': 'secret',
          'email': 'a@dox.dev',
          'email_again': 'b@dox.dev',
        }),
      );
      expect(issue.code, IssueCodes.same);
      expect(issue.message, 'The email_again must match email');
    });

    test('confirmed with another key, and in a nested object', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'user': v.object(<String, Schema<Object?>>{
          'pin': v.coerce.int().confirmed(other: 'pin_again'),
        }),
      });
      expect(
        s.safeParse(<String, dynamic>{
          'user': <String, dynamic>{'pin': '1234', 'pin_again': '1234'},
        }).success,
        true,
      );
      // a number matches the same text
      expect(
        s.safeParse(<String, dynamic>{
          'user': <String, dynamic>{'pin': 1234, 'pin_again': '1234'},
        }).success,
        true,
      );
      ValidationIssue issue = only(
        s.safeParse(<String, dynamic>{
          'user': <String, dynamic>{'pin': 1234, 'pin_again': 4321},
        }),
      );
      expect(issue.dottedPath, 'user.pin');
    });

    test('a custom message', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'a': v.string().same('b', message: 'A and B differ'),
      });
      expect(
        only(s.safeParse(<String, dynamic>{'a': 'x', 'b': 'y'})).message,
        'A and B differ',
      );
    });

    test('compares raw input: trim() does not count', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'code': v.string().trim().confirmed(),
      });
      expect(
        s.safeParse(<String, dynamic>{
          'code': ' ab ',
          'code_confirmation': ' ab ',
        }).success,
        true,
      );
      expect(
        s.safeParse(<String, dynamic>{
          'code': ' ab ',
          'code_confirmation': 'ab',
        }).success,
        false,
      );
    });

    test('text and numbers match both ways', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'a': v.any().same('b'),
      });
      expect(
        s.safeParse(<String, dynamic>{'a': '1234', 'b': 1234}).success,
        true,
      );
      expect(
        s.safeParse(<String, dynamic>{'a': 1234, 'b': '1234'}).success,
        true,
      );
      expect(
        s.safeParse(<String, dynamic>{'a': true, 'b': 'true'}).success,
        true,
      );
      expect(
        s.safeParse(<String, dynamic>{'a': '12', 'b': 1234}).success,
        false,
      );
      expect(Same.matches(<Object?>['a'], <Object?>['a']), false);
    });

    test('Same.matches uses the last value of a repeated text key', () {
      expect(Same.matches('b', <Object?>['a', 'b']), true);
      expect(Same.matches('a', <Object?>['a', 'b']), false);
      expect(Same.matches('a', undefined), false);
      expect(Same.matches('a', <Object?>[]), false);
      expect(Same.matches(<Object?>['a', 'b'], 'b'), true);
    });
  });

  group('requiredIf and requiredWith |', () {
    ObjectSchema form = v.object(<String, Schema<Object?>>{
      'type': v.string(),
      'company': v.string().optional().requiredIf('type', 'company'),
      'phone': v.string().optional(),
      'country_code': v.string().nullish().requiredWith(<String>['phone']),
    });

    test('pass when the condition is not met', () {
      expect(form.safeParse(<String, dynamic>{'type': 'person'}).success, true);
    });

    test('requiredIf fails when the other key has the value', () {
      ValidationIssue issue = only(
        form.safeParse(<String, dynamic>{'type': 'company'}),
      );
      expect(issue.code, IssueCodes.requiredIf);
      expect(issue.dottedPath, 'company');
      expect(issue.message, 'The company is required when type is company');
      expect(
        form.safeParse(<String, dynamic>{'type': 'company', 'company': 'Dox'}),
        isA<ParseResult<Map<String, dynamic>>>().having(
          (ParseResult<Map<String, dynamic>> r) => r.success,
          'success',
          true,
        ),
      );
    });

    test('requiredIf reads the converted value of the other key', () async {
      // vat comes first: the order of the keys does not matter
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'vat': v.string().optional().requiredIf('type', 'company'),
        'type': v.string().trim().toLowerCase(),
      });
      Map<String, dynamic> padded = <String, dynamic>{'type': ' Company '};
      expect(only(s.safeParse(padded)).code, IssueCodes.requiredIf);
      expect(only(await s.safeParseAsync(padded)).code, IssueCodes.requiredIf);
      // the plain case still works
      expect(
        only(s.safeParse(<String, dynamic>{'type': 'company'})).code,
        IssueCodes.requiredIf,
      );
      expect(s.safeParse(<String, dynamic>{'type': ' Person '}).success, true);
      // the output keeps the order of the shape
      expect(
        s.parse(<String, dynamic>{'type': ' Company ', 'vat': 'V1'}).keys,
        <String>['vat', 'type'],
      );
      // the other key fails its own check: the raw value is used
      ObjectSchema n = v.object(<String, Schema<Object?>>{
        'type': v.string().min(20),
        'vat': v.string().optional().requiredIf('type', 'company'),
      });
      expect(
        n
            .safeParse(<String, dynamic>{'type': 'company'})
            .issues
            .map((ValidationIssue i) => i.code),
        contains(IssueCodes.requiredIf),
      );
    });

    test('blank text counts as missing', () {
      expect(
        form.safeParse(<String, dynamic>{
          'type': 'company',
          'company': '  ',
        }).success,
        false,
      );
    });

    test('requiredWith fails when the other key is present', () {
      ValidationIssue issue = only(
        form.safeParse(<String, dynamic>{'type': 'x', 'phone': '0812345678'}),
      );
      expect(issue.code, IssueCodes.requiredWith);
      expect(
        issue.message,
        'The country_code is required when phone is present',
      );
      // null is missing too
      expect(
        form.safeParse(<String, dynamic>{
          'type': 'x',
          'phone': '0812345678',
          'country_code': null,
        }).success,
        false,
      );
      expect(
        form.safeParse(<String, dynamic>{
          'type': 'x',
          'phone': '0812345678',
          'country_code': '+66',
        }).success,
        true,
      );
    });

    test('.nullable() after requiredIf still checks null', () async {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'type': v.string(),
        'vat': v.string().optional().requiredIf('type', 'company').nullable(),
        'tel': v.string().optional().requiredWith(<String>['fax']).nullable(),
      });
      Map<String, dynamic> company = <String, dynamic>{
        'type': 'company',
        'vat': null,
      };
      expect(only(s.safeParse(company)).code, IssueCodes.requiredIf);
      expect(only(await s.safeParseAsync(company)).code, IssueCodes.requiredIf);
      expect(
        only(
          s.safeParse(<String, dynamic>{'type': 'x', 'fax': '1', 'tel': null}),
        ).code,
        IssueCodes.requiredWith,
      );
      // null still passes when the rule does not apply
      expect(
        s.safeParse(<String, dynamic>{'type': 'person', 'vat': null}).success,
        true,
      );
    });

    test('a list of values, text matches numbers and booleans', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'kind': v.any(),
        'note': v.string().optional().requiredIf('kind', <Object>[
          'a',
          2,
          true,
        ]),
      });
      expect(s.safeParse(<String, dynamic>{'kind': 'a'}).success, false);
      expect(s.safeParse(<String, dynamic>{'kind': '2'}).success, false);
      expect(s.safeParse(<String, dynamic>{'kind': 'true'}).success, false);
      expect(s.safeParse(<String, dynamic>{'kind': 'b'}).success, true);
      ValidationIssue issue = only(s.safeParse(<String, dynamic>{'kind': 2}));
      expect(issue.message, 'The note is required when kind is a or 2 or true');
    });

    test(
      'custom message, async parse, and JSON Schema stays optional',
      () async {
        OptionalSchema<String> note = v.string().optional().requiredWith(
          <String>['a', 'b'],
          message: 'Need {field}',
        );
        ObjectSchema s = v.object(<String, Schema<Object?>>{'note': note});
        ParseResult<Map<String, dynamic>> result = await s.safeParseAsync(
          <String, dynamic>{'b': 'x'},
        );
        expect(only(result).message, 'Need note');
        expect(s.toJsonSchema()['required'], isNull);
        expect(
          RequiredWhenIssue(const RequiredWith(<String>['a', 'b'])).params,
          <String, Object?>{'others': 'a or b'},
        );
      },
    );

    test('an enum value matches its name', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'kind': v.string(),
        'company': v.string().optional().requiredIf('kind', Kind.company),
      });
      expect(
        only(s.safeParse(<String, dynamic>{'kind': 'company'})).message,
        'The company is required when kind is company',
      );
      expect(s.safeParse(<String, dynamic>{'kind': 'person'}).success, true);
      expect(
        const RequiredIf('kind', <Kind>[
          Kind.person,
        ]).appliesTo(<String, dynamic>{'kind': 'person'}),
        true,
      );
    });

    test('rules added after requiredIf keep it', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'a': v.any(),
        'b': v
            .string()
            .optional()
            .requiredIf('a', 1)
            .refine((String? value) => true),
      });
      expect(s.safeParse(<String, dynamic>{'a': 1}).success, false);
    });
  });

  group('json |', () {
    test('pass and fail', () {
      expect(v.string().json().safeParse('{"a":1}').success, true);
      expect(v.string().json().safeParse('[1, 2]').success, true);
      ValidationIssue issue = only(v.string().json().safeParse('{a:1}'));
      expect(issue.code, IssueCodes.json);
      expect(issue.message, 'The value is not a valid json');
      expect(
        v.string().json().toJsonSchema()['contentMediaType'],
        'application/json',
      );
    });
  });

  group('digits and between |', () {
    test('digits', () {
      expect(v.string().digits(4).safeParse('0123').success, true);
      expect(v.string().digits(4).safeParse('123').success, false);
      expect(v.string().digits(4).safeParse('12a4').success, false);
      expect(v.string().digits(2).safeParse('-1').success, false);
      ValidationIssue issue = only(v.string().digits(4).safeParse('12345'));
      expect(issue.code, IssueCodes.digits);
      expect(issue.message, 'The value must be 4 digits');
      expect(v.string().digits(4).toJsonSchema()['pattern'], r'^[0-9]{4}$');
    });

    test('digitsBetween', () {
      StringSchema s = v.string().digitsBetween(4, 6);
      expect(s.safeParse('1234').success, true);
      expect(s.safeParse('123456').success, true);
      expect(s.safeParse('123').success, false);
      expect(s.safeParse('1234567').success, false);
      expect(s.safeParse('12.45').success, false);
      ValidationIssue issue = only(s.safeParse('1'));
      expect(issue.code, IssueCodes.digitsBetween);
      expect(issue.message, 'The value must be between 4 and 6 digits');
    });

    test('between for numbers', () {
      expect(v.int().between(1, 10).safeParse(1).success, true);
      expect(v.int().between(1, 10).safeParse(10).success, true);
      expect(v.num().between(1, 2).safeParse(1.5).success, true);
      ValidationIssue issue = only(v.int().between(1, 10).safeParse(11));
      expect(issue.code, IssueCodes.between);
      expect(issue.message, 'The value must be between 1 and 10');
      expect(v.int().between(1, 10).toJsonSchema(), <String, dynamic>{
        'type': 'integer',
        'minimum': 1,
        'maximum': 10,
      });
    });
  });

  group('dateFormat |', () {
    test('names, 12 hour time and more PHP letters', () {
      bool m(String value, String format) {
        return DateFormatted.matches(value, format);
      }

      expect(m('01 Jan 2024', 'd M Y'), true);
      expect(m('01 M 2024', 'd M Y'), false);
      expect(m('01 jan 2024', 'd M Y'), false);
      expect(m('January 5, 2024', 'F j, Y'), true);
      expect(m('Mon, 01 Jan 2024', 'D, d M Y'), true);
      expect(m('Tue, 01 Jan 2024', 'D, d M Y'), false); // it was a Monday
      expect(m('Monday 1st January', 'l jS F'), true);
      expect(m('Monday 1nd January', 'l jS F'), false);
      expect(m('22nd', 'jS'), true);
      expect(m('11th', 'jS'), true);
      expect(m('12:30 PM', 'h:i A'), true);
      expect(m('h:30 A', 'h:i A'), false);
      expect(m('13:30 PM', 'h:i A'), false);
      expect(m('9:05 am', 'g:i a'), true);
      expect(m('2024-01-31 9:05 pm 21', 'Y-m-d g:i a H'), true);
      expect(m('2024-01-31 9:05 pm 09', 'Y-m-d g:i a H'), false);
      expect(m('1700000000', 'U'), true);
      expect(m('2024-01-31T10:00:00+07:00', 'c'), true);
      expect(m('Wed, 31 Jan 2024 10:00:00 +0700', 'r'), true);
      expect(m('2024-02 29', 'Y-m t'), true);
      expect(m('2023-02 29', 'Y-m t'), false);
      expect(m('2024 1', 'Y L'), true);
      expect(m('2023 1', 'Y L'), false);
      expect(m('2024-02-01 31', 'Y-m-d z'), true);
      expect(m('2024-02-01 30', 'Y-m-d z'), false);
      expect(m('2024-01-01 1 1', 'Y-m-d N w'), true);
      expect(m('10:00 Z', 'H:i p'), true);
      expect(m('10:00 Asia/Bangkok', 'H:i e'), true);
      expect(m('10:00 UTC', 'H:i T'), true);
    });

    test('no leading zero for j, n, g, G, z and U, like Laravel', () {
      bool m(String value, String format) {
        return DateFormatted.matches(value, format);
      }

      expect(m('1/2/2024', 'j/n/Y'), true);
      expect(m('01/02/2024', 'j/n/Y'), false);
      expect(m('9:05', 'g:i'), true);
      expect(m('09:05', 'g:i'), false);
      expect(m('0:05', 'G:i'), true);
      expect(m('00:05', 'G:i'), false);
      expect(m('24:05', 'G:i'), false);
      expect(m('0', 'z'), true);
      expect(m('031', 'z'), false);
      expect(m('0', 'U'), true);
      expect(m('-5', 'U'), true);
      expect(m('0170', 'U'), false);
    });

    test('an unknown letter throws, an escaped one is text', () {
      expect(
        () => DateFormatted.matches('2024-W01', 'Y-\\WW'),
        throwsArgumentError,
      );
      expect(() => v.string().dateFormat('Y-W'), throwsArgumentError);
      expect(() => v.string().dateFormat('Y-q'), throwsArgumentError);
      expect(DateFormatted.matches('2024-W', r'Y-\W'), true);
      expect(DateFormatted.matches('2024 at 10', r'Y \a\t H'), true);
    });

    test('Y-m-d', () {
      StringSchema s = v.string().dateFormat('Y-m-d');
      expect(s.safeParse('2024-02-29').success, true);
      expect(s.safeParse('2023-02-29').success, false);
      expect(s.safeParse('2024-13-01').success, false);
      expect(s.safeParse('2024-1-01').success, false);
      expect(s.safeParse('2024-01-01 10:00').success, false);
      ValidationIssue issue = only(s.safeParse('01/02/2024'));
      expect(issue.code, IssueCodes.dateFormat);
      expect(issue.message, 'The value must match the format Y-m-d');
    });

    test('time, short forms, time zones and escapes', () {
      expect(DateFormatted.matches('2024-01-31 23:59:59', 'Y-m-d H:i:s'), true);
      expect(
        DateFormatted.matches('2024-01-31 24:00:00', 'Y-m-d H:i:s'),
        false,
      );
      expect(DateFormatted.matches('2024-01-31 10:60', 'Y-m-d H:i'), false);
      expect(DateFormatted.matches('1/2/24', 'j/n/y'), true);
      expect(DateFormatted.matches('31/4/24', 'j/n/y'), false);
      expect(DateFormatted.matches('10:00:00.123', 'H:i:s.v'), true);
      expect(
        DateFormatted.matches('2024-01-31T10:00+07:00', r'Y-m-d\TH:iP'),
        true,
      );
      expect(
        DateFormatted.matches('2024-01-31T10:00+0700', r'Y-m-d\TH:iO'),
        true,
      );
      expect(
        DateFormatted.matches('2024-01-31X10:00+07:00', r'Y-m-d\TH:iP'),
        false,
      );
      expect(DateFormatted.matches('2024.01.31', 'Y.m.d'), true);
      expect(DateFormatted.matches('2024x01x31', 'Y.m.d'), false);
    });
  });

  group('password |', () {
    test('min only by default', () {
      expect(v.string().password().safeParse('abcdefgh').success, true);
      ValidationIssue issue = only(v.string().password().safeParse('abc'));
      expect(issue.code, IssueCodes.password);
      expect(issue.message, 'The value must have at least 8 characters');
    });

    test('every requirement', () {
      StringSchema s = v.string().password(
        min: 10,
        mixedCase: true,
        numbers: true,
        symbols: true,
      );
      expect(s.safeParse('Abcdefgh1!').success, true);
      expect(s.safeParse('Abcdefg1!').success, false); // too short
      expect(s.safeParse('abcdefgh1!').success, false); // no upper case
      expect(s.safeParse('ABCDEFGH1!').success, false); // no lower case
      expect(s.safeParse('Abcdefghi!').success, false); // no number
      expect(s.safeParse('Abcdefghi1').success, false); // no symbol
      expect(
        only(s.safeParse('x')).message,
        'The value must have at least 10 characters, one upper case and one '
        'lower case letter, one number, and one symbol',
      );
      expect(s.toJsonSchema()['minLength'], 10);
    });

    test('letters', () {
      StringSchema s = v.string().password(min: 4, letters: true);
      expect(s.safeParse('1234').success, false);
      expect(s.safeParse('123é').success, true);
      expect(
        only(s.safeParse('1234')).message,
        'The value must have at least 4 characters and one letter',
      );
    });
  });

  group('exists and unique |', () {
    FakeVerifier db = FakeVerifier(<String, List<Map<String, Object?>>>{
      'teams': <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'slug': 'core'},
      ],
      'users': <Map<String, Object?>>[
        <String, Object?>{'id': 5, 'email': 'taken@dox.dev'},
      ],
    });

    setUp(() {
      PresenceVerifier.instance = db;
      db.calls.clear();
    });

    tearDown(() {
      PresenceVerifier.instance = null;
    });

    test('exists', () async {
      expect((await v.int().exists('teams').safeParseAsync(1)).success, true);
      ValidationIssue issue = only(
        await v.int().exists('teams').safeParseAsync(2),
      );
      expect(issue.code, IssueCodes.exists);
      expect(issue.message, 'The selected value is invalid');
      expect(
        (await v
                .string()
                .exists('teams', column: 'slug')
                .safeParseAsync('core'))
            .success,
        true,
      );
      expect(db.calls.last, 'teams.slug except null=null');
    });

    test('unique', () async {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'email': v.string().unique('users', column: 'email'),
      });
      expect(
        (await s.safeParseAsync(<String, dynamic>{'email': 'new@dox.dev'}))
            .success,
        true,
      );
      ValidationIssue issue = only(
        await s.safeParseAsync(<String, dynamic>{'email': 'taken@dox.dev'}),
      );
      expect(issue.code, IssueCodes.unique);
      expect(issue.message, 'The email has already been taken');
      expect(db.calls.last, 'users.email except null=null');
    });

    test('unique ignores one row', () async {
      StringSchema s = v.string().unique('users', column: 'email', ignore: 5);
      expect((await s.safeParseAsync('taken@dox.dev')).success, true);
      expect(db.calls.last, 'users.email except id=5');
    });

    test('a list of values', () async {
      ListSchema<int> s = v.list(v.int().exists('teams'));
      ParseResult<List<int>> result = await s.safeParseAsync(<int>[1, 3]);
      expect(only(result).dottedPath, '1');
    });

    test('a verifier on the rule wins', () async {
      PresenceVerifier.instance = null;
      FakeVerifier own = FakeVerifier(<String, List<Map<String, Object?>>>{});
      StringSchema s = v.string().use(
        UniqueRule<String>('users', column: 'email', verifier: own),
      );
      expect((await s.safeParseAsync('taken@dox.dev')).success, true);
      expect(own.calls, hasLength(1));
    });

    test('no verifier is a clear error', () async {
      PresenceVerifier.instance = null;
      await expectLater(
        v.int().exists('teams').safeParseAsync(1),
        throwsA(isA<StateError>()),
      );
    });

    test('a rule made by hand checks names before the query', () async {
      for (Rule<String> rule in <Rule<String>>[
        ExistsRule<String>('teams; drop table x'),
        ExistsRule<String>('teams', column: 'id--'),
        UniqueRule<String>('users', column: 'a b'),
        UniqueRule<String>(
          'users',
          column: 'email',
          ignore: 1,
          ignoreColumn: 'x)',
        ),
      ]) {
        await expectLater(
          v.string().use(rule).safeParseAsync('a'),
          throwsArgumentError,
        );
      }
      expect(db.calls, isEmpty);
      expect(PresenceVerifier.checkName('public.users'), 'public.users');
    });

    test('async rules need parseAsync', () {
      expect(
        () => v.string().unique('users', column: 'email').safeParse('a'),
        throwsStateError,
      );
    });

    test('a list is one query, like Laravel (MySQL ignores case)', () async {
      FakeVerifier mysql = FakeVerifier(<String, List<Map<String, Object?>>>{
        'users': <Map<String, Object?>>[
          <String, Object?>{'id': 5, 'email': 'taken@dox.dev'},
        ],
      }, ignoreCase: true);
      RuleContext context = RuleContext(
        state: ParseState(root: null),
        path: const <Object>['emails'],
      );
      UniqueRule<String> unique = UniqueRule<String>(
        'users',
        column: 'email',
        verifier: mysql,
      );
      ExistsRule<String> exists = ExistsRule<String>(
        'users',
        column: 'email',
        verifier: mysql,
      );
      Future<List<int>> u(List<String> values) {
        return unique.failedItems(values, context);
      }

      Future<List<int>> e(List<String> values) {
        return exists.failedItems(values, context);
      }

      expect(await u(<String>['new@dox.dev', 'other@dox.dev']), <int>[]);
      // the row is an item by its exact text: only that item fails
      expect(await u(<String>['new@dox.dev', 'taken@dox.dev']), <int>[1]);
      // every found row is an item by text, so only that item fails. On
      // MySQL `TAKEN@` is taken too, but one query can not tell (same as
      // 3.0.1; a unique index stops the insert)
      expect(await u(<String>['taken@dox.dev', 'TAKEN@dox.dev']), <int>[0]);
      // only the database matched: it can not tell which, so all fail
      expect(await u(<String>['new@dox.dev', 'TAKEN@dox.dev']), <int>[0, 1]);
      // an item passes only when its exact text is found
      expect(await e(<String>['TAKEN@dox.dev', 'TAKEN@dox.dev']), <int>[0, 1]);
      expect(await e(<String>['taken@dox.dev', 'nope@dox.dev']), <int>[1]);
      expect(await e(<String>['taken@dox.dev', 'TAKEN@dox.dev']), <int>[1]);
      // `bob` finds `bob` and `Bob`: `nobody` must still fail
      FakeVerifier names = FakeVerifier(<String, List<Map<String, Object?>>>{
        'people': <Map<String, Object?>>[
          <String, Object?>{'id': 1, 'name': 'bob'},
          <String, Object?>{'id': 2, 'name': 'Bob'},
        ],
      }, ignoreCase: true);
      expect(
        await ExistsRule<String>(
          'people',
          column: 'name',
          verifier: names,
        ).failedItems(<String>['bob', 'nobody'], context),
        <int>[1],
      );

      // 500 items: always one query
      List<String> many = <String>[
        for (int i = 0; i < 499; i++) 'new$i@dox.dev',
      ]..insert(250, 'TAKEN@dox.dev');
      mysql.calls.clear();
      expect(await u(many), hasLength(500));
      // the list fails, and the items not found as text are marked
      expect(await e(many), hasLength(500));
      List<String> copies = List<String>.filled(500, 'TAKEN@dox.dev');
      expect(await e(copies), hasLength(500));
      expect(await u(copies), hasLength(500));
      expect(mysql.calls, hasLength(4));
    });

    test('a list with null, and when the verifier can not tell', () async {
      FakeVerifier fake = FakeVerifier(<String, List<Map<String, Object?>>>{
        'teams': <Map<String, Object?>>[
          <String, Object?>{'id': 1},
        ],
      });
      RuleContext context = RuleContext(
        state: ParseState(root: null),
        path: const <Object>['ids'],
      );
      expect(
        await ExistsRule<int?>(
          'teams',
          verifier: fake,
        ).failedItems(<int?>[1, null], context),
        <int>[1],
      );
      expect(
        await UniqueRule<int?>(
          'teams',
          column: 'id',
          verifier: fake,
        ).failedItems(<int?>[null, 2], context),
        <int>[],
      );
      UnknownVerifier unknown = UnknownVerifier();
      expect(
        await ExistsRule<Object>(
          'teams',
          verifier: unknown,
        ).failedItems(<Object>[1, 'abc'], context),
        <int>[0, 1],
      );
      expect(
        await UniqueRule<Object>(
          'teams',
          column: 'id',
          verifier: unknown,
        ).failedItems(<Object>[1, 'abc'], context),
        <int>[0, 1],
      );
    });

    test('names are checked when the schema is built', () {
      expect(() => v.string().exists('teams; drop'), throwsArgumentError);
      expect(
        () => v.int().unique('users', column: 'email', ignoreColumn: 'x)'),
        throwsArgumentError,
      );
      expect(
        () => v.string().unique('users', column: 'a b'),
        throwsArgumentError,
      );
      // names the ORM takes are fine
      expect(
        v.string().unique('2fa_codes', column: 'code'),
        isA<StringSchema>(),
      );
      expect(PresenceVerifier.checkName('db.public.users'), 'db.public.users');
      expect(PresenceVerifier.checkName('é_table'), 'é_table');
    });

    test('a key from the user is never the column', () async {
      // a map key comes from the request: it must not pick the column
      MapSchema<String> m = v.map(v.string().unique('users', column: 'email'));
      await m.safeParseAsync(<String, dynamic>{'password_hash': 'x'});
      expect(db.calls.last, 'users.email except null=null');
    });

    test(
      'one value: the database match decides (MySQL ignores case)',
      () async {
        PresenceVerifier.instance = FakeVerifier(
          <String, List<Map<String, Object?>>>{
            'users': <Map<String, Object?>>[
              <String, Object?>{'id': 5, 'email': 'taken@dox.dev'},
            ],
            'teams': <Map<String, Object?>>[
              <String, Object?>{'id': 1, 'slug': 'core'},
            ],
          },
          ignoreCase: true,
        );
        StringSchema unique = v.string().unique('users', column: 'email');
        expect((await unique.safeParseAsync('TAKEN@dox.dev')).success, false);
        expect((await unique.safeParseAsync('new@dox.dev')).success, true);
        StringSchema exists = v.string().exists('teams', column: 'slug');
        expect((await exists.safeParseAsync('CORE')).success, true);
        expect((await exists.safeParseAsync('nope')).success, false);
        // 1.0 finds the row 1, even if the text is not the same
        expect(
          (await v.num().exists('teams').safeParseAsync(1.0)).success,
          true,
        );
      },
    );
  });

  group('DTO helpers |', () {
    test('DtoState.requiredWhen adds the issue with DTO messages', () {
      DtoState s = DtoState(root: <String, dynamic>{});
      Map<String, dynamic> input = <String, dynamic>{'type': 'company'};
      s.requiredWhen(
        const RequiredIf('type', 'company'),
        undefined,
        input,
        const <Object>[],
        'company',
        const <String, String>{},
      );
      s.requiredWhen(
        const RequiredWith(<String>['type']),
        '  ',
        input,
        const <Object>[],
        'tax_id',
        const <String, String>{'tax_id.required_with': 'Tax ID please'},
      );
      s.requiredWhen(
        const RequiredIf('type', 'person'),
        null,
        input,
        const <Object>[],
        'name',
        const <String, String>{},
      );
      expect(s.issues, hasLength(2));
      expect(
        s.issues[0].message,
        'The company is required when type is company',
      );
      expect(s.issues[1].message, 'Tax ID please');
      // a value that is there: no issue, even when the rule applies
      s.requiredWhen(
        const RequiredIf('type', 'company'),
        'Dox',
        input,
        const <Object>[],
        'other',
        const <String, String>{},
      );
      // an empty list is missing
      s.requiredWhen(
        const RequiredIf('type', 'company'),
        <String>[],
        input,
        const <Object>[],
        'tags',
        const <String, String>{},
      );
      expect(s.issues, hasLength(3));
      expect(s.issues[2].dottedPath, 'tags');
    });

    test('DtoState.requiredWhen reads the converted other field', () {
      // like the generated code: type is trimmed and lower case
      DtoState s = DtoState(root: <String, dynamic>{});
      Map<String, dynamic> input = <String, dynamic>{'type': ' Company '};
      Object? type = s.string(
        s.read(input, 'type'),
        const <Object>[],
        'type',
        const <String, String>{},
        trim: true,
        textCase: 1,
      );
      expect(type, 'company');
      s.requiredWhen(
        const RequiredIf('type', 'company'),
        undefined,
        input,
        const <Object>[],
        'vat',
        const <String, String>{},
      );
      expect(s.issues.single.code, IssueCodes.requiredIf);

      // text input: 'yes' is true
      DtoState t = DtoState(root: <String, dynamic>{}, text: true);
      Map<String, dynamic> form = <String, dynamic>{'active': 'yes'};
      t.boolean(
        t.read(form, 'active'),
        const <Object>[],
        'active',
        const <String, String>{},
      );
      t.requiredWhen(
        const RequiredIf('active', true),
        undefined,
        form,
        const <Object>[],
        'reason',
        const <String, String>{},
      );
      expect(t.issues.single.code, IssueCodes.requiredIf);

      // the other field fails its own check: the raw value is used
      DtoState u = DtoState(root: <String, dynamic>{});
      Map<String, dynamic> bad = <String, dynamic>{'type': 5};
      u.string(
        u.read(bad, 'type'),
        const <Object>[],
        'type',
        const <String, String>{},
      );
      u.requiredWhen(
        const RequiredIf('type', 5),
        undefined,
        bad,
        const <Object>[],
        'vat',
        const <String, String>{},
      );
      expect(u.issues.map((ValidationIssue i) => i.code), <String>[
        IssueCodes.string,
        IssueCodes.requiredIf,
      ]);
    });

    test('rule classes are const, so they work as annotations', () {
      const List<Object> annotations = <Object>[
        Same<Object?>('a'),
        Confirmed<Object?>(),
        Json(),
        Digits(4),
        DigitsBetween(4, 6),
        DateFormatted('Y-m-d'),
        Password(mixedCase: true),
        RequiredIf('a', 'b'),
        RequiredWith(<String>['a']),
      ];
      expect(annotations, hasLength(9));
    });
  });
}
