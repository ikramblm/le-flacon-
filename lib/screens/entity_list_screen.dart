import 'package:flutter/material.dart';
import '../models/schema.dart';
import '../services/repository.dart';
import '../services/repository_scope.dart';
import '../utils/formatters.dart';
import '../widgets/app_drawer.dart';
import 'entity_detail_screen.dart';
import 'entity_form_screen.dart';

/// Generic list screen for any TableSchema: search box, formatted subtitle
/// built from the fields flagged showInList, and an Add FAB (hidden when
/// the schema disallows it, e.g. Vente).
class EntityListScreen extends StatefulWidget {
  final TableSchema schema;
  const EntityListScreen({super.key, required this.schema});

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  Future<List<Map<String, dynamic>>>? _future;
  String _query = '';

  void _reload() => setState(() => _future = null);

  String _titleFor(TableSchema schema, Map<String, dynamic> r) {
    if (schema.titleBuilder != null) return schema.titleBuilder!(r);
    return (r[schema.displayField] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    _future ??= repo.getEnriched(widget.schema);
    final schema = widget.schema;

    return Scaffold(
      appBar: AppBar(title: Text(schema.label)),
      drawer: const AppDrawer(),
      floatingActionButton: schema.allowAdd
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EntityFormScreen(schema: schema)),
                );
                if (result == true) _reload();
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Rechercher...', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                var rows = snap.data!;
                if (_query.isNotEmpty) {
                  rows = rows.where((r) => _titleFor(schema, r).toLowerCase().contains(_query)).toList();
                }
                if (rows.isEmpty) return const Center(child: Text('Aucun enregistrement'));
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final subtitleParts = <String>[];
                    for (final f in schema.fields.where((f) => f.showInList)) {
                      final val = f.type == FieldType.ref ? r['${f.name}_display'] : r[f.name];
                      if (val == null || val.toString().isEmpty) continue;
                      String display;
                      switch (f.type) {
                        case FieldType.price:
                          display = formatPrice(val);
                          break;
                        case FieldType.date:
                          display = formatDate(val);
                          break;
                        case FieldType.dateTime:
                          display = formatDateTime(val);
                          break;
                        case FieldType.number:
                          display = formatNumber(val);
                          break;
                        default:
                          display = val.toString();
                      }
                      subtitleParts.add('${f.label}: $display');
                    }
                    return ListTile(
                      title: Text(_titleFor(schema, r)),
                      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join('   •   ')),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EntityDetailScreen(schema: schema, id: r[schema.primaryKey].toString()),
                          ),
                        ).then((_) => _reload());
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
