import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

class Note {
  Note(this.text);

  final Object? text;
}

/// A DTO that keeps the raw `text` value, to see what it gets.
class _NoteDto extends DtoSchema<Note> {
  const _NoteDto();

  @override
  Type get type => Note;

  @override
  String get name => 'Note';

  @override
  Note? convert(Object? input, DtoState s, List<Object> p) {
    return Note((input as Map<String, dynamic>)['text']);
  }

  @override
  Note fromMap(Map<String, dynamic> input) {
    return Note(input['text']);
  }

  @override
  Map<String, dynamic> toMap(Note value) {
    return <String, dynamic>{'text': value.text};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'type': 'object'};
  }
}

class Signup {
  Signup(this.name, this.tags, this.nick, this.age);

  final String name;
  final List<String> tags;
  final Maybe<String> nick;
  final int age;
}

/// A DTO written like the code a dox_builder with the DTO flags makes for:
/// `@MinLength(2) String name`, `@MinItems(2) List<String> tags`,
/// `Maybe<String> nick` and `int age`.
class _SignupDto extends DtoSchema<Signup> {
  const _SignupDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => Signup;

  @override
  String get name => 'Signup';

  @override
  bool get usesRequiredWhen => false;

  @override
  Signup? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    Object? c0 = s.string(s.read(input, 'name'), p, 'name', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'name', _m);
    Object? c1 = s.list(s.read(input, 'tags'), p, 'tags', _m);
    if (c1 is List) {
      int b0 = s.issues.length;
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < c1.length; i0++) {
        Object? x0 = s.string(c1[i0], <Object>[...p, 'tags'], i0, _m);
        if (x0 is String) o0.add(x0);
      }
      // a list with a bad item is bad
      c1 = s.issues.length != b0 ? invalid : o0;
    }
    if (c1 == null || c1 is Undefined || s.emptyList(c1)) {
      s.required(p, 'tags', _m);
      c1 = invalid;
    }
    Object? c2 = s.string(s.read(input, 'nick'), p, 'nick', _m);
    if (c2 == null || s.sentEmpty(c2, input, 'nick')) {
      s.required(p, 'nick', _m);
    }
    Object? c3 = s.integer(s.read(input, 'age'), p, 'age', _m);
    if (c3 == null || c3 is Undefined) s.required(p, 'age', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (c0 is String) {
      if (!(c0.runes.length >= 2)) {
        s.fail(
          p,
          'name',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          c0,
          params: const <String, Object?>{'min': 2},
        );
      }
    }
    if (c1 is List<String>) {
      if (!(c1.length >= 2)) {
        s.fail(
          p,
          'tags',
          IssueCodes.minItems,
          DefaultMessages.minItems,
          c1,
          params: const <String, Object?>{'min': 2},
        );
      }
    }
    if (s.issues.length != e) return null;
    return Signup(
      c0 as String,
      c1 as List<String>,
      c2 is Undefined
          ? const Maybe<String>.missing()
          : Maybe<String>(c2 as String),
      c3 as int,
    );
  }

  @override
  Signup fromMap(Map<String, dynamic> input) {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toMap(Signup value) {
    return <String, dynamic>{};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'type': 'object'};
  }
}

/// The dotted path and code of each issue of [input].
Future<List<String>> _signupIssues(Map<String, dynamic> input) async {
  ParseResult<Signup> result = await const _SignupDto().safeValidateMap(input);
  return <String>[
    for (ValidationIssue issue in result.issues)
      '${issue.dottedPath} ${issue.code}',
  ];
}

