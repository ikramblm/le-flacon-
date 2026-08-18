import '../services/repository.dart';
import '../utils/formatters.dart';
import 'schema.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// ---------------------------------------------------------------------------
// Utilisateurs — hidden/system table (login + record-owner ref elsewhere)
// ---------------------------------------------------------------------------
final TableSchema utilisateursSchema = TableSchema(
  tableName: 'utilisateurs',
  label: 'Utilisateurs',
  primaryKey: 'id',
  useSequentialId: true,
  displayField: 'telephone',
  showInDrawer: false,
  iconName: 'person',
  fields: [
    // Legacy field kept only for database migration compatibility.
    // Authentication now uses telephone exclusively.
    FieldDef(name: 'utilisateur', label: "Ancien nom d'utilisateur", type: FieldType.text, required: false, showInList: false),
    FieldDef(name: 'telephone', label: 'Téléphone', type: FieldType.phone, required: true),
    FieldDef(name: 'mot_de_passe', label: 'Mot de passe', type: FieldType.text, required: true, showInList: false),
    FieldDef(
      name: 'role',
      label: 'Rôle',
      type: FieldType.enumType,
      required: true,
      enumValues: ['admin', 'user'],
    ),
  ],
);

// ---------------------------------------------------------------------------
// Clients
// ---------------------------------------------------------------------------
final TableSchema clientsSchema = TableSchema(
  tableName: 'clients',
  label: 'Clients',
  primaryKey: 'id',
  useSequentialId: false,
  displayField: 'nom',
  iconName: 'people',
  fields: [
    FieldDef(name: 'nom', label: 'Nom', type: FieldType.text, required: true),
    FieldDef(name: 'telephone', label: 'Téléphone', type: FieldType.phone, showInList: true),
    FieldDef(name: 'email', label: 'Email', type: FieldType.email, showInList: true),
  ],
);

// ---------------------------------------------------------------------------
// Fournisseurs
// ---------------------------------------------------------------------------
final TableSchema fournisseursSchema = TableSchema(
  tableName: 'fournisseurs',
  label: 'Fournisseurs',
  primaryKey: 'id',
  useSequentialId: true,
  displayField: 'nom',
  iconName: 'local_shipping',
  fields: [
    FieldDef(name: 'nom', label: 'Nom', type: FieldType.text, required: true),
    FieldDef(name: 'telephone', label: 'Téléphone', type: FieldType.phone, showInList: true),
    FieldDef(name: 'produits', label: 'Produits fournis', type: FieldType.text, multiline: true, showInList: true),
  ],
);

// ---------------------------------------------------------------------------
// Ingrédients
// ---------------------------------------------------------------------------
final TableSchema ingredientsSchema = TableSchema(
  tableName: 'ingredients',
  label: 'Ingrédients',
  primaryKey: 'id',
  useSequentialId: true,
  displayField: 'nom',
  iconName: 'science',
  fields: [
    FieldDef(name: 'nom', label: 'Nom', type: FieldType.text, required: true),
    FieldDef(name: 'prix_achat', label: "Prix d'achat", type: FieldType.price, showInList: true),
    FieldDef(name: 'prix_vente', label: 'Prix de vente', type: FieldType.price, showInList: true),
  ],
);

// ---------------------------------------------------------------------------
// Parfums (internal table name in the source app: "Produits")
// ---------------------------------------------------------------------------
final TableSchema parfumsSchema = TableSchema(
  tableName: 'parfums',
  label: 'Parfums',
  primaryKey: 'id',
  useSequentialId: true,
  displayField: 'nom',
  iconName: 'local_florist',
  fields: [
    FieldDef(name: 'nom', label: 'Nom', type: FieldType.text, required: true),
    FieldDef(name: 'marque', label: 'Marque', type: FieldType.text, showInList: true),
    FieldDef(name: 'prix_achat_ml', label: "Prix d'achat / ml", type: FieldType.price),
    FieldDef(name: 'prix_vente_ml', label: 'Prix de vente / ml', type: FieldType.price, showInList: true),
    FieldDef(name: 'utilisateur_id', label: 'Utilisateur', type: FieldType.ref, refTable: 'utilisateurs'),
  ],
);

