
// android/app/build.gradle.kts

import java.util.Properties
import java.io.File
import org.gradle.api.tasks.Copy

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle plugin must be applied AFTER Android & Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
    // Apply Google Services at the module level (after Android & Kotlin)
    id("com.google.gms.google-services")
}

// Read Flutter-generated properties for versioning
val localProperties = Properties().apply {
    val file = File(rootProject.projectDir, "local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

val flutterVersionCode = (localProperties.getProperty("flutter.versionCode") ?: "1").toInt()
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

// Kotlin DSL at top-level (outside android { ... })
kotlin {
    // Ensure Kotlin uses JDK 17 toolchain (AGP 8.13 expects JDK 17)
    jvmToolchain(17)
    // Align Kotlin bytecode target with Java 17
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "org.ialfm.prayertimes"

    // AGP 8.13 supports API 36; use the latest for builds
    compileSdk = 36

    defaultConfig {
        applicationId = "org.ialfm.prayertimes"
        // Flutter plugin exports minSdkVersion; typically 21 for most templates
        minSdk = flutter.minSdkVersion
        // Target the latest available to align with modern behavior & Play requirements
        targetSdk = 36

        versionCode = flutterVersionCode
        versionName = flutterVersionName

        // Optional: restrict locales to reduce size
        resConfigs("en", "ar")
    }

    // JDK 17 toolchain for source/target compatibility
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // signingConfig = signingConfigs.release // when you add a release keystore
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// --- Dependencies ---
// Keep native Firebase dependencies ONLY if you use Android Firebase APIs directly in Kotlin/Java.
// If all Firebase is via FlutterFire (Dart), you can remove this block.
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))
    implementation("com.google.firebase:firebase-analytics")
    // Add others if you call them natively:
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
    // implementation("com.google.firebase:firebase-messaging")
    // implementation("com.google.firebase:firebase-storage")
}

/**
 * ---------------------------------------------------------------------------
 * Mirror AGP's debug APK to Flutter’s expected path (project-root/build/...).
 * Flutter looks for: <root>/build/app/outputs/flutter-apk/app-debug.apk
 * AGP writes to:     android/app/build/outputs/apk/debug/app-debug.apk
 * ---------------------------------------------------------------------------
 */
val copyDebugApkToFlutter by tasks.registering(Copy::class) {
    // Source: AGP output (this app module)
    from(layout.projectDirectory.file("build/outputs/apk/debug/app-debug.apk"))

    // Destination: **project root** build folder (note the two-level ..)
    into(layout.projectDirectory.dir("../../build/app/outputs/flutter-apk"))

    // Ensure destination filename is exactly what Flutter expects
    rename { _ -> "app-debug.apk" }

    // Create destination directory if missing
    doFirst {
        layout.projectDirectory.dir("../../build/app/outputs/flutter-apk").asFile.mkdirs()
    }
}

/**
 * Attach the copy task only if `assembleDebug` exists.
 * Using `afterEvaluate` avoids failures when the task isn't registered yet.
 */
afterEvaluate {
    tasks.findByName("assembleDebug")?.let { assemble ->
        assemble.finalizedBy(copyDebugApkToFlutter)
    }
}