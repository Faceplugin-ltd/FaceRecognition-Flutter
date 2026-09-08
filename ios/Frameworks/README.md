# iOS frameworks (Google Drive)

Download from:

https://drive.google.com/drive/folders/1PKmV-o7gq7s7dDtiNgXPfCi2ZlWaRy5H

Unzip into this folder:

- `facerecognitionsdk.framework`
- `FaceRecognitionEngine.framework`
- `onnxruntime.framework`

Then from the plugin root:

```bash
dart run tool/bootstrap.dart
# or: cd example/ios && pod install
```

That creates matching `*.xcframework` next to each `.framework`. CocoaPods vendors the xcframeworks into the plugin pod so the linker resolves `FaceRecognitionSDK` symbols.

Windows machines only need the Android AAR for `flutter run`; iOS packaging requires a Mac.
