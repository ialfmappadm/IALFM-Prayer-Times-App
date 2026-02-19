
// android/settings.gradle.kts

pluginManagement {
    // Discover Flutter SDK via local.properties
    val flutterSdkPath: String = run {
        val props = java.util.Properties()
        file("local.properties").inputStream().use { props.load(it) }
        val p = props.getProperty("flutter.sdk")
        require(!p.isNullOrBlank()) { "flutter.sdk not set in local.properties" }
        p
    }
    // Flutter plugin loader (required for Plugin DSL)
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// ---- Plugin versions (Plugin DSL) ----
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0" // required by Flutter; keep at 1.0.0
    id("com.android.application") version "8.13.2" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
    id("com.google.firebase.crashlytics") version "2.9.9" apply false
}

include(":app")