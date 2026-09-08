import 'package:face_recognition_sdk/live_frame_prep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planLiveFrame', () {
    test('uses default maxEdge 640', () {
      final plan = planLiveFrame(
        const LiveFramePrepInput(
          frontCamera: false,
          width: 480,
          height: 640,
        ),
      );
      expect(plan.maxEdge, liveFrameMaxEdge);
      expect(plan.rotateDegrees, 0);
    });

    test('back landscape → +90', () {
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: false,
            orientation: 'landscape-left',
            width: 1280,
            height: 720,
          ),
        ).rotateDegrees,
        90,
      );
    });

    test('front landscape → -90', () {
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: true,
            orientation: 'landscape-right',
            width: 1280,
            height: 720,
          ),
        ).rotateDegrees,
        -90,
      );
    });

    test('front portrait → +180 on iOS only', () {
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: true,
            orientation: 'portrait',
            width: 720,
            height: 1280,
            platform: 'ios',
          ),
        ).rotateDegrees,
        180,
      );
    });

    test('front portrait → 0 on Android', () {
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: true,
            orientation: 'portrait',
            width: 720,
            height: 1280,
            platform: 'android',
          ),
        ).rotateDegrees,
        0,
      );
    });

    test('front portrait defaults to +180 when platform omitted', () {
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: true,
            orientation: 'portrait',
            width: 720,
            height: 1280,
          ),
        ).rotateDegrees,
        180,
      );
    });

    test('back portrait → 0', () {
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: false,
            orientation: 'portrait',
            width: 720,
            height: 1280,
            platform: 'android',
          ),
        ).rotateDegrees,
        0,
      );
    });

    test('square treated as portrait path', () {
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: true,
            width: 640,
            height: 640,
            platform: 'ios',
          ),
        ).rotateDegrees,
        180,
      );
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: true,
            width: 640,
            height: 640,
            platform: 'android',
          ),
        ).rotateDegrees,
        0,
      );
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: false,
            width: 640,
            height: 640,
          ),
        ).rotateDegrees,
        0,
      );
    });

    test('respects custom maxEdge', () {
      expect(
        planLiveFrame(
          const LiveFramePrepInput(
            frontCamera: false,
            width: 100,
            height: 100,
            maxEdge: 320,
          ),
        ).maxEdge,
        320,
      );
    });

    test('orientation tag alone does not change degrees when size is portrait', () {
      final a = planLiveFrame(
        const LiveFramePrepInput(
          frontCamera: true,
          orientation: 'landscape-left',
          width: 480,
          height: 640,
          platform: 'ios',
        ),
      );
      final b = planLiveFrame(
        const LiveFramePrepInput(
          frontCamera: true,
          orientation: 'portrait',
          width: 480,
          height: 640,
          platform: 'ios',
        ),
      );
      expect(a.rotateDegrees, 180);
      expect(b.rotateDegrees, 180);
    });
  });
}