// ---------------------------------------------------------------------------
// Bouteilles
// ---------------------------------------------------------------------------
final TableSchema bouteillesSchema = TableSchema(
  tableName: 'bouteilles',
  label: 'Bouteilles',
  primaryKey: 'id',
  useSequentialId: true,
  displayField: 'nom',
  iconName: 'liquor',
  fields: [
    FieldDef(name: 'nom', label: 'Nom', type: FieldType.text, required: true),
    FieldDef(name: 'capacite', label: 'Capacité (ml)', type: FieldType.number, showInList: true),
    FieldDef(name: 'prix_achat', label: "Prix d'achat", type: FieldType.price),
    FieldDef(name: 'prix_vente', label: 'Prix de vente', type: FieldType.price, showInList: true),
    FieldDef(name: 'couleur', label: 'Couleur', type: FieldType.text),
    FieldDef(name: 'utilisateur_id', label: 'Utilisateur', type: FieldType.ref, refTable: 'utilisateurs'),
  ],
);

// ---------------------------------------------------------------------------
// Recette — computed prix_total_achat / prix_total_vente
// ---------------------------------------------------------------------------
final TableSchema recetteSchema = TableSchema(
  tableName: 'recette',
  label: 'Recette',
  primaryKey: 'id',
  useSequentialId: true,
  displayField: 'nom_recette',
  iconName: 'menu_book',
  fields: [
    FieldDef(name: 'nom_recette', label: 'Nom de la recette', type: FieldType.text, required: true),
    FieldDef(name: 'dose', label: 'Dose', type: FieldType.number),
    FieldDef(name: 'volume_total', label: 'Volume total (ml)', type: FieldType.number, showInList: true),
    FieldDef(name: 'produit_id', label: 'Produit (parfum)', type: FieldType.ref, refTable: 'parfums', required: true),
    FieldDef(name: 'ml_extrait', label: "ml d'extrait", type: FieldType.number),
    FieldDef(name: 'alcool_id', label: 'Alcool', type: FieldType.ref, refTable: 'ingredients'),
    FieldDef(name: 'ml_alcool', label: "ml d'alcool", type: FieldType.number),
    FieldDef(name: 'fixateur_id', label: 'Fixateur', type: FieldType.ref, refTable: 'ingredients'),
    FieldDef(name: 'ml_fixateur', label: 'ml de fixateur', type: FieldType.number),
    FieldDef(name: 'prix_total_achat', label: "Prix total d'achat", type: FieldType.price, readOnly: true),
    FieldDef(name: 'prix_total_vente', label: 'Prix total de vente', type: FieldType.price, readOnly: true, showInList: true),
    FieldDef(name: 'image', label: 'Image', type: FieldType.photo),
    FieldDef(name: 'utilisateur_id', label: 'Utilisateur', type: FieldType.ref, refTable: 'utilisateurs'),
  ],
  recompute: (values, repo) async {
    final res = await repo.computeRecettePrices(
      produitId: values['produit_id'] as String?,
      mlExtrait: _toDouble(values['ml_extrait']),
      alcoolId: values['alcool_id'] as String?,
      mlAlcool: _toDouble(values['ml_alcool']),
      fixateurId: values['fixateur_id'] as String?,
      mlFixateur: _toDouble(values['ml_fixateur']),
    );
    return {
      'prix_total_achat': res['achat'],
      'prix_total_vente': res['vente'],
    };
  },
);

// ---------------------------------------------------------------------------
// Mélanges — computed prix_total
// ---------------------------------------------------------------------------
final TableSchema melangesSchema = TableSchema(
  tableName: 'melanges',
  label: 'Mélanges',
  primaryKey: 'id',
  useSequentialId: false,
  displayField: 'nom_melange',
  iconName: 'blender',
  fields: [
    FieldDef(name: 'nom_melange', label: 'Nom du mélange', type: FieldType.text, required: true),
    FieldDef(name: 'volume_total', label: 'Volume total (ml)', type: FieldType.number, showInList: true),
    FieldDef(name: 'extrait1_id', label: 'Extrait 1', type: FieldType.ref, refTable: 'parfums', required: true),
    FieldDef(name: 'ml_extrait1', label: 'ml extrait 1', type: FieldType.number),
    FieldDef(name: 'extrait2_id', label: 'Extrait 2', type: FieldType.ref, refTable: 'parfums'),
    FieldDef(name: 'ml_extrait2', label: 'ml extrait 2', type: FieldType.number),
    FieldDef(name: 'ingredient_id', label: 'Ingrédient', type: FieldType.ref, refTable: 'ingredients'),
    FieldDef(name: 'ml_ingredient', label: 'ml ingrédient', type: FieldType.number),
    FieldDef(name: 'description_courte', label: 'Description courte', type: FieldType.text, multiline: true),
    FieldDef(name: 'prix_total', label: 'Prix total', type: FieldType.price, readOnly: true, showInList: true),
  ],
  recompute: (values, repo) async {
    final total = await repo.computeMelangePrice(
      extrait1Id: values['extrait1_id'] as String?,
      mlExtrait1: _toDouble(values['ml_extrait1']),
      extrait2Id: values['extrait2_id'] as String?,
      mlExtrait2: _toDouble(values['ml_extrait2']),
      ingredientId: values['ingredient_id'] as String?,
      mlIngredient: _toDouble(values['ml_ingredient']),
    );
    return {'prix_total': total};
  },
);

