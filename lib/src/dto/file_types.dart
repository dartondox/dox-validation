/// An uploaded file the validator can check.
///
/// dox-core `RequestFile` implements it, so `v.file()` and the DTO file
/// rules (`@MaxSize`, `@Mimes`, `@Image`, `@Dimensions` and more) can
/// read it.
abstract class FileInput {
  /// File extension from the file name, without the dot, like `png`.
  String get extension;

  /// Size in bytes.
  int get length;

  /// The first bytes of the file: at least [FileTypes.headSize] bytes
  /// when the file is that long. The real file type comes from them.
  ///
  /// It may hold more. The image size of a PNG, GIF or WebP is in the
  /// first [FileTypes.headSize] bytes. A JPEG keeps its size after the
  /// photo metadata, so `dimensions` needs more bytes for it, like the
  /// first [ImageSize.jpegHeadSize] bytes.
  List<int> get head;
}

/// Finds the real type of a file from its first bytes ("magic bytes").
///
/// The file name and the content type from the client are not trusted.
/// The file name extension must not be another known type or a type a
/// browser runs, so `x.html` with GIF bytes is not a `gif`. An empty or
/// unknown extension (like a `blob` upload) is fine when the bytes match. A type without a byte signature (like `txt` or
/// `csv`) is matched by the file name extension only.
class FileTypes {
  const FileTypes._();

  /// How many first bytes a [FileInput] must keep in [FileInput.head].
  static const int headSize = 32;

  /// Extension => the byte format it uses.
  static const Map<String, String> _formats = <String, String>{
    'jpg': 'jpg',
    'jpeg': 'jpg',
    'png': 'png',
    'gif': 'gif',
    'webp': 'webp',
    'bmp': 'bmp',
    'tif': 'tiff',
    'tiff': 'tiff',
    'ico': 'ico',
    'psd': 'psd',
    'pdf': 'pdf',
    'mp3': 'mp3',
    'wav': 'wav',
    'avi': 'avi',
    'ogg': 'ogg',
    'flac': 'flac',
    'woff': 'woff',
    'woff2': 'woff2',
    'wasm': 'wasm',
    '7z': '7z',
    'rar': 'rar',
    // containers: the bytes are shared, so the file name must match too
    'zip': 'zip',
    'docx': 'zip',
    'xlsx': 'zip',
    'pptx': 'zip',
    'odt': 'zip',
    'ods': 'zip',
    'odp': 'zip',
    'epub': 'zip',
    'jar': 'zip',
    'apk': 'zip',
    'doc': 'ole',
    'xls': 'ole',
    'ppt': 'ole',
    'msg': 'ole',
    'mp4': 'ftyp',
    'm4a': 'ftyp',
    'm4v': 'ftyp',
    'mov': 'ftyp',
    'heic': 'ftyp',
    'heif': 'ftyp',
    'avif': 'ftyp',
    '3gp': 'ftyp',
    'webm': 'mkv',
    'mkv': 'mkv',
    'gz': 'gz',
    'tgz': 'gz',
  };

  /// Byte formats used by more than one file type.
  static const Set<String> _containers = <String>{
    'zip',
    'ole',
    'ftyp',
    'mkv',
    'gz',
  };

  /// `true` when [file] is one of [types] (file extensions, like `pdf`).
  static bool matches(FileInput file, List<String> types) {
    String? found = sniff(file.head);
    String name = file.extension.toLowerCase();
    for (String type in types) {
      String ext = type.toLowerCase();
      String? format = _formats[ext];
      if (format == null) {
        // no byte signature: trust the name, but only for non-binary bytes
        if (found == null && name == ext) return true;
      } else if (format == found && _nameFits(name, format)) {
        if (!_containers.contains(format) || name == ext) return true;
      }
    }
    return false;
  }

