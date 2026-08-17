import 'package:flutter/material.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';
import '../services/repository.dart';
import '../services/repository_scope.dart';
import '../widgets/app_drawer.dart';
import 'calendrier_screen.dart';
import 'comptabilite_screen.dart';
import 'entity_form_screen.dart';
import 'entity_list_screen.dart';

/// Dashboard of tiles linking out to every other view, matching the
/// source app's Home screen (a gallery of tiles), plus a header quick
/// action to add a Charge and a few running totals.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_Stats>? _statsFuture;

  Future<_Stats> _loadStats(Repository repo) async {
    final clients = await repo.getAll(clientsSchema);
    final ventes = await repo.getAll(venteSchema);
    final total = await repo.sumField(venteSchema, 'total');
    return _Stats(clients: clients.length, ventes: ventes.length, total: total);
  }

  void _refresh() => setState(() => _statsFuture = null);

  void _openList(BuildContext context, TableSchema schema) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EntityListScreen(schema: schema))).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    _statsFuture ??= _loadStats(repo);

    final tiles = <_Tile>[
      _Tile(
        'Vendre',
        Icons.sell,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => EntityFormScreen(schema: venteSchema)))
            .then((_) => _refresh()),
      ),
      _Tile('Recette', Icons.menu_book, () => _openList(context, recetteSchema)),
      _Tile('Bouteilles', Icons.liquor, () => _openList(context, bouteillesSchema)),
      _Tile('Charges', Icons.receipt_long, () => _openList(context, chargesSchema)),
      _Tile('Clients', Icons.people, () => _openList(context, clientsSchema)),
      _Tile('Fournisseurs', Icons.local_shipping, () => _openList(context, fournisseursSchema)),
      _Tile('Ingrédients', Icons.science, () => _openList(context, ingredientsSchema)),
      _Tile('Mélanges', Icons.blender, () => _openList(context, melangesSchema)),
      _Tile('Parfums', Icons.local_florist, () => _openList(context, parfumsSchema)),
      _Tile('Vente', Icons.point_of_sale, () => _openList(context, venteSchema)),
      _Tile(
        'Comptabilité',
        Icons.calculate_outlined,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComptabiliteScreen())),
      ),
      _Tile(
        'Calendrier',
        Icons.calendar_month_outlined,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendrierScreen())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Le Flacon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: 'Ajouter une charge',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>  EntityFormScreen(schema: chargesSchema)))
                .then((_) => _refresh()),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<_Stats>(
              future: _statsFuture,
              builder: (context, snap) {
                final s = snap.data;
                return Row(
                  children: [
                    Expanded(child: _StatCard(label: 'Clients', value: s == null ? '—' : '${s.clients}')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(label: 'Ventes', value: s == null ? '—' : '${s.ventes}')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(label: "Chiffre d'affaires", value: s == null ? '—' : '${s.total.toStringAsFixed(0)} DA')),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: tiles.map((t) => _TileCard(tile: t)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats {
  final int clients;
  final int ventes;
  final double total;
  _Stats({required this.clients, required this.ventes, required this.total});
}

class _Tile {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _Tile(this.label, this.icon, this.onTap);
}

class _TileCard extends StatelessWidget {
  final _Tile tile;
  const _TileCard({required this.tile});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: tile.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tile.icon, size: 30, color: color),
              const SizedBox(height: 8),
              Text(tile.label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