// ---------------------------------------------------------------------------
// Vente — no Add button (created only through the "Vendre" quick form);
// Capacité bouteille / Volume Recette are looked up from the chosen refs.
// ---------------------------------------------------------------------------
final TableSchema venteSchema = TableSchema(
  tableName: 'vente',
  label: 'Vente',
  primaryKey: 'id',
  useSequentialId: false,
  displayField: 'id',
  allowAdd: false,
  iconName: 'point_of_sale',
  titleBuilder: (r) => 'Vente ${r['id']}',
  fields: [
    FieldDef(name: 'client_id', label: 'Client', type: FieldType.ref, refTable: 'clients', required: true, showInList: true),
    FieldDef(
      name: 'type_produit',
      label: 'Type de produit',
      type: FieldType.enumType,
      required: true,
      enumValues: ['Recette simple', 'Mélange personnalisé'],
    ),
    FieldDef(
      name: 'recette_id',
      label: 'Recette',
      type: FieldType.ref,
      refTable: 'recette',
      visibleWhenField: 'type_produit',
      visibleWhenValues: ['Recette simple'],
    ),
    FieldDef(
      name: 'melange_id',
      label: 'Mélange',
      type: FieldType.ref,
      refTable: 'melanges',
      visibleWhenField: 'type_produit',
      visibleWhenValues: ['Mélange personnalisé'],
    ),
    FieldDef(name: 'volume_recette', label: 'Volume (ml)', type: FieldType.number, readOnly: true),
    FieldDef(name: 'bouteille_id', label: 'Bouteille', type: FieldType.ref, refTable: 'bouteilles', required: true),
    FieldDef(name: 'capacite_bouteille', label: 'Capacité bouteille (ml)', type: FieldType.number, readOnly: true),
    FieldDef(name: 'date', label: 'Date', type: FieldType.dateTime, showInList: true),
    FieldDef(name: 'total', label: 'Total', type: FieldType.price, showInList: true),
    FieldDef(name: 'image', label: 'Image', type: FieldType.photo),
    FieldDef(name: 'utilisateur_id', label: 'Utilisateur', type: FieldType.ref, refTable: 'utilisateurs'),
  ],
  recompute: (values, repo) async {
    final updates = <String, dynamic>{};
    final bouteilleId = values['bouteille_id'] as String?;
    if (bouteilleId != null && bouteilleId.isNotEmpty) {
      final b = await repo.getById(bouteillesSchema, bouteilleId);
      updates['capacite_bouteille'] = _toDouble(b?['capacite']);
    }
    final type = values['type_produit'];
    if (type == 'Recette simple') {
      final rid = values['recette_id'] as String?;
      if (rid != null && rid.isNotEmpty) {
        final r = await repo.getById(recetteSchema, rid);
        updates['volume_recette'] = _toDouble(r?['volume_total']);
      }
    } else if (type == 'Mélange personnalisé') {
      final mid = values['melange_id'] as String?;
      if (mid != null && mid.isNotEmpty) {
        final m = await repo.getById(melangesSchema, mid);
        updates['volume_recette'] = _toDouble(m?['volume_total']);
      }
    }
    return updates;
  },
);

