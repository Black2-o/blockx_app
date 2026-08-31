/// Which OEM skin the phone runs — drives the device-specific reliability tips.
enum DeviceOem { miui, coloros, funtouch, oneui, other }

/// Read-only device identity (from Android `Build`), used only by the Device
/// Setup screen to show the right per-manufacturer instructions.
class DeviceInfo {
  const DeviceInfo({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.sdkInt,
  });

  final String manufacturer;
  final String brand;
  final String model;
  final int sdkInt;

  factory DeviceInfo.fromMap(Map<dynamic, dynamic> map) => DeviceInfo(
        manufacturer: (map['manufacturer'] as String?) ?? '',
        brand: (map['brand'] as String?) ?? '',
        model: (map['model'] as String?) ?? '',
        sdkInt: (map['sdkInt'] as int?) ?? 0,
      );

  DeviceOem get oem {
    final s = '$manufacturer $brand'.toLowerCase();
    if (s.contains('xiaomi') || s.contains('redmi') || s.contains('poco')) {
      return DeviceOem.miui;
    }
    if (s.contains('oppo') || s.contains('realme') || s.contains('oneplus')) {
      return DeviceOem.coloros;
    }
    if (s.contains('vivo') || s.contains('iqoo')) return DeviceOem.funtouch;
    if (s.contains('samsung')) return DeviceOem.oneui;
    return DeviceOem.other;
  }

  /// Android 13+ hides Accessibility for sideloaded apps behind "Allow
  /// restricted settings".
  bool get needsRestrictedSettings => sdkInt >= 33;

  /// A friendly manufacturer name for headings ("Xiaomi", "realme"…).
  String get label {
    if (manufacturer.isEmpty) return 'your phone';
    return manufacturer[0].toUpperCase() + manufacturer.substring(1);
  }
}
