# iOS example host

Requirements: **Flutter 3.44+**, **macOS + Xcode**, physical device recommended.

Demo license bundle id: **`com.faceplugin.facerecognition.app`**
(Android demo `applicationId` is `com.faceplugin.facerecognitionsdk` — different on purpose.)

1. Unzip the three Drive frameworks into the **plugin** folder (not `example/ios/`):

   ```text
   FaceRecognition-Flutter-App/ios/Frameworks/
   ├── facerecognitionsdk.framework
   ├── FaceRecognitionEngine.framework
   └── onnxruntime.framework
   ```

2. From the **plugin root**: `dart run tool/bootstrap.dart` (should print `ok:` for each framework)
3. `cd example && flutter pub get`
4. `cd ios && pod install`  ← required again after copying frameworks
5. Open `Runner.xcworkspace` and set **Team** / signing

Camera / photos: `Podfile` `post_install` sets `PERMISSION_CAMERA=1` and
`PERMISSION_PHOTOS=1` for `permission_handler`.
