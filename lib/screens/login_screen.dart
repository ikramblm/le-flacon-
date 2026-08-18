import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/schemas_data.dart';
import '../services/repository_scope.dart';
import '../services/session.dart';
import 'home_screen.dart';

/// Login and account creation using a phone number.
///
/// The first account created when there is no administrator is automatically
/// an administrator. All later accounts are normal users. Administrators can
/// create or promote additional administrators from Gestion des utilisateurs.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _createMode = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = RepositoryScope.of(context);
    final phone = _normalizePhone(_phoneCtrl.text);
    final hashed = sha256.convert(utf8.encode(_passCtrl.text)).toString();

    try {
      final users = await repo.getAll(utilisateursSchema);
      final match = users
          .where((u) => _normalizePhone(u['telephone']?.toString() ?? '') == phone)
          .toList();

      if (_createMode) {
        if (match.isNotEmpty) {
          setState(() => _error = 'Ce numéro de téléphone est déjà utilisé.');
          return;
        }

        final hasAdmin = users.any((u) => u['role']?.toString() == 'admin');
        final createAsAdmin = !hasAdmin;
        final id = await repo.generateId(utilisateursSchema);
        final user = {
          'id': id,
          'telephone': phone,
          'mot_de_passe': hashed,
          'role': createAsAdmin ? 'admin' : 'user',
        };

        await repo.insertRecord(utilisateursSchema, user);
        Session.instance.login(user);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              createAsAdmin
                  ? 'Compte administrateur créé avec succès.'
                  : 'Compte utilisateur créé avec succès.',
            ),
          ),
        );
      } else {
        if (match.isEmpty || match.first['mot_de_passe'] != hashed) {
          setState(() => _error = 'Numéro de téléphone ou mot de passe incorrect.');
          return;
        }

        final user = Map<String, dynamic>.from(match.first);
        Session.instance.login(user);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion à la base de données. Veuillez réessayer.';
        });
      }
      debugPrint('Login error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = _createMode;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.local_florist,
                      size: 56,
                      color: Color(0xFF6D2E46),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le Flacon',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestion de parfumerie',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _phoneCtrl,
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
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(isCreate ? 'Créer le compte' : 'Se connecter'),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _createMode = !_createMode;
                          _error = null;
                        });
                      },
                      child: Text(
                        isCreate
                            ? "J'ai déjà un compte"
                            : 'Créer un nouveau compte utilisateur',
                      ),
                    ),
                    if (isCreate) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Si aucun administrateur n’existe encore, ce compte '
                        'sera administrateur. Sinon, il sera utilisateur.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