void main() {
  tearDown(() {
    Validator.flags = const ValidationFlags();
  });

  test('all flags are off by default, all() turns every one on', () {
    ValidationFlags off = Validator.flags;
    expect(off.emptyStringsToNull, isFalse);
    expect(off.unicodeAlpha, isFalse);
    expect(off.shortInMessage, isFalse);
    expect(off.dtoAllErrors, isFalse);
    expect(off.dtoRejectEmptyList, isFalse);
    expect(off.dtoMaybeRejectsEmpty, isFalse);
    ValidationFlags on = const ValidationFlags.all();
    expect(on.emptyStringsToNull, isTrue);
    expect(on.unicodeAlpha, isTrue);
    expect(on.shortInMessage, isTrue);
    expect(on.dtoAllErrors, isTrue);
    expect(on.dtoRejectEmptyList, isTrue);
    expect(on.dtoMaybeRejectsEmpty, isTrue);
  });

  group('emptyStringsToNull', () {
    ObjectSchema schema() {
      return v.object(<String, Schema<Object?>>{
        'name': v.string(),
        'email': v.string().email().optional(),
        'note': v.string().nullable(),
        'tags': v.list(v.string().nullable()),
      });
    }

    Map<String, dynamic> input = <String, dynamic>{
      'name': '',
      'email': '',
      'note': '',
      'tags': <String>['a', ''],
    };

    test('off: "" is text', () {
      ParseResult<Map<String, dynamic>> result = schema().safeParse(input);
      expect(result.success, isFalse);
      // "" passes required, and .email() runs on it
      expect(result.issues.map((ValidationIssue i) => i.code), <String>[
        IssueCodes.email,
      ]);
      expect(v.string().parse(''), '');
    });

    test('on: "" is null, also nested', () {
      Validator.flags = const ValidationFlags(emptyStringsToNull: true);
      ParseResult<Map<String, dynamic>> result = schema().safeParse(input);
      expect(result.success, isFalse);
      Map<String, String> errors = <String, String>{
        for (ValidationIssue i in result.issues) i.path.join('.'): i.code,
      };
      expect(errors, <String, String>{
        'name': IssueCodes.required,
        'email': IssueCodes.required,
      });

      Map<String, dynamic> ok = schema().parse(<String, dynamic>{
        'name': 'Ann',
        'note': '',
        'tags': <String>['a', ''],
      });
      expect(ok['note'], isNull);
      expect(ok['tags'], <String?>['a', null]);
      expect(v.string().safeParse('').success, isFalse);
    });

    test('on: async parse converts too', () async {
      Validator.flags = const ValidationFlags(emptyStringsToNull: true);
      ParseResult<String?> result = await v.string().nullable().safeParseAsync(
        '',
      );
      expect(result.success, isTrue);
      expect(result.value, isNull);
    });

    test('on: the input of the caller is not changed', () {
      Validator.flags = const ValidationFlags(emptyStringsToNull: true);
      Map<String, dynamic> data = <String, dynamic>{
        'note': '',
        'tags': <String>[''],
      };
      v
          .object(<String, Schema<Object?>>{
            'note': v.string().nullable(),
            'tags': v.list(v.string().nullable()),
          })
          .parse(data);
      expect(data['note'], '');
      expect(data['tags'], <String>['']);
    });

    test('on: a DTO checked on its own keeps ""', () async {
      Validator.flags = const ValidationFlags(emptyStringsToNull: true);
      Map<String, dynamic> data = <String, dynamic>{'text': ''};
      expect(const _NoteDto().parse(data).text, '');
      expect((await const _NoteDto().validateMap(data)).text, '');
    });
  });

  group('unicodeAlpha', () {
    test('off: ASCII only', () {
      expect(v.string().alpha().safeParse('José').success, isFalse);
      expect(v.string().alphaNumeric().safeParse('José1').success, isFalse);
      expect(v.string().alphaDash().safeParse('José-1').success, isFalse);
      expect(Patterns.alpha.hasMatch('José'), isFalse);
      expect(v.string().alpha().safeParse('Jose').success, isTrue);
    });

    test('on: Unicode letters, marks and digits', () {
      // made before the flag is set: it still follows the flag
      StringSchema alpha = v.string().alpha();
      Validator.flags = const ValidationFlags(unicodeAlpha: true);
      expect(alpha.safeParse('José').success, isTrue);
      expect(alpha.safeParse('ภาษาไทย').success, isTrue);
      expect(alpha.safeParse('José1').success, isFalse);
      expect(v.string().alphaNumeric().safeParse('José١').success, isTrue);
      expect(v.string().alphaNumeric().safeParse('José-1').success, isFalse);
      expect(v.string().alphaDash().safeParse('José_1-2').success, isTrue);
      expect(v.string().alphaDash().safeParse('José 1').success, isFalse);
      // DTO code reads Patterns directly
      expect(Patterns.alpha.hasMatch('José'), isTrue);
    });

    test('on: a newline at the end, empty text and emoji fail', () {
      Validator.flags = const ValidationFlags(unicodeAlpha: true);
      for (StringSchema schema in <StringSchema>[
        v.string().alpha(),
        v.string().alphaNumeric(),
        v.string().alphaDash(),
      ]) {
        expect(schema.safeParse('a\n').success, isFalse);
        expect(schema.safeParse('').success, isFalse);
        expect(schema.safeParse('😀').success, isFalse);
        expect(schema.safeParse('a😀').success, isFalse);
      }
    });

    test('the JSON Schema pattern follows the flag, like the check', () {
      // made before the flag is set
      StringSchema alpha = v.string().alpha();
      StringSchema dash = v.string().alphaDash();
      StringSchema numeric = v.string().alphaNumeric();
      expect(alpha.toJsonSchema()['pattern'], r'^[a-zA-Z]+$');
      expect(dash.toJsonSchema()['pattern'], r'^[a-zA-Z0-9_-]+$');
      expect(numeric.toJsonSchema()['pattern'], r'^[a-zA-Z0-9]+$');
      Validator.flags = const ValidationFlags(unicodeAlpha: true);
      expect(alpha.toJsonSchema()['pattern'], r'^[\p{L}\p{M}]+$');
      expect(dash.toJsonSchema()['pattern'], r'^[\p{L}\p{M}\p{N}_-]+$');
      expect(numeric.toJsonSchema()['pattern'], r'^[\p{L}\p{M}\p{N}]+$');
      expect(alpha.rules.single.params['pattern'], r'^[\p{L}\p{M}]+$');
    });
  });

  group('shortInMessage', () {
    EnumSchema<String> roles() {
      return v.enumOf(<String>['admin', 'user']);
    }

    test('off: the message lists the values', () {
      ValidationIssue issue = roles().safeParse('x').issues.single;
      expect(
        issue.message,
        'The selected value is invalid. Valid options are admin, and user',
      );
    });

    test('on: the short message', () {
      Validator.flags = const ValidationFlags(shortInMessage: true);
      ValidationIssue issue = v
          .object(<String, Schema<Object?>>{'role': roles()})
          .safeParse(<String, dynamic>{'role': 'x'})
          .issues
          .single;
      expect(issue.code, IssueCodes.inList);
      expect(issue.message, 'The selected role is invalid');
    });

    test('on: DTO enum check and custom messages', () {
      Validator.flags = const ValidationFlags(shortInMessage: true);
      DtoState state = DtoState(root: const <String, dynamic>{});
      state.enumName(
        'x',
        const <Object>[],
        'role',
        const <String, String>{},
        <String>['admin'],
      );
      expect(state.issues.single.message, 'The selected role is invalid');
      // a custom message still wins
      ValidationIssue custom = roles()
          .safeParse(
            'x',
            messages: MessageResolver(
              messages: <String, String>{'in': 'Pick one of {values}'},
            ),
          )
          .issues
          .single;
      expect(custom.message, 'Pick one of admin, and user');
    });

    test('on: a message on the rule itself still wins', () {
      Validator.flags = const ValidationFlags(shortInMessage: true);
      // what the code for `@In([...], message: '...')` calls
      DtoState state = DtoState(root: const <String, dynamic>{});
      state.fail(
        const <Object>[],
        'role',
        IssueCodes.inList,
        DefaultMessages.inList,
        'x',
        params: const <String, Object?>{'values': 'admin'},
        message: 'Pick {values}',
      );
      expect(state.issues.single.message, 'Pick admin');
    });
  });

  group('dtoAllErrors', () {
    Map<String, dynamic> input = <String, dynamic>{
      'name': 'a',
      'tags': <String>['x', 'y'],
      'age': 'old',
    };

    test('off: a type error stops the rules of other fields', () async {
      expect(await _signupIssues(input), <String>['age integer']);
    });

    test('on: the rules of the good fields run too', () async {
      Validator.flags = const ValidationFlags(dtoAllErrors: true);
      expect(await _signupIssues(input), <String>[
        'age integer',
        'name min_length',
      ]);
    });

    test('on: good input still passes', () async {
      Validator.flags = const ValidationFlags(dtoAllErrors: true);
      ParseResult<Signup> result = await const _SignupDto().safeValidateMap(
        <String, dynamic>{
          'name': 'ab',
          'tags': <String>['x', 'y'],
          'age': 3,
        },
      );
      expect(result.success, isTrue);
    });
  });

  group('dtoRejectEmptyList', () {
    Map<String, dynamic> input = <String, dynamic>{
      'name': 'ab',
      'tags': <String>[],
      'age': 3,
    };

    test('off: [] is not required, only its rules run', () async {
      expect(await _signupIssues(input), <String>['tags min_items']);
    });

    test('on: [] fails required', () async {
      Validator.flags = const ValidationFlags(dtoRejectEmptyList: true);
      expect(await _signupIssues(input), <String>['tags required']);
    });

    test('on with dtoAllErrors: [] gives only required', () async {
      Validator.flags = const ValidationFlags(
        dtoRejectEmptyList: true,
        dtoAllErrors: true,
      );
      expect(await _signupIssues(input), <String>['tags required']);
      // only an empty list
      DtoState state = DtoState(root: const <String, dynamic>{});
      expect(state.emptyList(<String>['x']), isFalse);
      expect(state.emptyList(''), isFalse);
    });
  });

  group('dtoMaybeRejectsEmpty', () {
    Map<String, dynamic> base = <String, dynamic>{
      'name': 'ab',
      'tags': <String>['x', 'y'],
      'age': 3,
    };

    test('off: "" counts as not sent', () async {
      ParseResult<Signup> result = await const _SignupDto().safeValidateMap(
        <String, dynamic>{...base, 'nick': ''},
      );
      expect(result.success, isTrue);
      expect(result.value!.nick.isPresent, isFalse);
    });

    test('on: "" fails required, a missing key still passes', () async {
      Validator.flags = const ValidationFlags(dtoMaybeRejectsEmpty: true);
      expect(
        await _signupIssues(<String, dynamic>{...base, 'nick': ''}),
        <String>['nick required'],
      );
      ParseResult<Signup> missing = await const _SignupDto().safeValidateMap(
        base,
      );
      expect(missing.success, isTrue);
      expect(missing.value!.nick.isPresent, isFalse);
      ParseResult<Signup> sent = await const _SignupDto().safeValidateMap(
        <String, dynamic>{...base, 'nick': 'bo'},
      );
      expect(sent.value!.nick.value, 'bo');
    });
  });

  group('a list with a bad item', () {
    Future<List<String>> issues(List<Object> tags) {
      return _signupIssues(<String, dynamic>{
        'name': 'ab',
        'tags': tags,
        'age': 3,
      });
    }

    for (ValidationFlags flags in <ValidationFlags>[
      const ValidationFlags(),
      const ValidationFlags(dtoRejectEmptyList: true),
      const ValidationFlags.all(),
    ]) {
      String mode = flags.dtoAllErrors
          ? 'all flags'
          : flags.dtoRejectEmptyList
          ? 'dtoRejectEmptyList'
          : 'flags off';
      test('$mode: gives only the item error', () async {
        Validator.flags = flags;
        expect(await issues(<Object>[5]), <String>['tags.0 string']);
        expect(await issues(<Object>['a', 5]), <String>['tags.1 string']);
      });
    }
  });
}
