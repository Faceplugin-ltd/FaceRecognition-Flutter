<div align="center">
<img alt="FacePlugin" src="https://avatars.githubusercontent.com/u/160751046?s=200&v=4" width="200"/>
</div>

#### 🌐 Company Site - [Here](https://faceplugin.com)
#### 🤗 Hugging Face - [Here](https://huggingface.co/FacePlugin-Ltd)
#### 🛟 Help Center - [Here](https://doc.faceplugin.com)
#### 🐳 Docker Hub - [Here](https://hub.docker.com/u/faceplugin)

# FacePlugin Face Recognition SDK — Flutter (Fully On-Premise)

> **Ready in ~15 minutes (after runtime download):**
> Drop Android AAR + iOS frameworks → Run the example on a phone
> Jump: [Quick start](#quick-start-checklist) · [Get the runtimes](#get-the-runtimes) · [Run the demo](#run-the-demo) · [Integrate into your app](#integrate-into-your-own-app) · [Dart API](#about-sdk-dart-api)

Customer repo name: `FaceRecognition-Flutter`

## Quick start checklist

Use this for the **example app** (check each box in order):

- [ ] Clone `FaceRecognition-Flutter` and run `dart run tool/bootstrap.dart` (or `flutter pub get` at root + `example/`)
- [ ] Fix anything `flutter doctor` reports (Android toolchain, Xcode, licenses, JDK)
- [ ] Download runtimes from [Google Drive](#get-the-runtimes)
- [ ] Android: copy `facerecognitionsdk.aar` → `example/android/libfacesdk/`
- [ ] iOS: unzip frameworks → `ios/Frameworks/` (`facerecognitionsdk`, `FaceRecognitionEngine`, `onnxruntime`)
- [ ] iOS (macOS): `cd example/ios && pod install`
- [ ] `cd example && flutter run` (physical device recommended)
- [ ] Home screen status bar shows **Ready** → Enroll / Identify / Capture / Attribute

> **Integrating into your own app?** Skip to [Integrate into your own app](#integrate-into-your-own-app) — Android AAR path is different (`…/android/libs/` under the plugin dependency). Full API and layer guide: [doc.faceplugin.com](https://doc.faceplugin.com).

## Introduction

FacePlugin **Face Recognition SDK for Flutter** is a fully on-device biometric plugin for Android and iOS. Enroll faces, identify in 1:N with VideoWorker, capture with an oval coach, and read attributes with 2D liveness — all on the phone. The pub package `face_recognition_sdk` wraps the same native engines as our FaceRecognitionSDK Android and iOS apps.

All processing stays on the device. **No** biometric data is sent to FacePlugin cloud — built for KYC, eKYC, and cross-platform mobile onboarding.

This repository contains:

| Folder | Purpose |
| ------ | ------- |
| Repository root | `face_recognition_sdk` — the Flutter plugin you depend on in your app |
| `example/` | Full demo (Enroll, Identify, Capture, Attribute, Settings, About) |

Native binaries are **not** on GitHub (too large). Download them from Google Drive (links below) and copy into the paths shown.

### Main Functionalities

| Feature | Supported |
| ------- | --------- |
| Gallery enroll (single-face template) | ✓ |
| Live 1:N identify with VideoWorker | ✓ |
| 2D liveness / anti-spoofing on identify | ✓ |
| Oval capture coach with optional enroll | ✓ |
| Gallery attributes, landmarks, age, gender, emotion | ✓ |
| Local person database (demo) | ✓ |
| Settings (thresholds / clear DB) | ✓ |

### Product List

| Platform | Repository |
|----------|------------|
| Android (Recognition) | [FaceRecognition-Android](https://github.com/Faceplugin-ltd/FaceRecognition-Android) |
| iOS (Recognition) | [FaceRecognition-iOS](https://github.com/Faceplugin-ltd/FaceRecognition-iOS) |
| React Native (Recognition) | [FaceRecognition-React-Native](https://github.com/Faceplugin-ltd/FaceRecognition-React-Native) |
| **Flutter (Recognition)** | **[FaceRecognition-Flutter](https://github.com/Faceplugin-ltd/FaceRecognition-Flutter)** (**this repo**) |
| Ionic Capacitor (Recognition) | [FaceRecognition-Ionic-Capacitor](https://github.com/Faceplugin-ltd/FaceRecognition-Ionic-Capacitor) |
| Ionic Cordova (Recognition) | [FaceRecognition-Ionic-Cordova](https://github.com/Faceplugin-ltd/FaceRecognition-Ionic-Cordova) |
| Windows (Recognition) | [FaceRecognition-Windows](https://github.com/Faceplugin-ltd/FaceRecognition-Windows) |
| Linux / Docker (Recognition) | [FaceRecognition-Docker](https://github.com/Faceplugin-ltd/FaceRecognition-Docker) |
| Android (Liveness) | [FaceLivenessDetection-Android](https://github.com/Faceplugin-ltd/FaceLivenessDetection-Android) |
| iOS (Liveness) | [FaceLivenessDetection-iOS](https://github.com/Faceplugin-ltd/FaceLivenessDetection-iOS) |
| Windows (Liveness) | [FaceLivenessDetection-Windows](https://github.com/Faceplugin-ltd/FaceLivenessDetection-Windows) |
| Linux / Docker (Liveness) | [FaceLivenessDetection-Docker](https://github.com/Faceplugin-ltd/FaceLivenessDetection-Docker) |


---

## Before you start

| Step | What you need |
| ---- | ------------- |
| 1 | **Flutter** (3.44+ recommended). Run `flutter doctor` and fix reported issues |
| 2 | **JDK 17+** for Android. Prefer Android Studio’s bundled JDK. `JAVA_HOME` must point to the JDK **home** (folder that contains `bin`), not to `bin` itself. Optionally: `flutter config --jdk-dir <path-to-jdk-home>` |
| 3 | Accept Android licenses: `flutter doctor --android-licenses` |
| 4 | **Physical device** recommended (camera / liveness; emulator is limited) |
| 5 | Android `facerecognitionsdk.aar` and iOS frameworks — see [Get the runtimes](#get-the-runtimes) |
| 6 | Demo licenses are in `example/lib/core/constants/license.dart` (Android `com.faceplugin.facerecognitionsdk`, iOS `com.faceplugin.facerecognition.app`). Request a new key only if you change `applicationId` / bundle id — see [SDK License](#sdk-license) |

You can run the **example** app as-is after placing the runtimes. Home tiles unlock when the status bar shows **Ready**.

### System requirements

| Platform | Requirement |
| -------- | ----------- |
| Flutter | 3.44+ (see `pubspec.yaml`) |
| Android | minSdk 24, physical device recommended |
| iOS | iOS 13+, physical device recommended |
| Dart | 3.3+ |

---

## Get the runtimes

Same Google Drive packs as FaceRecognitionSDK Android / iOS (includes `frc.fpk` models inside the runtime).

### Android

[Google Drive — Android](https://drive.google.com/drive/folders/1kpzYVv9Gbm_pEpDe9-x7FGB4NWZzvez0)

| File | Example app path | Your own app path |
| ---- | ---------------- | ----------------- |
| `facerecognitionsdk.aar` | `example/android/libfacesdk/facerecognitionsdk.aar` | Your app’s `android/libfacesdk/facerecognitionsdk.aar` + `include(":libfacesdk")` (copy the module from the example — do **not** use `implementation(files(…aar))` on the plugin) |

### iOS

[Google Drive — iOS](https://drive.google.com/drive/folders/1PKmV-o7gq7s7dDtiNgXPfCi2ZlWaRy5H)

Unzip into `ios/Frameworks/`:

```text
ios/Frameworks/
├── facerecognitionsdk.framework
├── FaceRecognitionEngine.framework
└── onnxruntime.framework
```

Then on a Mac: `dart run tool/bootstrap.dart` (builds matching `.xcframework`s) and `cd example/ios && pod install`. CocoaPods links the `.xcframework`s into the plugin pod — plain `.framework` alone often leaves undefined `FaceRecognitionSDK` symbols under `use_frameworks!`.

---

## Run the demo

```bash
git clone https://github.com/Faceplugin-ltd/FaceRecognition-Flutter.git
cd FaceRecognition-Flutter
dart run tool/bootstrap.dart
# Place AAR + iOS frameworks as above
cd example
flutter run
```

Keep demo ids for the included license:

| Platform | Id |
| -------- | -- |
| Android `applicationId` | `com.faceplugin.facerecognitionsdk` |
| iOS bundle id | `com.faceplugin.facerecognition.app` |

1. Wait for the home **status bar** → **Ready**.
2. Use **Enroll**, **Identify**, **Capture**, and **Attribute** for on-device 1:N matching, oval capture, attributes, and 2D liveness.

### Screenshots

| Home | Identify | Capture |
| ---- | -------- | ------- |
| <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/home.png" alt="FacePlugin Face Recognition — Home with Enroll, Identify, Capture, Attribute, Settings, About" width="240"/></p> | <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/identify.png" alt="FacePlugin Face Recognition — live 1:N identify with face box, landmarks, and liveness" width="240"/></p> | <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/capture.png" alt="FacePlugin Face Recognition — oval capture coach with Move closer" width="240"/></p> |

| Capture result | Attribute | Attribute (emotion) |
| -------------- | --------- | ------------------- |
| <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/capture-result.png" alt="FacePlugin Face Recognition — capture result with liveness, quality, and Enroll" width="240"/></p> | <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/attribute.png" alt="FacePlugin Face Recognition — attributes: 14 landmarks, liveness, age, gender" width="240"/></p> | <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/attribute-emotion.png" alt="FacePlugin Face Recognition — attributes: landmarks, age, gender, emotion" width="240"/></p> |

| Attribute (quality) | Settings | About |
| ------------------- | -------- | ----- |
| <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/attribute-quality.png" alt="FacePlugin Face Recognition — quality: blur, noise, pose, bounding box" width="240"/></p> | <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/settings.png" alt="FacePlugin Face Recognition — Settings for camera lens and thresholds" width="240"/></p> | <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/about.png" alt="FacePlugin Face Recognition SDK — About, on-device identity" width="240"/></p> |

| Home (tiles) | Attribute (liveness) |
| ------------ | -------------------- |
| <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/home-tiles.png" alt="FacePlugin Face Recognition — six home action tiles" width="240"/></p> | <p align="center"><img src="https://raw.githubusercontent.com/Faceplugin-ltd/faceplugin-assets/main/screenshots/face-recognition/android/attribute-liveness.png" alt="FacePlugin Face Recognition — liveness spoof score, age, gender" width="240"/></p> |

---

## SDK License

Licenses are **offline** and bound to your `applicationId` / bundle identifier.

The sample app already includes a valid key for `com.faceplugin.facerecognitionsdk`. You only need a new key if you use a different id.

### How to get a license

The code below shows how to use the license:

[https://github.com/Faceplugin-ltd/FaceRecognition-Flutter/blob/7ecff0aaeab88156283abca007e07f15e9381976/example/lib/core/constants/license.dart#L6-L14](https://github.com/Faceplugin-ltd/FaceRecognition-Flutter/blob/7ecff0aaeab88156283abca007e07f15e9381976/example/lib/core/constants/license.dart#L6-L14)

[https://github.com/Faceplugin-ltd/FaceRecognition-Flutter/blob/7ecff0aaeab88156283abca007e07f15e9381976/example/lib/services/sdk_service.dart#L28-L39](https://github.com/Faceplugin-ltd/FaceRecognition-Flutter/blob/7ecff0aaeab88156283abca007e07f15e9381976/example/lib/services/sdk_service.dart#L28-L39)

Please [contact us](#contact) to get a license for **your own app**.

---

## Integrate into your own app

You need the Flutter plugin + native runtimes. You do **not** need the example UI or person database (those are demo-only).

1. Add a path or git dependency:

```yaml
dependencies:
  face_recognition_sdk:
    git:
      url: https://github.com/Faceplugin-ltd/FaceRecognition-Flutter.git
```

Or path:

```yaml
dependencies:
  face_recognition_sdk:
    path: ../FaceRecognition-Flutter
```

2. Copy runtimes:

| Platform | Copy to |
| -------- | ------- |
| Android | Copy `example/android/libfacesdk/` into **your app** `android/libfacesdk/`, put `facerecognitionsdk.aar` there, and `include(":libfacesdk")` in `settings.gradle(.kts)`. (Do not `implementation(files(…aar))` inside the plugin — AGP will fail `bundleDebugAar`.) |
| iOS | Plugin checkout `ios/Frameworks/` (three frameworks), then `pod install` |

3. Set **your** `applicationId` / iOS bundle id and request a license for **that** id (not the demo id).

4. Permissions: camera + photo library (see example `AndroidManifest.xml` / `Info.plist`).

5. Minimal usage:

```dart
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

Future<void> activate() async {
  final code = await getMachineCode(); // FPMC1.… — send when requesting a key
  final act = await setActivation('FP1.…'); // bound to YOUR applicationId / bundle id
  if (act != sdkSuccess) {
    throw StateError(await lastLicenseError());
  }
  final initCode = await init();
  if (initCode != sdkSuccess) {
    throw StateError('init failed: $initCode');
  }
}

Future<void> enrollStill(String imagePath) async {
  final faces = await faceDetection(imagePath);
  if (faces.length != 1) return;
  final template = await templateExtraction(imagePath, faces.first);
  final cropB64 = await cropFace(imagePath, faces.first);
  // Store template + crop in YOUR database
}
```

Thresholds (identify, liveness, pose, eye-close, Capture settings) are **parameters** you pass from Dart — change them freely for your product. Defaults in the example Settings match FaceRecognitionSDK Apps (`identify` 0.67, `liveness` 0.5, level `0`, pose `40°`, eyeclose `0.5`).

---

## About SDK (Dart API)

Call order: `getMachineCode` → `setActivation` → `init` → detect / VideoWorker → `deinit` when done.

| API | Purpose |
| --- | ------- |
| `getMachineCode()` | `FPMC1.…` for license requests |
| `setActivation(license)` | Activate with `FP1.…` |
| `init()` / `deinit()` | Load / unload engine |
| `faceDetection(image, param?)` | Canonical `FaceBox` list |
| `detect(image, crop?, flags?)` | Raw engine JSON |
| `templateExtraction` / `cropFace` / `similarity` | Enroll + 1:1 match |
| `startVideoWorker` / `syncVideoWorkerDatabase` / `ingestLiveCameraFrame` | Live 1:N |
| `videoWorkerEvents` | Stream of tracking / match JSON |
| `FaceCapture` | Optional oval capture UI (`package:face_recognition_sdk/capture`) |
| `lastLicenseError()` | Human-readable license failure |

### FaceBox (cheat sheet)

Boxes include geometry (`x1,y1,x2,y2`), pose, liveness / quality / eyes / occlusion scores and labels, age / gender / emotion / mask / glasses, optional `attributes` map, and `landmarks` + `landmarkCount`.

### Status codes

| Code | Meaning |
| ---- | ------- |
| 0 | Success |
| 1 | License invalid |
| 2 | License expired |
| 3 | Not activated |
| 4 | Init failed |

---

## Example app layout

| Path | Role |
| ---- | ---- |
| `example/lib/core/constants/license.dart` | Demo FP1 keys only |
| `example/lib/services/` | SdkService, Settings, PersonDatabase (demo) |
| `example/lib/screens/` | Home, Identify, Capture, Attribute, Result, Settings, About |

---

## Contact

<div align="left">
<a target="_blank" href="mailto:info@faceplugin.com"><img src="https://img.shields.io/badge/email-info@faceplugin.com-blue.svg?logo=gmail" alt="faceplugin.com"></a>&emsp;
<a target="_blank" href="https://wa.me/+14692784822"><img src="https://img.shields.io/badge/whatsapp-faceplugin-blue.svg?logo=whatsapp" alt="faceplugin.com"></a>
</div>
