import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';

/// Local SQLite database for Le Flacon.
///
/// There is intentionally no demo administrator account. On a fresh
/// installation, the first account created through the login screen becomes
/// the administrator. Every later account is a normal user.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'le_flacon.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        for (final schema in allSchemas.values) {
          await db.execute(_createTableSql(schema));
        }
        // No demo/default account is inserted.
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE utilisateurs ADD COLUMN role TEXT NOT NULL DEFAULT 'user'",
          );

          // Remove the old demo administrator from previous builds.
          await db.delete(
            'utilisateurs',
            where: 'utilisateur = ?',
            whereArgs: ['admin'],
          );
        }

        if (oldVersion < 3) {
          // Authentication is now phone-number only. Keep the legacy
          // username column for SQLite compatibility, but clear old login
          // accounts so the owner can create a fresh phone-based admin.
          await db.execute(
            "ALTER TABLE utilisateurs ADD COLUMN telephone TEXT",
          );
          await db.delete('utilisateurs');
        }
      },
    );
  }

  String _createTableSql(TableSchema schema) {
    final buffer = StringBuffer('CREATE TABLE ${schema.tableName} (');
    buffer.write('${schema.primaryKey} TEXT PRIMARY KEY');
    for (final f in schema.fields) {
      final sqlType =
          (f.type == FieldType.number || f.type == FieldType.price)
              ? 'REAL'
              : 'TEXT';
      buffer.write(', ${f.name} $sqlType');
    }
    buffer.write(')');
    return buffer.toString();
  }
}
