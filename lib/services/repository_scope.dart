import 'package:flutter/widgets.dart';
import 'repository.dart';

/// Makes the single shared Repository instance available anywhere below
/// it in the widget tree via RepositoryScope.of(context).
class RepositoryScope extends InheritedWidget {
  final Repository repository;
  const RepositoryScope({super.key, required this.repository, required super.child});

  static Repository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'No RepositoryScope found in context');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) => oldWidget.repository != repository;
}
