import 'package:sqflite/sqflite.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';
import 'id_generator.dart';

/// Generic CRUD + relationship + computed-value access, driven entirely
/// by TableSchema metadata. This is the app's equivalent of AppSheet's
/// auto-generated data layer.
class Repository {
  final Database db;
  Repository(this.db);

  bool get _isDated => false;

  String _defaultOrder(TableSchema schema) =>
      (schema.tableName == 'vente' || schema.tableName == 'charges' || schema.tableName == 'inventaires')
          ? 'date DESC'
          : schema.displayField;

  Future<List<Map<String, dynamic>>> getAll(TableSchema schema) {
    return db.query(schema.tableName, orderBy: _defaultOrder(schema));
  }

  /// Same as getAll but LEFT JOINs every ref field so the caller gets a
  /// human-readable "<field>_display" column alongside each raw id.
  Future<List<Map<String, dynamic>>> getEnriched(TableSchema schema) async {
    final refs = schema.refFields;
    if (refs.isEmpty) {
      return db.query(schema.tableName, orderBy: _defaultOrder(schema));
    }
    final select = StringBuffer('SELECT t.*');
    final joins = StringBuffer();
    var i = 0;
    for (final f in refs) {
      final refSchema = allSchemas[f.refTable];
      if (refSchema == null) continue;
      final alias = 'r$i';
      select.write(', $alias.${refSchema.displayField} AS ${f.name}_display');
      joins.write(' LEFT JOIN ${refSchema.tableName} $alias ON t.${f.name} = $alias.${refSchema.primaryKey}');
      i++;
    }
    select.write(' FROM ${schema.tableName} t');
    select.write(joins.toString());
    final orderCol = (schema.tableName == 'vente' || schema.tableName == 'charges' || schema.tableName == 'inventaires')
        ? 't.date DESC'
        : 't.${schema.displayField}';
    select.write(' ORDER BY $orderCol');
    return db.rawQuery(select.toString());
  }

  Future<Map<String, dynamic>?> getById(TableSchema schema, String? id) async {
    if (id == null || id.isEmpty) return null;
    final rows = await db.query(schema.tableName, where: '${schema.primaryKey} = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> generateId(TableSchema schema) async {
    if (schema.useSequentialId) {
      final rows = await db.rawQuery(
        'SELECT MAX(CAST(${schema.primaryKey} AS INTEGER)) as m FROM ${schema.tableName}',
      );
      final maxVal = rows.first['m'];
      final next = (maxVal == null ? 0 : (maxVal as int)) + 1;
      return next.toString();
    }
    String id;
    Map<String, dynamic>? existing;
    do {
      id = IdGenerator.shortHex();
      existing = await getById(schema, id);
    } while (existing != null);
    return id;
  }

  Future<void> insertRecord(TableSchema schema, Map<String, dynamic> values) async {
    await db.insert(schema.tableName, values);
  }

  Future<void> updateRecord(TableSchema schema, String id, Map<String, dynamic> values) async {
    await db.update(schema.tableName, values, where: '${schema.primaryKey} = ?', whereArgs: [id]);
  }

  Future<void> deleteRecord(TableSchema schema, String id) async {
    await db.delete(schema.tableName, where: '${schema.primaryKey} = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getRelated(TableSchema childSchema, String refFieldName, String parentId) {
    return db.query(
      childSchema.tableName,
      where: '$refFieldName = ?',
      whereArgs: [parentId],
      orderBy: (childSchema.tableName == 'vente' || childSchema.tableName == 'charges') ? 'date DESC' : null,
    );
  }

  Future<int> countRelated(TableSchema childSchema, String refFieldName, String parentId) async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${childSchema.tableName} WHERE $refFieldName = ?',
      [parentId],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<double> sumField(TableSchema schema, String field, {String? whereClause, List<Object?>? whereArgs}) async {
    final where = whereClause != null ? ' WHERE $whereClause' : '';
    final r = await db.rawQuery('SELECT SUM($field) as s FROM ${schema.tableName}$where', whereArgs);
    final v = r.first['s'];
    return v == null ? 0 : (v as num).toDouble();
  }

  double _numOr0(dynamic v) => v == null ? 0 : (v as num).toDouble();

  /// Recette.Prix Total d'achat / Prix total de vente — computed from the
  /// ml quantities of extrait/alcool/fixateur times each component's unit price.
  Future<Map<String, double>> computeRecettePrices({
    String? produitId,
    double mlExtrait = 0,
    String? alcoolId,
    double mlAlcool = 0,
    String? fixateurId,
    double mlFixateur = 0,
  }) async {
    double achat = 0, vente = 0;
    if (produitId != null && produitId.isNotEmpty) {
      final p = await getById(parfumsSchema, produitId);
      achat += mlExtrait * _numOr0(p?['prix_achat_ml']);
      vente += mlExtrait * _numOr0(p?['prix_vente_ml']);
    }
    if (alcoolId != null && alcoolId.isNotEmpty) {
      final a = await getById(ingredientsSchema, alcoolId);
      achat += mlAlcool * _numOr0(a?['prix_achat']);
      vente += mlAlcool * _numOr0(a?['prix_vente']);
    }
    if (fixateurId != null && fixateurId.isNotEmpty) {
      final f = await getById(ingredientsSchema, fixateurId);
      achat += mlFixateur * _numOr0(f?['prix_achat']);
      vente += mlFixateur * _numOr0(f?['prix_vente']);
    }
    return {'achat': achat, 'vente': vente};
  }

  /// Mélanges.Prix total — sum of each blended component's sale price × ml.
  Future<double> computeMelangePrice({
    String? extrait1Id,
    double mlExtrait1 = 0,
    String? extrait2Id,
    double mlExtrait2 = 0,
    String? ingredientId,
    double mlIngredient = 0,
  }) async {
    double total = 0;
    if (extrait1Id != null && extrait1Id.isNotEmpty) {
      final p = await getById(parfumsSchema, extrait1Id);
      total += mlExtrait1 * _numOr0(p?['prix_vente_ml']);
    }
    if (extrait2Id != null && extrait2Id.isNotEmpty) {
      final p = await getById(parfumsSchema, extrait2Id);
      total += mlExtrait2 * _numOr0(p?['prix_vente_ml']);
    }
    if (ingredientId != null && ingredientId.isNotEmpty) {
      final i = await getById(ingredientsSchema, ingredientId);
      total += mlIngredient * _numOr0(i?['prix_vente']);
    }
    return total;
  }
}
