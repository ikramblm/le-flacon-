import '../services/repository.dart';

/// The kinds of fields a table can have. Mirrors the column types
/// observed in the original AppSheet app.
enum FieldType {
  text,
  number,
  price,
  phone,
  email,
  date,
  dateTime,
  enumType,
  ref,
  photo,
}

/// Describes a single column: how to render it, validate it, and
/// whether it depends on another field to decide its visibility
/// (e.g. Vente.Recette is only shown when Type de produit = "Recette simple").
class FieldDef {
  final String name; // sqlite column name
  final String label; // human label shown in the UI
  final FieldType type;
  final bool required;
  final bool readOnly; // computed / looked-up value, not directly editable
  final bool multiline;
  final String? refTable; // target table name, for FieldType.ref
  final List<String>? enumValues;
  final String? visibleWhenField;
  final List<String>? visibleWhenValues;
  final bool showInList; // included in the list-screen subtitle

  const FieldDef({
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.readOnly = false,
    this.multiline = false,
    this.refTable,
    this.enumValues,
    this.visibleWhenField,
    this.visibleWhenValues,
    this.showInList = false,
  });

  bool isVisible(Map<String, dynamic> values) {
    if (visibleWhenField == null || visibleWhenValues == null) return true;
    final current = values[visibleWhenField]?.toString();
    return visibleWhenValues!.contains(current);
  }
}

typedef RecomputeFn = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> values,
  Repository repo,
);

/// Describes a whole table: its columns, its primary key strategy,
/// and (optionally) a function that recalculates computed columns
/// whenever a dependency changes — the app-side equivalent of
/// AppSheet's virtual/computed columns.
class TableSchema {
  final String tableName;
  final String label;
  final String primaryKey;
  final bool useSequentialId; // true = numeric-looking id, false = short hex id
  final String displayField; // field used as the record's "name" everywhere
  final List<FieldDef> fields;
  final bool allowAdd; // Vente has no Add button (created only via "Vendre")
  final bool showInDrawer;
  final String iconName;
  final RecomputeFn? recompute;
  final String Function(Map<String, dynamic> record)? titleBuilder;

  const TableSchema({
    required this.tableName,
    required this.label,
    required this.primaryKey,
    required this.useSequentialId,
    required this.displayField,
    required this.fields,
    this.allowAdd = true,
    this.showInDrawer = true,
    required this.iconName,
    this.recompute,
    this.titleBuilder,
  });

  List<FieldDef> get refFields => fields.where((f) => f.type == FieldType.ref).toList();

  FieldDef? fieldByName(String name) {
    for (final f in fields) {
      if (f.name == name) return f;
    }
    return null;
  }
}
