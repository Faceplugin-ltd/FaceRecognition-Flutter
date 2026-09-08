#!/usr/bin/env dart
// Cross-platform setup checks (Windows / macOS / Linux).
// Usage from repo root:
//   dart run tool/bootstrap.dart

import 'dart:io';

void main() async {
  final root = Directory.current;
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync() ||
      !pubspec.readAsStringSync().contains('name: face_recognition_sdk')) {
    stderr.writeln(
      'Run from the FaceRecognition-Flutter repo root '
      '(folder that contains pubspec.yaml for face_recognition_sdk).',
    );
    exitCode = 1;
    return;
  }

  section('Flutter');
  await run('flutter', ['--version']);
  await run('flutter', ['pub', 'get']);
  await run('flutter', ['pub', 'get'], workingDirectory: p(root, 'example'));

  section('Android AAR');
  final exampleAar = File(
    p(root, 'example', 'android', 'libfacesdk', 'facerecognitionsdk.aar'),
  );
  if (exampleAar.existsSync()) {
    ok(exampleAar.path);
  } else {
    missing(
      exampleAar.path,
      'For the demo: copy facerecognitionsdk.aar from Google Drive '
      '(FaceRecognitionSDK Android pack) into example/android/libfacesdk/.',
    );
  }
  final pluginLibsAar = File(p(root, 'android', 'libs', 'facerecognitionsdk.aar'));
  if (pluginLibsAar.existsSync()) {
    print(
      'WARNING: ${pluginLibsAar.path} is present.\n'
      '  AGP cannot link a local .aar via implementation(files(…)) from the\n'
      '  Flutter plugin module. Remove this file and use :libfacesdk instead\n'
      '  (example/android/libfacesdk/ for the demo).',
    );
    exitCode = 1;
  }

  section('iOS frameworks');
  if (Platform.isWindows) {
    print(
      'Skipped on Windows (iOS builds require macOS + Xcode). '
      'On a Mac: place these under ios/Frameworks/ then run this script again '
      '(or pod install):\n'
      '  facerecognitionsdk.framework\n'
      '  FaceRecognitionEngine.framework\n'
      '  onnxruntime.framework',
    );
  } else {
    var allPresent = true;
    for (final name in [
      'facerecognitionsdk.framework',
      'FaceRecognitionEngine.framework',
      'onnxruntime.framework',
    ]) {
      final fw = Directory(p(root, 'ios', 'Frameworks', name));
      if (fw.existsSync()) {
        ok(fw.path);
      } else {
        allPresent = false;
        missing(
          fw.path,
          'Unzip from Google Drive (FaceRecognitionSDK iOS pack) into ios/Frameworks/.',
        );
      }
    }
    if (allPresent) {
      final code = await ensureXcframeworks(root);
      if (code != 0) exitCode = code;
    }
  }

  section('Done');
  print('Next:  cd example && flutter run');
  print(
    'Demo license is bound to Android applicationId com.faceplugin.facerecognitionsdk '
    'and iOS bundle id com.faceplugin.facerecognition.app — change those ids only with a new FP1 key.',
  );
  if (!Platform.isWindows) {
    print('iOS: cd example/ios && pod install → open Runner.xcworkspace → set Team');
  }
}

Future<int> ensureXcframeworks(Directory root) async {
  for (final base in [
    'facerecognitionsdk',
    'FaceRecognitionEngine',
    'onnxruntime',
  ]) {
    final fwPath = p(root, 'ios', 'Frameworks', '$base.framework');
    final fw = Directory(fwPath);
    if (!fw.existsSync()) continue;

    var binary = File('$fwPath${Platform.pathSeparator}$base');
    if (!binary.existsSync()) {
      binary = File('$fwPath${Platform.pathSeparator}lib$base.dylib');
    }
    final xcPath = p(root, 'ios', 'Frameworks', '$base.xcframework');
    final xc = Directory(xcPath);
    final plist = File('$xcPath${Platform.pathSeparator}Info.plist');

    if (xc.existsSync() &&
        plist.existsSync() &&
        binary.existsSync() &&
        !binary.lastModifiedSync().isAfter(plist.lastModifiedSync())) {
      print('$base.xcframework already up to date');
      continue;
    }

    if (xc.existsSync()) {
      xc.deleteSync(recursive: true);
    }
    print('Creating $xcPath');
    final result = await Process.run(
      'xcodebuild',
      [
        '-create-xcframework',
        '-framework',
        fw.path,
        '-output',
        xcPath,
      ],
      workingDirectory: root.path,
      runInShell: true,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      stderr.writeln('xcodebuild failed for $base');
      return result.exitCode;
    }
    ok(xcPath);
  }
  return 0;
}

Future<void> run(
  String exe,
  List<String> args, {
  String? workingDirectory,
}) async {
  print('+ $exe ${args.join(' ')}');
  final result = await Process.run(
    exe,
    args,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
  }
}

String p(Directory root, String a, [String? b, String? c, String? d]) {
  final parts = [
    root.path,
    a,
    if (b != null) b,
    if (c != null) c,
    if (d != null) d,
  ];
  return parts.join(Platform.pathSeparator);
}

void section(String title) => print('\n== $title ==');
void ok(String path) => print('ok: $path');
void missing(String path, String hint) {
  print('MISSING: $path');
  print('  → $hint');
  exitCode = 1;
}
