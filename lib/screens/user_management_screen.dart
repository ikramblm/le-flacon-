import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/schemas_data.dart';
import '../services/repository_scope.dart';
import '../services/session.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  String? _error;

  String _normalizePhone(String value) {
    var phone = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (phone.startsWith('+213')) {
      phone = '0${phone.substring(4)}';
    } else if (phone.startsWith('213') && phone.length == 12) {
      phone = '0${phone.substring(3)}';
    }
    return phone;
  }

  String? _validatePhone(String? value) {
    final phone = _normalizePhone(value ?? '');
    if (phone.isEmpty) return 'Numéro de téléphone requis';
    if (!RegExp(r'^0[567][0-9]{8}$').hasMatch(phone)) {
      return 'Entrez un numéro algérien valide (05/06/07XXXXXXXX)';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!Session.instance.isAdmin) {
      setState(() {
        _loading = false;
        _error = 'Accès réservé aux administrateurs.';
      });
      return;
    }

    try {
      final repo = RepositoryScope.of(context);
      final users = await repo.getAll(utilisateursSchema);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les utilisateurs.';
        _loading = false;
      });
    }
  }

  Future<void> _showUserDialog({Map<String, dynamic>? existing}) async {
    final repo = RepositoryScope.of(context);
    final isEditing = existing != null;
    final phoneCtrl = TextEditingController(
      text: existing?['telephone']?.toString() ?? '',
    );
    final passwordCtrl = TextEditingController();
    String role = existing?['role']?.toString() ?? 'user';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogFormKey = GlobalKey<FormState>();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Modifier l’utilisateur' : 'Nouvel utilisateur'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: dialogFormKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Numéro de téléphone',
                            hintText: '06 12 34 56 78',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: isEditing
                                ? 'Nouveau mot de passe (facultatif)'
                                : 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(
                            labelText: 'Rôle',
                            prefixIcon: Icon(Icons.security_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('Utilisateur'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Administrateur'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => role = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!dialogFormKey.currentState!.validate()) return;

                    final phone = _normalizePhone(phoneCtrl.text);
                    final password = passwordCtrl.text;
                    if (!isEditing && password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Le mot de passe est requis.')),
                      );
                      return;
                    }

                    final users = await repo.getAll(utilisateursSchema);
                    final duplicate = users.any(
                      (u) =>
                          _normalizePhone(u['telephone']?.toString() ?? '') == phone &&
                          u['id']?.toString() != existing?['id']?.toString(),
                    );
                    if (duplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ce numéro de téléphone est déjà utilisé.')),
                      );
                      return;
                    }

                    final data = <String, dynamic>{
                      'telephone': phone,
                      'role': role,
                    };

                    if (password.isNotEmpty) {
                      data['mot_de_passe'] =
                          sha256.convert(utf8.encode(password)).toString();
                    }

                    if (isEditing) {
                      final oldRole = existing!['role']?.toString() ?? 'user';

                      if (existing['id']?.toString() ==
                              Session.instance.currentUserId &&
                          role != 'admin') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vous ne pouvez pas retirer votre propre rôle administrateur.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (oldRole == 'admin' && role != 'admin') {
                        final adminCount =
                            users.where((u) => u['role'] == 'admin').length;
                        if (adminCount <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Impossible : il doit rester au moins un administrateur.',
                              ),
                            ),
                          );
                          return;
                        }
                      }

                      await repo.updateRecord(
                        utilisateursSchema,
                        existing['id'].toString(),
                        data,
                      );
                    } else {
                      final id = await repo.generateId(utilisateursSchema);
                      data['id'] = id;
                      data['mot_de_passe'] =
                          sha256.convert(utf8.encode(password)).toString();
                      await repo.insertRecord(utilisateursSchema, data);
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(isEditing ? 'Enregistrer' : 'Créer'),
                ),
              ],
            );
          },
        );
      },
    );

    phoneCtrl.dispose();
    passwordCtrl.dispose();

    if (result == true) await _loadUsers();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    if (id == null) return;

    if (id == Session.instance.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas supprimer votre propre compte.')),
      );
      return;
    }

    final role = user['role']?.toString() ?? 'user';
    if (role == 'admin') {
      final adminCount = _users.where((u) => u['role'] == 'admin').length;
      if (adminCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible : il doit rester au moins un administrateur.'),
          ),
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: Text(
          'Le compte avec le numéro "${user['telephone']}" sera définitivement supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = RepositoryScope.of(context);
    await repo.deleteRecord(utilisateursSchema, id);
    await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.instance.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestion des utilisateurs')),
        body: const Center(child: Text('Accès réservé aux administrateurs.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _users.isEmpty
                  ? const Center(child: Text('Aucun utilisateur enregistré.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final isAdmin = user['role'] == 'admin';
                        final isCurrent =
                            user['id']?.toString() == Session.instance.currentUserId;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.person_outline,
                            ),
                          ),
                          title: Text(user['telephone']?.toString() ?? ''),
                          subtitle: Text(isAdmin ? 'Administrateur' : 'Utilisateur'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Modifier',
                                onPressed: () => _showUserDialog(existing: user),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Supprimer',
                                onPressed:
                                    isCurrent ? null : () => _deleteUser(user),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
