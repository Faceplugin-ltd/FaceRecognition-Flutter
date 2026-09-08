# Placeholder for optional in-package frameworks

CocoaPods vendors frameworks from `ios/Frameworks/` (see that README).

Drop the three Google Drive frameworks there:

- `facerecognitionsdk.framework`
- `FaceRecognitionEngine.framework`
- `onnxruntime.framework`

This folder is reserved if a future SPM `Package.swift` needs in-package binaries
(relative `../Frameworks` breaks under Flutter’s ephemeral Packages layout).
