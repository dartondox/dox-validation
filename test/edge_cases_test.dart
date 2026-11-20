import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

const List<Object> _top = <Object>[];
const Map<String, String> _none = <String, String>{};

void main() {
  group('coerce.date with a big number', () {
    test('gives a date issue, not an error', () {
      expect(v.coerce.date().safeParse(99999999999999999).success, false);
      expect(v.coerce.date().safeParse(-99999999999999999).success, false);
    });

    test('the edge years do not throw', () {
      expect(v.coerce.date().safeParse('+275760-09-13').success, true);
      expect(v.coerce.date().safeParse('+275760-09-14').success, false);
      expect(v.coerce.date().safeParse('-271821-01-01').success, isA<bool>());
    });

    test('the edge of the range still works', () {
      expect(v.coerce.date().safeParse(8640000000000000).success, true);
      expect(v.coerce.date().safeParse(-8640000000000000).success, true);
    });
  });

  group('v.num() and Infinity', () {
    test('rejects Infinity and -Infinity', () {
      expect(v.num().min(0).safeParse(double.infinity).success, false);
      expect(v.num().safeParse(double.negativeInfinity).success, false);
      expect(v.coerce.num().safeParse('1e999').success, false);
    });

    test('int schema and normal numbers still pass', () {
      expect(v.int().safeParse(double.infinity).success, false);
      expect(v.coerce.int().safeParse(double.infinity).success, false);
      expect(v.num().safeParse(1.5).success, true);
      expect(v.num().safeParse(-3).success, true);
    });
  });

  group('impossible dates and times', () {
    test('datetime() rejects them', () {
      for (String text in <String>[
        '2024-02-31T10:00:00Z',
        '2023-02-29T10:00:00Z',
        '2024-13-01T10:00:00Z',
        '2024-01-31T25:00:00Z',
        '2024-01-31T10:61:00Z',
        '2024-01-31T10:00:61Z',
      ]) {
        expect(
          v.string().datetime().safeParse(text).success,
          false,
          reason: text,
        );
      }
    });

    test('coerce.date() rejects them', () {
      for (String text in <String>[
        '2024-02-31',
        '2024-04-31',
        '2024-01-31 25:61:61',
        '2024-01-31T24:00:00',
      ]) {
        expect(v.coerce.date().safeParse(text).success, false, reason: text);
      }
    });

    test('a DTO date rejects them', () {
      DtoState s = DtoState(root: null);
      expect(s.date('2024-02-31T10:00:00Z', _top, 'a', _none), invalid);
      expect(s.date('2024-01-31T25:61:61', _top, 'a', _none), invalid);
    });

    test('real dates and times still pass', () {
      for (String text in <String>[
        '2024-02-29',
        '2024-02-29T23:59:59Z',
        '2024-01-31 10:00',
        '2024-01-31T10:00:00.123Z',
        '2024-01-31T10:00:00+05:30',
        '2024-01-31T10:00:00-0800',
        '2024-12-31',
      ]) {
        expect(v.coerce.date().safeParse(text).success, true, reason: text);
      }
      expect(
        v.string().datetime().safeParse('2024-02-29T10:00:00+06:30').success,
        true,
      );
      expect(v.string().datetime().safeParse('2024-01-31 10:00').success, true);
      DtoState s = DtoState(root: null);
      expect(
        s.date('2024-02-29T10:00:00+06:30', _top, 'a', _none),
        DateTime.utc(2024, 2, 29, 3, 30),
      );
    });
  });

  group('DTO int with a huge double', () {
    test('1e30 is an int issue, not max int', () {
      DtoState s = DtoState(root: null);
      expect(s.integer(1e30, _top, 'a', _none), invalid);
      expect(s.integer(-1e30, _top, 'a', _none), invalid);
      expect(v.coerce.int().safeParse(1e30).success, false);
    });

    test('whole doubles in the safe range still pass', () {
      DtoState s = DtoState(root: null);
      expect(s.integer(42.0, _top, 'a', _none), 42);
      expect(s.integer(9007199254740992.0, _top, 'a', _none), 9007199254740992);
    });
  });

  group('coerce int and num with hex text', () {
    test('hex text fails', () {
      expect(v.coerce.int().safeParse('0x1F').success, false);
      expect(v.coerce.num().safeParse('0x1F').success, false);
    });

    test('decimal text still passes', () {
      expect(v.coerce.int().parse(' 42 '), 42);
      expect(v.coerce.num().parse('42'), 42);
      expect(v.coerce.num().parse('4.5'), 4.5);
      expect(v.coerce.num().parse('1e3'), 1000);
    });
  });

  group('multipleOf', () {
    test('works with fractions', () {
      expect(v.num().multipleOf(0.1).safeParse(0.3).success, true);
      expect(v.num().multipleOf(0.1).safeParse(0.7).success, true);
      expect(v.num().multipleOf(0.01).safeParse(1.15).success, true);
      expect(v.num().multipleOf(0.1).safeParse(0.35).success, false);
    });

    test('huge and tiny values do not throw or pass by chance', () {
      expect(v.num().multipleOf(0.1).safeParse(1e308).success, false);
      expect(v.num().multipleOf(10).safeParse(1e20).success, true);
      expect(v.num().multipleOf(0.01).safeParse(5000000.004).success, false);
      expect(v.num().multipleOf(1).safeParse(1000000000.4).success, false);
      expect(v.num().multipleOf(0.01).safeParse(19.99).success, true);
      expect(v.num().multipleOf(0.05).safeParse(1.15).success, true);
      expect(v.num().multipleOf(0.1).safeParse(-0.3).success, true);
      expect(v.num().multipleOf(1e-8).safeParse(1e-7).success, true);
    });

    test('big quotients keep working', () {
      expect(v.num().multipleOf(0.01).safeParse(307407039.16).success, true);
      expect(v.num().multipleOf(0.01).safeParse(42255011316.42).success, true);
      expect(v.num().multipleOf(0.1).safeParse(6705752917.7).success, true);
      expect(v.num().multipleOf(1).safeParse(1000000.0000001).success, false);
    });

    test('factor 0 gives an issue, not an error', () {
      expect(v.int().multipleOf(0).safeParse(3).success, false);
      expect(v.num().multipleOf(0).safeParse(3).success, false);
    });

    test('works as before for other numbers', () {
      expect(v.num().multipleOf(0.5).safeParse(1.5).success, true);
      expect(v.num().multipleOf(0.5).safeParse(1.4).success, false);
      expect(v.num().multipleOf(5).safeParse(10).success, true);
      expect(v.num().multipleOf(5).safeParse(11).success, false);
      expect(v.int().multipleOf(3).safeParse(9).success, true);
      expect(v.int().multipleOf(3).safeParse(10).success, false);
      expect(v.num().multipleOf(0).safeParse(3.5).success, false);
    });
  });
}
