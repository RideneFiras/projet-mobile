import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Navigateur (Chrome) : SQLite tourne en WebAssembly, données gardées
/// dans le navigateur. Nécessite web/sqlite3.wasm et web/sqflite_sw.js
/// (créés par 3_VERSION_WEB.bat).
void configurerSqliteWeb() {
  databaseFactory = databaseFactoryFfiWeb;
}
