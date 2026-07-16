/// A single installed application on the device.
///
/// Deliberately tiny: just what the UI needs to show a row in the app picker
/// and to look up a human-readable name for a stored package on the home
/// screen. The persisted block list only ever stores [packageName]; the label
/// is looked up from the live installed-apps list.
class AppInfo {
  const AppInfo({required this.packageName, required this.appName});

  final String packageName;
  final String appName;

  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppInfo(
      packageName: (map['packageName'] ?? '') as String,
      appName: (map['appName'] ?? '') as String,
    );
  }
}
