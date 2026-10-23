import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties when present (kept out of
// git — see android/.gitignore). Without it we fall back to the debug key so
// local builds still work. See details/RELEASE.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun getInstalledNdkVersion(): String {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        val properties = Properties()
        localPropertiesFile.inputStream().use { properties.load(it) }
        val sdkDir = properties.getProperty("sdk.dir")
        if (sdkDir != null) {
            val ndkDir = File(sdkDir, "ndk")
            if (ndkDir.exists() && ndkDir.isDirectory) {
                val installed = ndkDir.listFiles()
                    ?.filter { it.isDirectory }
                    ?.map { it.name }
                    ?.sortedDescending()
                if (!installed.isNullOrEmpty()) {
                    return installed.first()
                }
            }
        }
    }
    return flutter.ndkVersion
}

android {
    namespace = "com.example.blockx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = getInstalledNdkVersion()

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Personal sideloaded build — no real domain needed.
        applicationId = "com.blockx.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real release key when key.properties exists; otherwise fall
            // back to the debug key so builds still work (NOT for distribution).
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