  /// MIME type => the extensions it may have.
  /// No `image/svg+xml`: an SVG file can hold scripts.
  static const Map<String, List<String>> _mimeTypes = <String, List<String>>{
    'image/jpeg': <String>['jpg', 'jpeg'],
    'image/png': <String>['png'],
    'image/gif': <String>['gif'],
    'image/webp': <String>['webp'],
    'image/bmp': <String>['bmp'],
    'image/tiff': <String>['tif', 'tiff'],
    'image/vnd.microsoft.icon': <String>['ico'],
    'image/x-icon': <String>['ico'],
    'image/heic': <String>['heic'],
    'image/heif': <String>['heif'],
    'image/avif': <String>['avif'],
    'image/vnd.adobe.photoshop': <String>['psd'],
    'application/pdf': <String>['pdf'],
    'application/zip': <String>['zip'],
    'application/gzip': <String>['gz', 'tgz'],
    'application/x-7z-compressed': <String>['7z'],
    'application/vnd.rar': <String>['rar'],
    'application/x-rar-compressed': <String>['rar'],
    'application/msword': <String>['doc'],
    'application/vnd.ms-excel': <String>['xls'],
    'application/vnd.ms-powerpoint': <String>['ppt'],
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        <String>['docx'],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        <String>['xlsx'],
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        <String>['pptx'],
    'application/vnd.oasis.opendocument.text': <String>['odt'],
    'application/vnd.oasis.opendocument.spreadsheet': <String>['ods'],
    'application/vnd.oasis.opendocument.presentation': <String>['odp'],
    'application/epub+zip': <String>['epub'],
    'application/java-archive': <String>['jar'],
    'application/vnd.android.package-archive': <String>['apk'],
    'application/wasm': <String>['wasm'],
    'application/json': <String>['json'],
    'audio/mpeg': <String>['mp3'],
    'audio/wav': <String>['wav'],
    'audio/x-wav': <String>['wav'],
    'audio/ogg': <String>['ogg'],
    'audio/flac': <String>['flac'],
    'audio/mp4': <String>['m4a'],
    'video/mp4': <String>['mp4', 'm4v'],
    'video/quicktime': <String>['mov'],
    'video/x-msvideo': <String>['avi'],
    'video/webm': <String>['webm'],
    'video/x-matroska': <String>['mkv'],
    'video/3gpp': <String>['3gp'],
    'font/woff': <String>['woff'],
    'font/woff2': <String>['woff2'],
    'text/plain': <String>['txt'],
    'text/csv': <String>['csv'],
  };

  /// `true` when [file] is one of [mimeTypes], like `image/png`.
  /// `image/*` means every image type in the list (not svg).
  ///
  /// The client content type is not trusted. Each MIME type is turned
  /// into its file extensions, and [matches] checks the real bytes.
  /// An unknown MIME type never matches.
  static bool matchesMimeTypes(FileInput file, List<String> mimeTypes) {
    return matches(file, extensionsOf(mimeTypes));
  }

  /// The file extensions for [mimeTypes]. `image/*` gives every image
  /// extension in the list. Unknown MIME types give nothing.
  static List<String> extensionsOf(List<String> mimeTypes) {
    List<String> found = <String>[];
    for (String type in mimeTypes) {
      String mime = type.toLowerCase().trim();
      if (mime.endsWith('/*')) {
        String group = mime.substring(0, mime.length - 1);
        for (MapEntry<String, List<String>> entry in _mimeTypes.entries) {
          if (entry.key.startsWith(group)) found.addAll(entry.value);
        }
      } else {
        found.addAll(_mimeTypes[mime] ?? const <String>[]);
      }
    }
    return found;
  }

  /// Extensions a browser may run as a page or script.
  static const Set<String> _active = <String>{
    'html',
    'htm',
    'xhtml',
    'svg',
    'xml',
    'js',
    'mjs',
  };

  /// `false` when the client extension [name] is another known format, or
  /// a type a browser runs, so `x.html` with GIF bytes does not pass as
  /// `gif`. An empty or unknown extension is fine: browsers name canvas
  /// and fetch uploads `blob`.
  static bool _nameFits(String name, String format) {
    String? named = _formats[name];
    if (named != null) return named == format;
    return !_active.contains(name);
  }

