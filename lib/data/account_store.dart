import 'package:hive_flutter/hive_flutter.dart';

/// UI-only persistence for the sign-in gate. Separate Hive box `account`, holds
/// just the signed-in username. This touches NONE of the blocking backend
/// (block list, sites, features, native prefs) — it only remembers whether the
/// user has completed the first-time login so we can skip it next launch.
class AccountStore {
  AccountStore(this._box);

  static const String boxName = 'account';
  static const String _usernameKey = 'username';

  final Box<String> _box;

  static Future<AccountStore> open() async {
    final box = await Hive.openBox<String>(boxName);
    return AccountStore(box);
  }

  bool get isSignedIn => _box.get(_usernameKey) != null;

  String? get username => _box.get(_usernameKey);

  Future<void> signIn(String username) => _box.put(_usernameKey, username);

  Future<void> signOut() => _box.delete(_usernameKey);
}
