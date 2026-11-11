import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

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
  });
}