  /// The byte format of [head], like `png` or `zip`. `null` when unknown.
  static String? sniff(List<int> head) {
    if (_starts(head, const <int>[0xFF, 0xD8, 0xFF])) return 'jpg';
    if (_starts(head, const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])) {
      return 'png';
    }
    if (_ascii(head, 0, 'GIF87a') || _ascii(head, 0, 'GIF89a')) return 'gif';
    if (_ascii(head, 0, 'RIFF')) {
      if (_ascii(head, 8, 'WEBP')) return 'webp';
      if (_ascii(head, 8, 'WAVE')) return 'wav';
      if (_ascii(head, 8, 'AVI ')) return 'avi';
      return null;
    }
    if (_ascii(head, 0, 'BM') && _bmpHeader(head)) return 'bmp';
    if (_ascii(head, 0, '%PDF-')) return 'pdf';
    if (_starts(head, const <int>[0x50, 0x4B, 0x03, 0x04]) ||
        _starts(head, const <int>[0x50, 0x4B, 0x05, 0x06])) {
      return 'zip';
    }
    if (_starts(head, const <int>[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1])) {
      return 'ole';
    }
    if (_starts(head, const <int>[0x49, 0x49, 0x2A, 0x00]) ||
        _starts(head, const <int>[0x4D, 0x4D, 0x00, 0x2A])) {
      return 'tiff';
    }
    if (_starts(head, const <int>[0x00, 0x00, 0x01, 0x00])) return 'ico';
    if (_ascii(head, 0, '8BPS')) return 'psd';
    if (_ascii(head, 4, 'ftyp')) return 'ftyp';
    if (_ascii(head, 0, 'ID3') ||
        _starts(head, const <int>[0xFF, 0xFB]) ||
        _starts(head, const <int>[0xFF, 0xF3]) ||
        _starts(head, const <int>[0xFF, 0xF2])) {
      return 'mp3';
    }
    if (_ascii(head, 0, 'OggS')) return 'ogg';
    if (_ascii(head, 0, 'fLaC')) return 'flac';
    if (_starts(head, const <int>[0x1A, 0x45, 0xDF, 0xA3])) return 'mkv';
    if (_starts(head, const <int>[0x1F, 0x8B])) return 'gz';
    if (_starts(head, const <int>[0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) {
      return '7z';
    }
    if (_ascii(head, 0, 'Rar!')) return 'rar';
    if (_ascii(head, 0, 'wOFF')) return 'woff';
    if (_ascii(head, 0, 'wOF2')) return 'woff2';
    if (_starts(head, const <int>[0x00, 0x61, 0x73, 0x6D])) return 'wasm';
    return null;
  }

  /// sizes of the known BMP DIB headers (BITMAPCOREHEADER to V5)
  static const Set<int> _bmpDibSizes = <int>{12, 40, 52, 56, 64, 108, 124};

  /// `BM` alone is also text like "BMW". A real BMP has a known DIB
  /// header size (little endian) at byte 14.
  static bool _bmpHeader(List<int> head) {
    if (head.length < 18) return false;
    int size = head[14] | head[15] << 8 | head[16] << 16 | head[17] << 24;
    return _bmpDibSizes.contains(size);
  }

  static bool _starts(List<int> head, List<int> bytes) {
    if (head.length < bytes.length) return false;
    for (int i = 0; i < bytes.length; i++) {
      if (head[i] != bytes[i]) return false;
    }
    return true;
  }

  static bool _ascii(List<int> head, int at, String text) {
    if (head.length < at + text.length) return false;
    for (int i = 0; i < text.length; i++) {
      if (head[at + i] != text.codeUnitAt(i)) return false;
    }
    return true;
  }
}

/// The width and height of an image, read from the first bytes only.
///
/// Knows PNG, GIF, WebP and JPEG. It never reads the whole image, so a
/// big upload stays out of memory.
class ImageSize {
  const ImageSize(this.width, this.height);

  /// How many first bytes to keep so the size of most JPEG files can be
  /// found. A JPEG keeps its size after the photo metadata (EXIF), which
  /// can be up to 64 KB.
  static const int jpegHeadSize = 128 * 1024;

  final int width;
  final int height;

  /// The size from the first bytes of an image ([head]).
  /// `null` when the bytes are not a PNG, GIF, WebP or JPEG, or when the
  /// header is cut short or broken.
  static ImageSize? read(List<int> head) {
    ImageSize? size = switch (FileTypes.sniff(head)) {
      'png' => _png(head),
      'gif' => _gif(head),
      'webp' => _webp(head),
      'jpg' => _jpeg(head),
      _ => null,
    };
    if (size == null || size.width <= 0 || size.height <= 0) return null;
    return size;
  }

