import 'package:flutter/foundation.dart';
import '../data/repositories/auth_repository.dart';

/// Session exists only in memory. Credentials are never persisted or sent.
class DemoSession extends ChangeNotifier {
  DemoSession(this.repository);
  final AuthRepository repository;
  bool _signedIn = false;
  bool get signedIn => _signedIn;

  Future<void> signIn() async {
    await repository.signInDemo();
    _signedIn = true;
    notifyListeners();
  }

  void signOut() {
    _signedIn = false;
    notifyListeners();
  }
}
