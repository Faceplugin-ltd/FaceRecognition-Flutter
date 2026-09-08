import 'package:face_recognition_sdk/capture/capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseVideoWorkerEvent', () {
    test('parses tracking with face region and pose', () {
      const json = '''
      {"event":"tracking","frame_width":480,"frame_height":640,"faces":[{
        "track_id":3,
        "weak":false,
        "faceRegion":{"x":10,"y":20,"width":100,"height":120},
        "facePose":{"yaw":1.5,"pitch":-2,"roll":0},
        "facePoints":[{"x":15,"y":25}],
        "match":{"matched":true,"person_index":1,"score":0.91}
      }]}
      ''';
      final ev = parseVideoWorkerEvent(json);
      expect(ev, isA<VideoWorkerTracking>());
      final t = ev as VideoWorkerTracking;
      expect(t.frameWidth, 480);
      expect(t.frameHeight, 640);
      expect(t.faces, hasLength(1));
      expect(t.faces.first.trackId, 3);
      expect(t.faces.first.match?.matched, isTrue);
      expect(t.faces.first.match?.personIndex, 1);
      final box = workerFaceToBox(t.faces.first);
      expect(box.x1, 10);
      expect(box.y1, 20);
      expect(box.x2, 110);
      expect(box.y2, 140);
    });

    test('parses match event', () {
      const json =
          '{"event":"match","track_id":7,"matched":true,"person_index":2,"score":0.8}';
      final ev = parseVideoWorkerEvent(json);
      expect(ev, isA<VideoWorkerMatchEvent>());
      final m = ev as VideoWorkerMatchEvent;
      expect(m.trackId, 7);
      expect(m.matched, isTrue);
      expect(m.personIndex, 2);
      expect(m.score, 0.8);
    });

    test('returns null for junk', () {
      expect(parseVideoWorkerEvent('not-json'), isNull);
      expect(parseVideoWorkerEvent('{"event":"unknown"}'), isNull);
    });
  });
}
