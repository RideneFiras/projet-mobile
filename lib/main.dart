import 'package:flutter/material.dart';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/database/web_setup_stub.dart'
    if (dart.library.js_interop) 'core/database/web_setup_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Version web : SQLite en WebAssembly (sans effet sur Android)
  configurerSqliteWeb();
  // Crée / ouvre la base SQLite travel_platform.db
  await DatabaseHelper.instance.database;
  runApp(const TravelPlatformApp());
}