  /// `true` when [file] is an image whose size fits every limit given.
  /// [ratio] is width / height, like `3 / 2`. Like Laravel, a ratio
  /// passes when it is off by less than one pixel.
  static bool fits(
    FileInput file, {
    int? width,
    int? height,
    int? minWidth,
    int? maxWidth,
    int? minHeight,
    int? maxHeight,
    double? ratio,
  }) {
    ImageSize? size = read(file.head);
    if (size == null) return false;
    int w = size.width;
    int h = size.height;
    if (width != null && w != width) return false;
    if (height != null && h != height) return false;
    if (minWidth != null && w < minWidth) return false;
    if (maxWidth != null && w > maxWidth) return false;
    if (minHeight != null && h < minHeight) return false;
    if (maxHeight != null && h > maxHeight) return false;
    if (ratio != null) {
      double tolerance = 1 / ((w > h ? w : h) + 1);
      if ((ratio - w / h).abs() > tolerance) return false;
    }
    return true;
  }

  // PNG: the IHDR chunk comes first. Width and height are big endian.
  static ImageSize? _png(List<int> b) {
    if (b.length < 24 || !FileTypes._ascii(b, 12, 'IHDR')) return null;
    return ImageSize(_be32(b, 16), _be32(b, 20));
  }

  // GIF: the logical screen size, little endian.
  static ImageSize? _gif(List<int> b) {
    if (b.length < 10) return null;
    return ImageSize(_le16(b, 6), _le16(b, 8));
  }

  // WebP: one of the three VP8 chunk kinds.
  static ImageSize? _webp(List<int> b) {
    if (b.length < 25) return null;
    if (FileTypes._ascii(b, 12, 'VP8 ')) {
      if (b.length < 30) return null;
      // lossy: a start code, then 14 bit width and height
      if (b[23] != 0x9D || b[24] != 0x01 || b[25] != 0x2A) return null;
      return ImageSize(_le16(b, 26) & 0x3FFF, _le16(b, 28) & 0x3FFF);
    }
    if (FileTypes._ascii(b, 12, 'VP8L')) {
      // lossless: a signature byte, then 14 bit width - 1 and height - 1
      if (b[20] != 0x2F) return null;
      int bits = b[21] | b[22] << 8 | b[23] << 16 | b[24] << 24;
      return ImageSize((bits & 0x3FFF) + 1, (bits >> 14 & 0x3FFF) + 1);
    }
    if (FileTypes._ascii(b, 12, 'VP8X')) {
      if (b.length < 30) return null;
      // extended: 24 bit canvas width - 1 and height - 1
      return ImageSize(_le24(b, 24) + 1, _le24(b, 27) + 1);
    }
    return null;
  }

  // JPEG: walk the segments until a "start of frame" (SOF) marker.
  static ImageSize? _jpeg(List<int> b) {
    int i = 2;
    while (i + 1 < b.length) {
      if (b[i] != 0xFF) return null;
      int marker = b[i + 1];
      if (marker == 0xFF) {
        i++; // fill byte
        continue;
      }
      // markers without a length
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
        i += 2;
        continue;
      }
      // end of image or start of scan before any frame: no size
      if (marker == 0xD9 || marker == 0xDA) return null;
      if (i + 3 >= b.length) return null;
      int length = _be16(b, i + 2);
      if (length < 2) return null;
      bool frame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (frame) {
        if (i + 9 > b.length) return null;
        return ImageSize(_be16(b, i + 7), _be16(b, i + 5));
      }
      i += 2 + length;
    }
    return null;
  }

  static int _be16(List<int> b, int at) {
    return b[at] << 8 | b[at + 1];
  }

  static int _be32(List<int> b, int at) {
    return b[at] << 24 | b[at + 1] << 16 | b[at + 2] << 8 | b[at + 3];
  }

  static int _le16(List<int> b, int at) {
    return b[at] | b[at + 1] << 8;
  }

  static int _le24(List<int> b, int at) {
    return b[at] | b[at + 1] << 8 | b[at + 2] << 16;
  }
}
