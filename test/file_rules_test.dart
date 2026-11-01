import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

class TestFile implements FileInput {
  TestFile(this.extension, this.head, {int? length})
    : length = length ?? head.length;

  @override
  final String extension;

  @override
  final List<int> head;

  @override
  final int length;
}

List<int> be16(int n) => <int>[n >> 8 & 0xFF, n & 0xFF];
List<int> be32(int n) => <int>[...be16(n >> 16), ...be16(n)];
List<int> le16(int n) => <int>[n & 0xFF, n >> 8 & 0xFF];
List<int> le24(int n) => <int>[...le16(n), n >> 16 & 0xFF];

List<int> png(int w, int h) => <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ...be32(13), ...'IHDR'.codeUnits, ...be32(w), ...be32(h),
  8, 6, 0, 0, 0,
];

List<int> gif(int w, int h) => <int>[
  ...'GIF89a'.codeUnits,
  ...le16(w),
  ...le16(h),
  0,
  0,
  0,
];

List<int> riff(String kind, List<int> body) => <int>[
  ...'RIFF'.codeUnits,
  ...le16(100), 0, 0, //
  ...'WEBP'.codeUnits,
  ...kind.codeUnits,
  ...le16(body.length), 0, 0,
  ...body,
];

List<int> webpLossy(int w, int h) =>
    riff('VP8 ', <int>[0, 0, 0, 0x9D, 0x01, 0x2A, ...le16(w), ...le16(h), 0]);

List<int> webpLossless(int w, int h) {
  int bits = (w - 1) | (h - 1) << 14;
  return riff('VP8L', <int>[
    0x2F,
    bits & 0xFF,
    bits >> 8 & 0xFF,
    bits >> 16 & 0xFF,
    bits >> 24 & 0xFF,
    0,
  ]);
}

List<int> webpExtended(int w, int h) =>
    riff('VP8X', <int>[0, 0, 0, 0, ...le24(w - 1), ...le24(h - 1)]);

/// A JPEG with an APP1 (EXIF like) segment of [metadata] bytes before the
/// frame header.
List<int> jpeg(int w, int h, {int metadata = 16}) => <int>[
  0xFF, 0xD8, //
  0xFF, 0xE1, ...be16(metadata + 2), ...List<int>.filled(metadata, 0),
  0xFF, 0xC0, ...be16(17), 8, ...be16(h), ...be16(w), 3,
  ...List<int>.filled(9, 0),
];

String message(ParseResult<Object?> result) => result.issues.first.message;
String code(ParseResult<Object?> result) => result.issues.first.code;

