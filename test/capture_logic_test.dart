import 'package:face_recognition_sdk/capture/capture.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart' show FaceBox;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oval = OvalMetrics(width: 720, height: 1280);
  const settings = CaptureSettings.defaults;

  group('checkFace', () {
    test('no face', () {
      expect(checkFace(<FaceBox>[], settings, oval), FaceCaptureState.noFace);
    });

    test('multiple faces', () {
      const a = FaceBox(x1: 0, y1: 0, x2: 10, y2: 10);
      const b = FaceBox(x1: 20, y1: 20, x2: 30, y2: 30);
      expect(checkFace([a, b], settings, oval), FaceCaptureState.multipleFaces);
    });

    test('small face → move closer', () {
      const tiny = FaceBox(x1: 350, y1: 600, x2: 370, y2: 620);
      expect(checkFace([tiny], settings, oval), FaceCaptureState.moveCloser);
    });

    test('yaw over threshold → no front', () {
      const turned = FaceBox(
        x1: 200,
        y1: 420,
        x2: 520,
        y2: 860,
        yaw: 50,
      );
      expect(checkFace([turned], settings, oval), FaceCaptureState.noFront);
    });
  });

  test('warningFor maps states', () {
    expect(warningFor(FaceCaptureState.multipleFaces), contains('Multiple'));
    expect(warningFor(FaceCaptureState.captureOk), isEmpty);
  });
}
