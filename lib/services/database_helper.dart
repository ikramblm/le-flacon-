import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';

/// Local SQLite database for Le Flacon.
/// No demo administrator is created. The first account created in the login
/// screen becomes admin; later accounts are users.
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
      version: 4,
      onCreate: (db, version) async {
        for (final schema in allSchemas.values) {
          await db.execute(_createTableSql(schema));
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Make migrations resilient even if an earlier development build
        // reported a version without actually having all new columns.
        await _ensureColumn(db, 'utilisateurs', 'role', "TEXT NOT NULL DEFAULT 'user'");
        await _ensureColumn(db, 'utilisateurs', 'telephone', 'TEXT');

        // Remove legacy/demo login accounts. The owner creates a fresh
        // phone-based admin from the login screen.
        if (oldVersion < 4) {
          await db.delete('utilisateurs');
        }
      },
    );
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
