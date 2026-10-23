import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';

/// Local SQLite database for Le Flacon.
///
/// There is exactly one, fixed administrator account. It is seeded
/// automatically the first time the database is created (and restored on
/// upgrade for existing installs). There is no self-registration: every
/// other account must be created by that administrator from
/// "Gestion des utilisateurs".
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  // Fixed admin credentials (phone + SHA-256 of the password). Changing the
  // admin's login later should be done from "Gestion des utilisateurs" once
  // logged in, not by editing this seed — this only controls the account
  // created on a fresh install.
  static const String _adminPhone = '0512345678';
  static const String _adminPasswordHash =
      '75c3ba988d3709e5dfe2eb36aaf2f8d1346bfcce500339f835cfd246fe0963ea';

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'le_flacon.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        for (final schema in allSchemas.values) {
          await db.execute(_createTableSql(schema));
        }
        await _seedAdmin(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Make migrations resilient even if an earlier development build
        // reported a version without actually having all new columns.
        await _ensureColumn(db, 'utilisateurs', 'role', "TEXT NOT NULL DEFAULT 'user'");
        await _ensureColumn(db, 'utilisateurs', 'telephone', 'TEXT');

        if (oldVersion < 5) {
          // Self-registration is gone and there is now exactly one fixed
          // admin account: clear out any legacy/demo/self-created accounts
          // (including any old first-login admin) and reseed the fixed one.
          await db.delete('utilisateurs');
          await _seedAdmin(db);
        }
      },
    );
  }

  Future<void> _seedAdmin(Database db) async {
    final existing = await db.query(
      'utilisateurs',
      where: 'telephone = ?',
      whereArgs: [_adminPhone],
    );
    if (existing.isNotEmpty) return;

    await db.insert('utilisateurs', {
      'id': '1',
      'telephone': _adminPhone,
      'mot_de_passe': _adminPasswordHash,
      'role': 'admin',
    });
  }

  Future<void> _ensureColumn(Database db, String table, String column, String definition) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name']?.toString() == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
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
