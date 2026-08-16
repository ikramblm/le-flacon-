import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/database_helper.dart';
import 'services/repository.dart';
import 'services/repository_scope.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LeFlaconApp());
}

class LeFlaconApp extends StatelessWidget {
  const LeFlaconApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Flacon',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();
  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  Repository? _repo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db = await DatabaseHelper.instance.database;
    if (mounted) setState(() => _repo = Repository(db));
  }

  @override
  Widget build(BuildContext context) {
    if (_repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return RepositoryScope(repository: _repo!, child: const LoginScreen());
  }
}
