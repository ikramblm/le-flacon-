import 'package:flutter/material.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';
import '../services/repository.dart';
import '../services/repository_scope.dart';
import '../utils/formatters.dart';
import 'entity_detail_screen.dart';

/// Reproduces the source app's "Calendrier" view as a day-grouped agenda
/// of every dated Vente and Charge (a full month/week grid widget was not
/// something this environment could verify would compile, so this keeps
/// the same purpose — browsing records by date — with a date-jump and a
/// Ventes/Charges/Tout filter).
class CalendrierScreen extends StatefulWidget {
  const CalendrierScreen({super.key});
  @override
  State<CalendrierScreen> createState() => _CalendrierScreenState();
}

enum _Filter { tous, ventes, charges }

class _AgendaItem {
  final DateTime date;
  final String title;
  final String subtitle;
  final TableSchema schema;
  final String id;
  final bool isVente;
  _AgendaItem({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.schema,
    required this.id,
    required this.isVente,
  });
}

class _CalendrierScreenState extends State<CalendrierScreen> {
  Future<List<_AgendaItem>>? _future;
  _Filter _filter = _Filter.tous;
  DateTime? _selectedDay;

  Future<List<_AgendaItem>> _load(Repository repo) async {
    final items = <_AgendaItem>[];
    final ventes = await repo.getEnriched(venteSchema);
    for (final v in ventes) {
      items.add(_AgendaItem(
        date: DateTime.tryParse(v['date']?.toString() ?? '') ?? DateTime.now(),
        title: 'Vente — ${v['client_id_display'] ?? ''}',
        subtitle: formatPrice(v['total']),
        schema: venteSchema,
        id: v['id'].toString(),
        isVente: true,
      ));
    }
    final charges = await repo.getEnriched(chargesSchema);
    for (final c in charges) {
      items.add(_AgendaItem(
        date: DateTime.tryParse(c['date']?.toString() ?? '') ?? DateTime.now(),
        title: 'Charge — ${c['type_charge'] ?? ''}',
        subtitle: formatPrice(c['total']),
        schema: chargesSchema,
        id: c['id'].toString(),
        isVente: false,
      ));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    _future ??= _load(repo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_outlined),
            tooltip: 'Aller à une date',
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime(2100));
              if (picked != null) setState(() => _selectedDay = picked);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<_Filter>(
              segments: const [
                ButtonSegment(value: _Filter.tous, label: Text('Tout')),
                ButtonSegment(value: _Filter.ventes, label: Text('Ventes')),
                ButtonSegment(value: _Filter.charges, label: Text('Charges')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Filtré le ${formatDate(_selectedDay!.toIso8601String())}'),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _selectedDay = null), child: const Text('Effacer')),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<_AgendaItem>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                var items = snap.data!;
                if (_filter == _Filter.ventes) items = items.where((i) => i.isVente).toList();
                if (_filter == _Filter.charges) items = items.where((i) => !i.isVente).toList();
                if (_selectedDay != null) {
                  items = items
                      .where((i) => i.date.year == _selectedDay!.year && i.date.month == _selectedDay!.month && i.date.day == _selectedDay!.day)
                      .toList();
                }
                if (items.isEmpty) return const Center(child: Text('Aucun événement'));

                final grouped = <String, List<_AgendaItem>>{};
                for (final i in items) {
                  final key = formatDate(i.date.toIso8601String());
                  grouped.putIfAbsent(key, () => []).add(i);
                }

                return ListView(
                  children: grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        ),
                        for (final item in entry.value)
                          ListTile(
                            leading: Icon(item.isVente ? Icons.point_of_sale : Icons.receipt_long, color: item.isVente ? Colors.green : Colors.red),
                            title: Text(item.title),
                            subtitle: Text(item.subtitle),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EntityDetailScreen(schema: item.schema, id: item.id))),
                          ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
