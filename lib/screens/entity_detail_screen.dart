import 'dart:io';
import 'package:flutter/material.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';
import '../services/repository.dart';
import '../services/repository_scope.dart';
import '../utils/formatters.dart';
import '../utils/launchers.dart';
import 'entity_form_screen.dart';

/// Generic detail screen: shows every field of the record, then a
/// "related records" section per reverse relationship (e.g. a Client's
/// related Ventes, a Bouteille's related Charges), each with inline Add —
/// mirroring the source app's detail views.
class EntityDetailScreen extends StatefulWidget {
  final TableSchema schema;
  final String id;
  const EntityDetailScreen({super.key, required this.schema, required this.id});

  @override
  State<EntityDetailScreen> createState() => _EntityDetailScreenState();
}

class _EntityDetailScreenState extends State<EntityDetailScreen> {
  Future<Map<String, dynamic>?>? _future;

  void _reload() => setState(() => _future = null);

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    _future ??= repo.getById(widget.schema, widget.id);
    final schema = widget.schema;

    return Scaffold(
      appBar: AppBar(
        title: Text(schema.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final rec = await _future;
              if (rec == null) return;
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EntityFormScreen(schema: schema, existing: rec)),
              );
              if (result == true) _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Supprimer'),
                  content: const Text('Confirmer la suppression de cet enregistrement ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                  ],
                ),
              );
              if (confirm == true) {
                await repo.deleteRecord(schema, widget.id);
                if (mounted) Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final record = snap.data;
          if (record == null) return const Center(child: Text('Enregistrement introuvable'));
          final relations = reverseRelationsFor(schema);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                schema.titleBuilder != null ? schema.titleBuilder!(record) : (record[schema.displayField] ?? '').toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final f in schema.fields) _FieldRow(field: f, record: record)],
                  ),
                ),
              ),
              if (relations.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Éléments liés', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final rel in relations)
                  _RelatedSection(childSchema: rel.key, refField: rel.value, parentId: widget.id, onChanged: _reload),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final FieldDef field;
  final Map<String, dynamic> record;
  const _FieldRow({required this.field, required this.record});

  @override
  Widget build(BuildContext context) {
    final raw = record[field.name];
    if (raw == null || raw.toString().isEmpty) return const SizedBox.shrink();

    if (field.type == FieldType.photo) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(raw.toString()), height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      );
    }

    String display;
    switch (field.type) {
      case FieldType.price:
        display = formatPrice(raw);
        break;
      case FieldType.number:
        display = formatNumber(raw);
        break;
      case FieldType.date:
        display = formatDate(raw);
        break;
      case FieldType.dateTime:
        display = formatDateTime(raw);
        break;
      case FieldType.ref:
        display = (record['${field.name}_display'] ?? raw).toString();
        break;
      default:
        display = raw.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(field.label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(display, style: const TextStyle(fontWeight: FontWeight.w500))),
          if (field.type == FieldType.phone) ...[
            IconButton(icon: const Icon(Icons.call_outlined, size: 20), onPressed: () => launchPhoneCall(raw.toString())),
            IconButton(icon: const Icon(Icons.sms_outlined, size: 20), onPressed: () => launchSmsMessage(raw.toString())),
          ],
          if (field.type == FieldType.email)
            IconButton(icon: const Icon(Icons.email_outlined, size: 20), onPressed: () => launchEmailCompose(raw.toString())),
        ],
      ),
    );
  }
}

class _RelatedSection extends StatefulWidget {
  final TableSchema childSchema;
  final FieldDef refField;
  final String parentId;
  final VoidCallback onChanged;
  const _RelatedSection({required this.childSchema, required this.refField, required this.parentId, required this.onChanged});

  @override
  State<_RelatedSection> createState() => _RelatedSectionState();
}

class _RelatedSectionState extends State<_RelatedSection> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    _future ??= repo.getRelated(widget.childSchema, widget.refField.name, widget.parentId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snap) {
                      final count = snap.data?.length ?? 0;
                      return Text('${widget.childSchema.label} ($count)', style: const TextStyle(fontWeight: FontWeight.bold));
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EntityFormScreen(
                          schema: widget.childSchema,
                          presetValues: {widget.refField.name: widget.parentId},
                        ),
                      ),
                    );
                    if (result == true) {
                      setState(() => _future = null);
                      widget.onChanged();
                    }
                  },
                ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Aucun élément', style: TextStyle(color: Colors.black45)),
                  );
                }
                return Column(
                  children: rows.map((r) {
                    final title = widget.childSchema.titleBuilder != null
                        ? widget.childSchema.titleBuilder!(r)
                        : (r[widget.childSchema.displayField] ?? '').toString();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EntityDetailScreen(schema: widget.childSchema, id: r[widget.childSchema.primaryKey].toString()),
                          ),
                        ).then((_) {
                          setState(() => _future = null);
                          widget.onChanged();
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
