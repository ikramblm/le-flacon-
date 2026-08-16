import 'package:flutter/material.dart';
import '../models/schemas_data.dart';
import '../services/repository.dart';
import '../services/repository_scope.dart';
import '../utils/formatters.dart';

/// Reproduces the source app's "Comptabilité" screen: a date-range
/// singleton form (Date Debut select / Date Fin select, both required,
/// defaulting to today) that here also drives a small sales/expenses
/// report, since the downstream report it fed wasn't reachable from the
/// end-user account used to document the app.
class ComptabiliteScreen extends StatefulWidget {
  const ComptabiliteScreen({super.key});
  @override
  State<ComptabiliteScreen> createState() => _ComptabiliteScreenState();
}

class _ComptabiliteScreenState extends State<ComptabiliteScreen> {
  DateTime _debut = DateTime.now();
  DateTime _fin = DateTime.now();
  Future<_Report>? _future;

  Future<_Report> _generate(Repository repo) async {
    final startIso = DateTime(_debut.year, _debut.month, _debut.day).toIso8601String();
    final endIso = DateTime(_fin.year, _fin.month, _fin.day, 23, 59, 59).toIso8601String();
    final ventes = await repo.sumField(venteSchema, 'total', whereClause: 'date >= ? AND date <= ?', whereArgs: [startIso, endIso]);
    final charges = await repo.sumField(chargesSchema, 'total', whereClause: 'date >= ? AND date <= ?', whereArgs: [startIso, endIso]);
    final rows = await repo.db.rawQuery('SELECT COUNT(*) as c FROM vente WHERE date >= ? AND date <= ?', [startIso, endIso]);
    final count = (rows.first['c'] as int?) ?? 0;
    return _Report(ventes: ventes, charges: charges, nbVentes: count);
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Comptabilité')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _DateField(label: 'Date début', date: _debut, onPick: (d) => setState(() => _debut = d))),
              const SizedBox(width: 12),
              Expanded(child: _DateField(label: 'Date fin', date: _fin, onPick: (d) => setState(() => _fin = d))),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => _future = _generate(repo)),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Générer le rapport')),
          ),
          const SizedBox(height: 20),
          if (_future != null)
            FutureBuilder<_Report>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final r = snap.data!;
                return Column(
                  children: [
                    _ReportCard(label: 'Ventes (${r.nbVentes})', value: formatPrice(r.ventes), color: Colors.green),
                    const SizedBox(height: 10),
                    _ReportCard(label: 'Charges', value: formatPrice(r.charges), color: Colors.red),
                    const SizedBox(height: 10),
                    _ReportCard(label: 'Bénéfice net', value: formatPrice(r.ventes - r.charges), color: Colors.blueGrey),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Report {
  final double ventes;
  final double charges;
  final int nbVentes;
  _Report({required this.ventes, required this.charges, required this.nbVentes});
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DateField({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2015), lastDate: DateTime(2100));
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined)),
        child: Text(formatDate(date.toIso8601String())),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ReportCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(Icons.circle, color: color, size: 14)),
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
