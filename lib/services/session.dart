import 'package:flutter/foundation.dart';

/// In-memory session (resets on app restart — there is no persistent
/// token store, matching the scope of this rebuild).
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  Map<String, dynamic>? currentUser;

  void login(Map<String, dynamic> user) {
    currentUser = user;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  String? get currentUserId => currentUser?['id']?.toString();
  String get currentUserName => currentUser?['utilisateur']?.toString() ?? '';
}
