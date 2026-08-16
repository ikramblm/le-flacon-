import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';

/// Opens (and, on first launch, creates) the local SQLite database that
/// backs every table described in schemas_data.dart. This replaces the
/// AppSheet backend, since the source app's data itself was not
/// accessible from the end-user account used to reverse-engineer it.
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
      version: 1,
      onCreate: (db, version) async {
        for (final schema in allSchemas.values) {
          await db.execute(_createTableSql(schema));
        }
        await _seed(db);
      },
    );
  }

  String _createTableSql(TableSchema schema) {
    final buffer = StringBuffer('CREATE TABLE ${schema.tableName} (');
    buffer.write('${schema.primaryKey} TEXT PRIMARY KEY');
    for (final f in schema.fields) {
      final sqlType = (f.type == FieldType.number || f.type == FieldType.price) ? 'REAL' : 'TEXT';
      buffer.write(', ${f.name} $sqlType');
    }
    buffer.write(')');
    return buffer.toString();
  }

  Future<void> _seed(Database db) async {
    // Default account so the app is usable immediately: admin / admin.
    // NOTE: the source AppSheet app stored this password as plain text
    // (flagged in the reverse-engineered docs as a security concern);
    // here it is hashed with SHA-256 instead.
    await db.insert('utilisateurs', {
      'id': '1',
      'utilisateur': 'admin',
      'mot_de_passe': sha256.convert(utf8.encode('admin')).toString(),
    });
  }
}
