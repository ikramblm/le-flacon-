import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/schemas_data.dart';
import '../services/repository_scope.dart';
import '../services/session.dart';
import 'home_screen.dart';

/// Reproduces the source app's "Compte / Settings" login form
/// (Utilisateur + Mot de passe, both required). The reverse-engineered
/// docs flagged that field as a plain-text password layered on top of
/// Google-account access with unconfirmed enforcement; here it is at
/// least hashed (SHA-256) before being stored or compared.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  bool _createMode = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = RepositoryScope.of(context);
    final hashed = sha256.convert(utf8.encode(_passCtrl.text)).toString();
    try {
      final users = await repo.getAll(utilisateursSchema);
      final match = users.where((u) => u['utilisateur'] == _userCtrl.text).toList();
      if (_createMode) {
        if (match.isNotEmpty) {
          setState(() => _error = "Ce nom d'utilisateur existe déjà.");
          return;
        }
        final id = await repo.generateId(utilisateursSchema);
        final user = {'id': id, 'utilisateur': _userCtrl.text, 'mot_de_passe': hashed};
        await repo.insertRecord(utilisateursSchema, user);
        Session.instance.login(user);
      } else {
        if (match.isEmpty || match.first['mot_de_passe'] != hashed) {
          setState(() => _error = 'Identifiants incorrects.');
          return;
        }
        Session.instance.login(match.first);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const Icon(Icons.local_florist, size: 56, color: Color(0xFF6D2E46)),
                    const SizedBox(height: 8),
                    Text(
                      'Le Flacon',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Gestion de parfumerie', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: "Nom d'utilisateur", prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
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
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_createMode ? 'Créer le compte' : 'Se connecter'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _createMode = !_createMode),
                      child: Text(_createMode ? "J'ai déjà un compte" : 'Créer un nouveau compte utilisateur'),
                    ),
                    const SizedBox(height: 8),
                    Text('Compte par défaut : admin / admin', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
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
