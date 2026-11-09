import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

void main() {
  group('hexColor', () {
    test('takes # and 6 hex digits, both cases', () {
      expect(v.string().hexColor().safeParse('#1a2B3c').success, true);
      expect(v.string().hexColor().safeParse('#abc').success, false);
      expect(v.string().hexColor().safeParse('1a2b3c').success, false);
      expect(v.string().hexColor().safeParse('#1a2b3g').success, false);
      expect(v.string().hexColor().safeParse('#1a2b3c4d').success, false);
    });

    test('short: true also takes 3 digits', () {
      expect(v.string().hexColor(short: true).safeParse('#abc').success, true);
      expect(
        v.string().hexColor(short: true).safeParse('#abcd').success,
        false,
      );
    });

    test('code, message and JSON Schema', () {
      ParseResult<String> result = v.string().hexColor().safeParse('red');
      expect(result.issues.single.code, 'hex_color');
      expect(
        result.issues.single.message,
        'The value must be a hex color like #1a2b3c',
      );
      expect(
        v.string().hexColor().toJsonSchema()['pattern'],
        r'^#[0-9a-fA-F]{6}$',
      );
    });
  });

  group('dateFormat Y-m', () {
    test('a real month passes, month 13 fails', () {
      expect(v.string().dateFormat('Y-m').safeParse('2026-02').success, true);
      expect(v.string().dateFormat('Y-m').safeParse('2026-13').success, false);
      expect(v.string().dateFormat('Y-m').safeParse('2026-2').success, false);
    });
  });

  group('DtoState', () {
    DtoState state() {
      return DtoState(root: const <String, dynamic>{});
    }

    test('read with emptyToNull gives null for ""', () {
      Map<String, dynamic> input = <String, dynamic>{'a': '', 'b': ' '};
      expect(state().read(input, 'a'), '');
      expect(state().read(input, 'a', emptyToNull: true), isNull);
      // only the empty string, like ConvertEmptyStringsToNull
      expect(state().read(input, 'b', emptyToNull: true), ' ');
      expect(state().read(input, 'c', emptyToNull: true), undefined);
    });

    test('dropIssuesAfter removes the newer issues', () {
      DtoState s = state();
      s.fail(const <Object>[], 'a', 'required', 'x', null);
      int count = s.issues.length;
      expect(s.dropIssuesAfter(count), false);
      s.fail(const <Object>[], 'b', 'required', 'x', null);
      expect(s.dropIssuesAfter(count), true);
      expect(s.issues.single.dottedPath, 'a');
    });
  });
}
