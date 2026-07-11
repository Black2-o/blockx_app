# Tech Stack & Packages

## Flutter side (`pubspec.yaml`)

| Purpose | Package | Notes |
|---|---|---|
| Installed apps list + icons | `device_apps` | For the Tier 1 app picker |
| Usage stats (supplementary/stats screen only) | `usage_stats` | Not the primary detection mechanism — Accessibility events are; this is for optional history/analytics later |
| Local persistence (Flutter-side cache/UI copy) | `sqflite` or `hive` | Per architecture doc, native is source of truth; this is read-mostly cache |
| Runtime permission requests | `permission_handler` | Covers standard perms; Accessibility enablement itself still requires manual deep-link to Settings, no API grants it silently |
| Foreground service / isolate coordination helper | `flutter_foreground_task` | Optional — may reduce native boilerplate for the timer service; evaluate once Tier 1 is working, don't block on it |
| Stats/usage charts (later) | `fl_chart` | v2 scope, not required for MVP |
| Fonts | bundle `Bebas Neue` + `Barlow Condensed` as local assets in `pubspec.yaml` (`fonts:` section) | Avoids `google_fonts` package's network fetch on first run — better for an app that's meant to work offline/reliably |
| MethodChannel/EventChannel | built into Flutter SDK, no package needed | `services.dart` |

## Native Android side (Gradle deps, `android/app/build.gradle`)

| Purpose | Dependency |
|---|---|
| DNS packet parsing/building | `dnsjava` (plain Java lib, e.g. `dnsjava:dnsjava:3.x`) |
| Everything else (Accessibility, Overlay, VpnService, Foreground Service) | Android SDK only, no third-party lib needed |

## Manifest permissions (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
    tools:ignore="ProtectedPermissions" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<service android:name=".accessibility.BlockAccessibilityService"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
    android:exported="false">
    <intent-filter><action android:name="android.accessibilityservice.AccessibilityService" /></intent-filter>
    <meta-data android:name="android.accessibilityservice"
        android:resource="@xml/accessibility_service_config" />
</service>

<service android:name=".vpn.DomainVpnService"
    android:permission="android.permission.BIND_VPN_SERVICE"
    android:exported="false">
    <intent-filter><action android:name="android.net.VpnService" /></intent-filter>
</service>

<service android:name=".timer.TimerForegroundService"
    android:foregroundServiceType="specialUse"
    android:exported="false" />

<receiver android:name=".BootReceiver" android:exported="false">
    <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED" /></intent-filter>
</receiver>
```

`PACKAGE_USAGE_STATS` is a special permission — still needs the user to
manually enable it via `Settings.ACTION_USAGE_ACCESS_SETTINGS`, same
deep-link pattern as Accessibility. Only needed if you build the optional
`usage_stats`-based stats screen; not required for core blocking.

## Battery optimization
Not a manifest permission — request via:
```kotlin
val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
intent.data = Uri.parse("package:$packageName")
startActivity(intent)
```
Flag in onboarding as a required step, especially since MIUI/ColorOS/other
Bangladesh-common OEM skins aggressively kill background services otherwise.

## Dev tooling (not app dependencies, but needed during development)
- **`uiautomatorviewer`** (ships with Android SDK command-line tools) or
  Android Studio's **Layout Inspector** — for discovering Reels/Shorts
  resource-ids per Tier 2 spec.
- **`adb`** — for sideloading builds to your device without Play Store, and
  for `adb shell dumpsys accessibility` style debugging of the Accessibility
  service if events aren't firing as expected.
