import 'package:flutter/material.dart';
import '../models/schemas_data.dart';
import '../services/session.dart';
import '../screens/entity_form_screen.dart';
import '../screens/entity_list_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/user_management_screen.dart';

IconData iconForName(String name) {
  switch (name) {
    case 'menu_book':
      return Icons.menu_book;
    case 'liquor':
      return Icons.liquor;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'people':
      return Icons.people;
    case 'local_shipping':
      return Icons.local_shipping;
    case 'science':
      return Icons.science;
    case 'blender':
      return Icons.blender;
    case 'local_florist':
      return Icons.local_florist;
    case 'point_of_sale':
      return Icons.point_of_sale;
    case 'person':
      return Icons.person;
    case 'inventory_2':
      return Icons.inventory_2;
    default:
      return Icons.circle;
  }
}

/// Persistent left navigation, matching the 12-entry sidebar of the
/// source AppSheet app (Home, Vendre, Recette, Bouteilles, Charges,
/// Clients, Fournisseurs, Ingrédients, Mélanges, Parfums, Vente, Compte).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text('Le Flacon', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: const Text('Vendre'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntityFormScreen(schema: venteSchema)));
              },
            ),
            for (final schema in drawerSchemas)
              ListTile(
                leading: Icon(iconForName(schema.iconName)),
                title: Text(schema.label),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntityListScreen(schema: schema)));
                },
              ),
            if (Session.instance.isAdmin) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Gestion des utilisateurs'),
                subtitle: const Text('Administrateurs uniquement'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  );
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Compte'),
              subtitle: Text(Session.instance.currentUserPhone),
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Compte'),
                    content: Text('Connecté en tant que ${Session.instance.currentUserPhone}'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
                      FilledButton(
                        onPressed: () {
                          Session.instance.logout();
                          Navigator.pop(context);
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text('Déconnexion'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
