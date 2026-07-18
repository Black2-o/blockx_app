import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_store.dart';

/// UI-ONLY account state, persisted in [AccountStore] (Hive box `account`).
/// Touches NO native code, blocking data, or network (master prompt §G): a
/// hardcoded `admin` / `admin` unlocks a static premium badge, and the signed-in
/// state is remembered across launches so the first-time gate only shows once.
/// Structured so real auth can slot in later without a visual redesign.
class AccountState {
  const AccountState({this.signedIn = false, this.username});

  final bool signedIn;
  final String? username;
}

/// Provides the opened [AccountStore]. Overridden in `main()` once Hive is ready.
final accountStoreProvider = Provider<AccountStore>((ref) {
  throw UnimplementedError('accountStoreProvider must be overridden in main()');
});

class AccountNotifier extends StateNotifier<AccountState> {
  AccountNotifier(this._store)
      : super(AccountState(
          signedIn: _store.isSignedIn,
          username: _store.username,
        ));

  final AccountStore _store;

  /// Returns true on success. Hardcoded stub credentials; persists on success.
  Future<bool> signIn(String username, String password) async {
    if (username.trim() == 'admin' && password == 'admin') {
      final name = username.trim();
      await _store.signIn(name);
      state = AccountState(signedIn: true, username: name);
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    await _store.signOut();
    state = const AccountState();
  }
}

final accountProvider =
    StateNotifierProvider<AccountNotifier, AccountState>((ref) {
  return AccountNotifier(ref.watch(accountStoreProvider));
});
