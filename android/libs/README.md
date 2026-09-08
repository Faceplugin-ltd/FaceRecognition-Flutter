# Android runtime for *your* Flutter app

Do **not** put `facerecognitionsdk.aar` here and expect `implementation(files(…))` —
AGP rejects that for Flutter plugin library modules (`bundleDebugAar` fails).

## Correct wiring (same as the example)

1. Download [Android runtime (Google Drive)](https://drive.google.com/drive/folders/1kpzYVv9Gbm_pEpDe9-x7FGB4NWZzvez0)
2. Copy the `libfacesdk` folder from this repo’s `example/android/libfacesdk/` into **your app’s** `android/` tree
3. Place `facerecognitionsdk.aar` inside that folder
4. In your app `android/settings.gradle(.kts)`:

```kotlin
include(":libfacesdk")
```

The plugin resolves `project(":libfacesdk")` automatically when that module exists.

## Demo app

Use `example/android/libfacesdk/facerecognitionsdk.aar` only — do not also drop an AAR into this `android/libs/` folder.
