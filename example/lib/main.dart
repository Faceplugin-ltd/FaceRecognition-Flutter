import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'services/person_database.dart';
import 'services/sdk_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Face capture/identify expect a fixed upright portrait frame — do not follow
  // device rotation (matches native FaceRecognitionSDK Apps).
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  final settings = SettingsService();
  final db = PersonDatabase();
  await settings.load();
  await db.load();
  settings.setClearPersonsCallback(db.clear);

  final sdk = SdkService()..bootstrap();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sdk),
        ChangeNotifierProvider.value(value: db),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const FaceRecognitionApp(),
    ),
  );
}
