import 'package:hive_flutter/hive_flutter.dart';

/// Persistence for blocked website hosts: one Hive box `blocked_sites`, one
/// entry per normalized domain (key == value == e.g. "youtube.com").
///
/// Kept separate from the app block list ([BlockStore]) because websites are a
/// plain set of domains, not per-package [BlockConfig]s.
class SiteStore {
  SiteStore(this._box);

  static const String boxName = 'blocked_sites';

  final Box<String> _box;

  /// Opens (or creates) the blocked-sites box.
  static Future<SiteStore> open() async {
    final box = await Hive.openBox<String>(boxName);
    return SiteStore(box);
  }

  /// All blocked domains, sorted.
  List<String> readAll() => _box.values.toList()..sort();

  /// Adds (or replaces) a domain.
  Future<void> add(String domain) => _box.put(domain, domain);

  /// Removes a domain.
  Future<void> remove(String domain) => _box.delete(domain);
}
