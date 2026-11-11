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

void main() {
  tearDown(() {
    Validator.flags = const ValidationFlags();
  });

  test('all flags are off by default, all() turns every one on', () {
    ValidationFlags off = Validator.flags;
    expect(off.emptyStringsToNull, isFalse);
    expect(off.unicodeAlpha, isFalse);
    expect(off.shortInMessage, isFalse);
    ValidationFlags on = const ValidationFlags.all();
    expect(on.emptyStringsToNull, isTrue);
    expect(on.unicodeAlpha, isTrue);
    expect(on.shortInMessage, isTrue);
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
}
