import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/shared/utils/decode_image.dart';

/// 30 x 12 pixels.
const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAB4AAAAMCAIAAAD6TJplAAACdUlEQVR42g3MkQKFMABA0W'
    'EYDMJwGAaDMByGwSAMhxeDQRgOw2AQhsMwGIR9xnvnA44QgkJQCipBLVCCRtAKOkEvMIJB'
    'MAomwSxwAgSLYBVsgiDYBYfgFFyCJLgFj+AVfAIhJIWklFSSWqIkjaSVdJJeYiSDZJRMkl'
    'niJEgWySrZJEGySw7JKbkkSXJLHskr+eS/VhSKUlEpaoVSNIpW0Sl6hVEMilExKWaFU6BY'
    'FKtiUwTFrjgUp+JSJMWteBSv4lP/WlNoSk2lqTVK02haTafpNUYzaEbNpJk1ToNm0ayaTR'
    'M0u+bQnJpLkzS35tG8mk//a0NhKA2VoTYoQ2NoDZ2hNxjDYBgNk2E2OAOGxbAaNkMw7IbD'
    'cBouQzLchsfwGj7zry2FpbRUltqiLI2ltXSW3mIsg2W0TJbZ4ixYFstq2SzBslsOy2m5LM'
    'lyWx7La/nsv3YUjtJROWqHcjSO1tE5eodxDI7RMTlmh3PgWByrY3MEx+44HKfjciTH7Xgc'
    'r+Nz/9pTeEpP5ak9ytN4Wk/n6T3GM3hGz+SZPc6DZ/Gsns0TPLvn8Jyey5M8t+fxvJ7P/+'
    'tAESgDVaAOqEATaANdoA+YwBAYA1NgDrgAgSWwBrZACOyBI3AGrkAK3IEn8Aa+8K8jRaSM'
    'VJE6oiJNpI10kT5iIkNkjEyROeIiRJbIGtkiIbJHjsgZuSIpckeeyBv54r9OFIkyUSXqhE'
    'o0iTbRJfqESQyJMTEl5oRLkFgSa2JLhMSeOBJn4kqkxJ14Em/iS/86U2TKTJWpMyrTZNpM'
    'l+kzJjNkxsyUmTMuQ2bJrJktEzJ75sicmSuTMnfmybyZL/MD4/jx4LAguOoAAAAASUVORK'
    '5CYII=';

/// 30 x 12 pixels, with no EXIF.
const String _jpegBase64 =
    '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGg'
    'AAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAHqADAAQAAAABAAAADAAAAAD/7QA4UGhv'
    'dG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8'
    'AAEQgADAAeAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//E'
    'ALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJD'
    'NicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3'
    'eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1t'
    'fY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYH'
    'CAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQ'
    'kjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdo'
    'aWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8'
    'jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMACQkJCQkJEAkJEBYQEBAWHhYW'
    'FhYeJh4eHh4eJi4mJiYmJiYuLi4uLi4uLjc3Nzc3N0BAQEBASEhISEhISEhISP/bAEMBCw'
    'wMEhESHxERH0szKjNLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tL'
    'S0tLS0tLS0tLS//dAAQAAv/aAAwDAQACEQMRAD8A4aLR/atGLR/au2itYfStGK1h9K3qZh'
    'I8TB5pM4mLR/atCPR+OldvFbQ+laEdrDjpXn1MwkfXYTNJ2P/Z';

/// Adds an APP1 segment that stores [orientation] as EXIF, right after SOI.
Uint8List _withOrientation(Uint8List jpeg, int orientation) {
  return Uint8List.fromList([
    ...jpeg.take(2),
    ...[0xFF, 0xE1, 0x00, 0x22],
    ...ascii.encode('Exif'),
    ...[0x00, 0x00],
    ...[0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08],
    ...[0x00, 0x01],
    ...[0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01],
    ...[0x00, orientation, 0x00, 0x00],
    ...[0x00, 0x00, 0x00, 0x00],
    ...jpeg.skip(2),
  ]);
}

Future<Size> _decodedSize(Uint8List bytes) async {
  final decoded = await decodeImageFromList(bytes);
  final size = Size(decoded.width.toDouble(), decoded.height.toDouble());
  decoded.dispose();
  return size;
}

void main() {
  final png = base64Decode(_pngBase64);
  final jpeg = base64Decode(_jpegBase64);

  group('readImageSize - normal cases', () {
    testWidgets('reads the size of a PNG', (tester) async {
      final size = await tester.runAsync(() => readImageSize(png));

      expect(size, const Size(30, 12));
    });

    testWidgets('reads the size of a JPEG', (tester) async {
      final size = await tester.runAsync(() => readImageSize(jpeg));

      expect(size, const Size(30, 12));
    });
  });

  group('readImageSize - edge cases', () {
    testWidgets('a full decode swaps the sides for orientation 6',
        (tester) async {
      final size = await tester.runAsync(
        () => _decodedSize(_withOrientation(jpeg, 6)),
      );

      expect(size, const Size(12, 30));
    });

    for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
      testWidgets('matches a full decode for orientation $orientation',
          (tester) async {
        final bytes = _withOrientation(jpeg, orientation);

        final sizes = await tester.runAsync(
          () async => [await readImageSize(bytes), await _decodedSize(bytes)],
        );

        expect(sizes![0], sizes[1]);
      });
    }
  });

  group('readImageSize - failure cases', () {
    testWidgets('throws on bytes that are not an image', (tester) async {
      final error = await tester.runAsync(() async {
        try {
          await readImageSize(Uint8List.fromList([1, 2, 3, 4]));
          return null;
        } catch (error) {
          return error;
        }
      });

      expect(error, isNotNull);
    });
  });
}