// ---------------------------------------------------------------------------
// Charges — Total is always Quantité × Coût (verified against source data)
// ---------------------------------------------------------------------------
final TableSchema chargesSchema = TableSchema(
  tableName: 'charges',
  label: 'Charges',
  primaryKey: 'id',
  useSequentialId: false,
  displayField: 'id',
  iconName: 'receipt_long',
  titleBuilder: (r) => (r['type_charge'] ?? 'Charge').toString(),
  fields: [
    FieldDef(
      name: 'type_charge',
      label: 'Type de charge',
      type: FieldType.enumType,
      required: true,
      enumValues: ['Parfum', 'Ingrédient', 'Bouteilles', 'Paiement Salaire', 'Autre'],
    ),
    FieldDef(
      name: 'bouteille_id',
      label: 'Bouteille',
      type: FieldType.ref,
      refTable: 'bouteilles',
      visibleWhenField: 'type_charge',
      visibleWhenValues: ['Bouteilles'],
    ),
    FieldDef(
      name: 'parfum_id',
      label: 'Parfum',
      type: FieldType.ref,
      refTable: 'parfums',
      visibleWhenField: 'type_charge',
      visibleWhenValues: ['Parfum'],
    ),
    FieldDef(
      name: 'ingredient_id',
      label: 'Ingrédient',
      type: FieldType.ref,
      refTable: 'ingredients',
      visibleWhenField: 'type_charge',
      visibleWhenValues: ['Ingrédient'],
    ),
    FieldDef(name: 'fournisseur_id', label: 'Fournisseur', type: FieldType.ref, refTable: 'fournisseurs', showInList: true),
    FieldDef(name: 'quantite', label: 'Quantité', type: FieldType.number, required: true),
    FieldDef(name: 'cout', label: 'Coût unitaire', type: FieldType.price, required: true),
    FieldDef(name: 'total', label: 'Total', type: FieldType.price, readOnly: true, showInList: true),
    FieldDef(name: 'date', label: 'Date', type: FieldType.dateTime, showInList: true),
    FieldDef(name: 'photo', label: 'Photo', type: FieldType.photo),
    FieldDef(name: 'utilisateur_id', label: 'Utilisateur', type: FieldType.ref, refTable: 'utilisateurs'),
  ],
  recompute: (values, repo) async {
    final total = _toDouble(values['quantite']) * _toDouble(values['cout']);
    return {'total': total};
  },
);

// ---------------------------------------------------------------------------
// Inventaires — table existed with no data and no dedicated screen in the
// source app, so this structure is inferred (bottle/ingredient + quantity).
// Not shown in the drawer; reachable only from Bouteille / Ingrédient detail.
// ---------------------------------------------------------------------------
final TableSchema inventairesSchema = TableSchema(
  tableName: 'inventaires',
  label: 'Inventaires',
  primaryKey: 'id',
  useSequentialId: false,
  displayField: 'id',
  showInDrawer: false,
  iconName: 'inventory_2',
  titleBuilder: (r) => 'Inventaire — ${formatDate(r['date'])}',
  fields: [
    FieldDef(name: 'bouteille_id', label: 'Bouteille', type: FieldType.ref, refTable: 'bouteilles'),
    FieldDef(name: 'ingredient_id', label: 'Ingrédient', type: FieldType.ref, refTable: 'ingredients'),
    FieldDef(name: 'quantite', label: 'Quantité en stock', type: FieldType.number, showInList: true),
    FieldDef(name: 'date', label: 'Date', type: FieldType.dateTime, showInList: true),
  ],
);

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------
final Map<String, TableSchema> allSchemas = {
  'utilisateurs': utilisateursSchema,
  'clients': clientsSchema,
  'fournisseurs': fournisseursSchema,
  'ingredients': ingredientsSchema,
  'parfums': parfumsSchema,
  'bouteilles': bouteillesSchema,
  'recette': recetteSchema,
  'melanges': melangesSchema,
  'vente': venteSchema,
  'charges': chargesSchema,
  'inventaires': inventairesSchema,
};

TableSchema? allSchemasOf(String name) => allSchemas[name];

/// Matches the 12-entry left sidebar of the source app (minus Home,
/// Vendre and Compte, which are wired directly in the drawer widget).
final List<TableSchema> drawerSchemas = [
  recetteSchema,
  bouteillesSchema,
  chargesSchema,
  clientsSchema,
  fournisseursSchema,
  ingredientsSchema,
  melangesSchema,
  parfumsSchema,
  venteSchema,
];

/// For a given parent table, finds every other table that references it
/// (used to render "related records" sections on detail screens, the
/// same way AppSheet shows reverse relationships).
List<MapEntry<TableSchema, FieldDef>> reverseRelationsFor(TableSchema parent) {
  final result = <MapEntry<TableSchema, FieldDef>>[];
  for (final schema in allSchemas.values) {
    for (final f in schema.refFields) {
      if (f.refTable == parent.tableName) {
        result.add(MapEntry(schema, f));
      }
    }
  }
  return result;
}
