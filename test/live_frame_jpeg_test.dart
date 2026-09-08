import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Encode/decode fixture for the BGRA → JPEG path used by [feedCameraFrame].
void main() {
  test('BGRA buffer encodes to a decodable JPEG', () {
    const w = 8;
    const h = 8;
    final bgra = List<int>.filled(w * h * 4, 0);
    for (var i = 0; i < w * h; i++) {
      bgra[i * 4] = 255; // B
      bgra[i * 4 + 1] = 0;
      bgra[i * 4 + 2] = 0;
      bgra[i * 4 + 3] = 255;
    }
    final image = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: Uint8List.fromList(bgra).buffer,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    );
    final jpg = img.encodeJpg(image, quality: 85);
    expect(jpg.length, greaterThan(32));
    final decoded = img.decodeJpg(jpg);
    expect(decoded, isNotNull);
    expect(decoded!.width, w);
    expect(decoded.height, h);
  });
}