void main() {
  group('maxSize and minSize |', () {
    test('max size in bytes', () {
      FileSchema s = v.file().maxSize(2 * 1024 * 1024);
      expect(
        s.safeParse(TestFile('pdf', const <int>[], length: 2 << 20)).success,
        true,
      );
      ParseResult<FileInput> bad = s.safeParse(
        TestFile('pdf', const <int>[], length: (2 << 20) + 1),
      );
      expect(bad.success, false);
      expect(code(bad), IssueCodes.maxSize);
      expect(message(bad), 'The value may not be larger than 2MB');
    });

    test('min size in bytes', () {
      FileSchema s = v.file().minSize(1500);
      expect(
        s.safeParse(TestFile('pdf', const <int>[], length: 1500)).success,
        true,
      );
      ParseResult<FileInput> bad = s.safeParse(
        TestFile('pdf', const <int>[], length: 10),
      );
      expect(code(bad), IssueCodes.minSize);
      expect(message(bad), 'The value must be at least 1500B');
      expect(
        message(v.file().minSize(10 * 1024).safeParse(TestFile('x', <int>[]))),
        'The value must be at least 10KB',
      );
    });

    test('custom message and JSON Schema', () {
      ParseResult<FileInput> bad = v
          .file()
          .maxSize(1, message: 'Too big')
          .safeParse(TestFile('pdf', <int>[1, 2]));
      expect(message(bad), 'Too big');
      expect(
        v.file().maxSize(10).minSize(1).toJsonSchema(),
        containsPair('maxLength', 10),
      );
    });
  });

  group('mimes and mimeTypes |', () {
    test('mimes checks the real bytes', () {
      FileSchema s = v.file().mimes(<String>['png', 'pdf']);
      expect(s.safeParse(TestFile('png', png(1, 1))).success, true);
      ParseResult<FileInput> bad = s.safeParse(TestFile('png', gif(1, 1)));
      expect(code(bad), IssueCodes.mimes);
      expect(message(bad), 'The value must be a file of type: png, pdf');
    });

    test('mimeTypes maps MIME types to the real bytes', () {
      FileSchema s = v.file().mimeTypes(<String>['image/png']);
      expect(s.safeParse(TestFile('png', png(1, 1))).success, true);
      // the bytes say gif, so the name and the client type do not matter
      ParseResult<FileInput> bad = s.safeParse(TestFile('png', gif(1, 1)));
      expect(bad.success, false);
      expect(code(bad), IssueCodes.mimeTypes);
      expect(message(bad), 'The value must be a file of type: image/png');
    });

    test('image/* takes every image, but not svg or html', () {
      FileSchema s = v.file().mimeTypes(<String>['image/*']);
      expect(s.safeParse(TestFile('gif', gif(1, 1))).success, true);
      expect(s.safeParse(TestFile('jpg', jpeg(1, 1))).success, true);
      expect(s.safeParse(TestFile('svg', '<svg>'.codeUnits)).success, false);
      expect(s.safeParse(TestFile('html', gif(1, 1))).success, false);
      expect(
        FileTypes.extensionsOf(<String>['image/*']),
        isNot(contains('svg')),
      );
    });

    test('types without a byte signature use the name', () {
      FileSchema s = v.file().mimeTypes(<String>['text/csv']);
      expect(s.safeParse(TestFile('csv', 'a,b'.codeUnits)).success, true);
      expect(s.safeParse(TestFile('csv', png(1, 1))).success, false);
    });

    test('unknown MIME types never match', () {
      FileSchema s = v.file().mimeTypes(<String>['application/x-made-up']);
      expect(s.safeParse(TestFile('bin', <int>[1, 2, 3])).success, false);
    });
  });

  group('dimensions |', () {
    test('reads PNG, GIF, WebP and JPEG sizes', () {
      Map<String, List<int>> images = <String, List<int>>{
        'png': png(640, 480),
        'gif': gif(640, 480),
        'webp lossy': webpLossy(640, 480),
        'webp lossless': webpLossless(640, 480),
        'webp extended': webpExtended(640, 480),
        'jpeg': jpeg(640, 480),
      };
      images.forEach((String name, List<int> bytes) {
        ImageSize? size = ImageSize.read(bytes);
        expect(size?.width, 640, reason: name);
        expect(size?.height, 480, reason: name);
      });
    });

    test('jpeg skips metadata and fill bytes', () {
      List<int> bytes = jpeg(300, 200, metadata: 60000);
      expect(ImageSize.read(bytes)?.width, 300);
      List<int> filled = <int>[0xFF, 0xD8, 0xFF, 0xFF, ...jpeg(30, 20).skip(2)];
      expect(ImageSize.read(filled)?.height, 20);
    });

    test('min, max, exact and ratio', () {
      TestFile file = TestFile('png', png(300, 200));
      expect(
        v
            .file()
            .dimensions(minWidth: 300, maxHeight: 200)
            .safeParse(file)
            .success,
        true,
      );
      expect(v.file().dimensions(minWidth: 301).safeParse(file).success, false);
      expect(v.file().dimensions(maxWidth: 299).safeParse(file).success, false);
      expect(
        v.file().dimensions(minHeight: 201).safeParse(file).success,
        false,
      );
      expect(
        v.file().dimensions(width: 300, height: 200).safeParse(file).success,
        true,
      );
      expect(v.file().dimensions(width: 200).safeParse(file).success, false);
      expect(v.file().dimensions(ratio: 3 / 2).safeParse(file).success, true);
      expect(v.file().dimensions(ratio: 1).safeParse(file).success, false);
    });

    test('message and code', () {
      ParseResult<FileInput> bad = v
          .file()
          .dimensions(maxWidth: 10)
          .safeParse(TestFile('gif', gif(20, 20)));
      expect(code(bad), IssueCodes.dimensions);
      expect(message(bad), 'The value has invalid image dimensions');
      expect(
        message(
          v
              .file()
              .dimensions(maxWidth: 10, message: 'Too wide')
              .safeParse(TestFile('gif', gif(20, 20))),
        ),
        'Too wide',
      );
    });

    test('bad and cut short headers fail', () {
      FileSchema s = v.file().dimensions(minWidth: 1);
      List<List<int>> bad = <List<int>>[
        const <int>[],
        png(10, 10).sublist(0, 20), // cut before the height
        gif(10, 10).sublist(0, 8),
        webpLossy(10, 10).sublist(0, 27),
        webpLossless(10, 10).sublist(0, 23),
        webpExtended(10, 10).sublist(0, 28),
        jpeg(10, 10).sublist(0, 25), // cut inside the frame header
        jpeg(10, 10, metadata: 1000).sublist(0, 500), // cut in metadata
        png(0, 10), // zero width
        gif(10, 0),
        <int>[0xFF, 0xD8, 0xFF, 0xDA, 0, 2], // scan before any frame
        <int>[0xFF, 0xD8, 0xFF, 0xE1, 0, 0], // segment length below 2
        <int>[0xFF, 0xD8, 0x00, 0x00, 0, 0], // not a marker
        riff('VP8 ', List<int>.filled(12, 0)), // no start code
        '%PDF-1.7 not an image at all'.codeUnits,
      ];
      for (int i = 0; i < bad.length; i++) {
        expect(ImageSize.read(bad[i]), null, reason: 'case $i');
        expect(
          s.safeParse(TestFile('png', bad[i])).success,
          false,
          reason: 'case $i',
        );
      }
    });
  });
}
