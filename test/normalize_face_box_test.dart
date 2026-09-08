import 'package:face_recognition_sdk/normalize_face_box.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeFaceBox', () {
    test('is identity when attributes already present (iOS shape)', () {
      final ios = <String, dynamic>{
        'x1': 10,
        'y1': 20,
        'x2': 100,
        'y2': 120,
        'liveness': 0.9,
        'livenessLabel': 'Real · 90%',
        'glassesLabel': 'No',
        'attributes': {
          'Liveness2D': 'Real · 90%',
          'Glasses': 'No',
          'Lighting': 'Good · 80%',
        },
      };
      final out = normalizeFaceBox(ios);
      expect(out['attributes']?['Lighting'], 'Good · 80%');
      expect(out['livenessLabel'], 'Real · 90%');
    });

    test('synthesizes attributes from Android typed fields', () {
      final android = <String, dynamic>{
        'x1': 1,
        'y1': 2,
        'x2': 3,
        'y2': 4,
        'age': 30,
        'genderLabel': 'Male',
        'emotionLabel': 'Neutral',
        'maskLabel': 'No Mask',
        'liveness': 0.85,
        'livenessLabel': 'Real',
        'qualityLabel': 'Good',
        'face_quality': 0.7,
        'eyesLeftLabel': 'Open',
        'eyesRightLabel': 'Open',
        'face_occlusion': 0.1,
      };
      final out = normalizeFaceBox(android);
      final attrs = Map<String, dynamic>.from(out['attributes'] as Map);
      expect(attrs['Gender'], 'Male');
      expect(attrs['Emotion'], 'Neutral');
      expect(attrs['MedicalMask'], 'No Mask');
      expect(attrs['Liveness2D'], 'Real · 85%');
      expect(attrs['Age'], '30');
      expect(attrs['EyesLeft'], 'Open');
      expect(out['occlusionLabel']?.toString(), contains('Clear'));
      expect(attrs['Occlusion']?.toString(), contains('Clear'));
      expect(attrs.containsKey('Glasses'), isFalse);
    });

    test('normalizes arrays', () {
      final boxes = normalizeFaceBoxes([
        {'x1': 0, 'y1': 0, 'x2': 1, 'y2': 1, 'genderLabel': 'Female'},
        {
          'x1': 0,
          'y1': 0,
          'x2': 1,
          'y2': 1,
          'attributes': {'Gender': 'Male'},
          'genderLabel': 'Male',
        },
      ]);
      expect(
        (boxes[0]['attributes'] as Map)['Gender'],
        'Female',
      );
      expect(
        (boxes[1]['attributes'] as Map)['Gender'],
        'Male',
      );
    });
  });
}
