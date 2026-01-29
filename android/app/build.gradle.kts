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
    // Ensure Kotlin uses JDK 17 toolchain (AGP 8.x expects JDK 17)
    jvmToolchain(17)
    // Align Kotlin bytecode target with Java 17
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "org.ialfm.prayertimes"

    // AGP 8.x supports API 36; use the latest for builds
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

        // ✅ Required by flutter_local_notifications and other Java 8+ APIs on older Android
        isCoreLibraryDesugaringEnabled = true
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        // Profile inherits debug’s proguard/shrink settings by default (Flutter injects profile)
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
    implementation("com.google.android.material:material:1.13.0") // Material 3 dependency

    // ✅ Add the desugar runtime for core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Add others if you call them natively:
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
    // implementation("com.google.firebase:firebase-messaging")
    // implementation("com.google.firebase:firebase-storage")
}

/* ---------------------------------------------------------------------------
   Copy tasks that mirror AGP outputs to the paths Flutter expects.
   Works across AGP 7/8 (no Variant API required).
   --------------------------------------------------------------------------- */

// DEBUG → <root>/build/app/outputs/flutter-apk/app-debug.apk
val copyDebugApkToFlutter by tasks.registering(Copy::class) {
    val src = layout.projectDirectory.file("build/outputs/apk/debug/app-debug.apk").asFile
    onlyIf { src.exists() }
    from(src)
    into(layout.projectDirectory.dir("../../build/app/outputs/flutter-apk"))
    rename { _ -> "app-debug.apk" }
    doFirst {
        layout.projectDirectory.dir("../../build/app/outputs/flutter-apk").asFile.mkdirs()
    }
}

// PROFILE → <root>/build/app/outputs/flutter-apk/app-profile.apk
val copyProfileApkToFlutter by tasks.registering(Copy::class) {
    val profileDir = layout.projectDirectory.dir("build/outputs/apk/profile").asFile
    // Defer candidate discovery until execution time
    val candidates = project.provider {
        // Prefer universal profile APK; fallback to first split profile APK (e.g. arm64-v8a)
        val universal = File(profileDir, "app-profile.apk")
        if (universal.exists()) listOf(universal)
        else profileDir.walkTopDown()
            .filter { it.isFile && it.name.endsWith("-profile.apk") }
            .toList()
    }

    onlyIf { candidates.get().isNotEmpty() }
    from({ candidates.get().first() })
    into(layout.projectDirectory.dir("../../build/app/outputs/flutter-apk"))
    rename { _ -> "app-profile.apk" }
    doFirst {
        layout.projectDirectory.dir("../../build/app/outputs/flutter-apk").asFile.mkdirs()
    }
}

// RELEASE AAB → <root>/build/app/outputs/bundle/release/app-release.aab
val copyReleaseAabToFlutter by tasks.registering(Copy::class) {
    val aab = layout.projectDirectory.file("build/outputs/bundle/release/app-release.aab").asFile
    onlyIf { aab.exists() }
    from(aab)
    into(layout.projectDirectory.dir("../../build/app/outputs/bundle/release"))
    rename { _ -> "app-release.aab" }
    doFirst {
        layout.projectDirectory.dir("../../build/app/outputs/bundle/release").asFile.mkdirs()
    }
}

/* ---------------------------------------------------------------------------
   Hook the copy tasks to run *after* the corresponding assemble/bundle tasks.
   --------------------------------------------------------------------------- */
afterEvaluate {
    tasks.findByName("assembleDebug")?.finalizedBy(copyDebugApkToFlutter)
    tasks.findByName("assembleProfile")?.finalizedBy(copyProfileApkToFlutter)
    tasks.findByName("bundleRelease")?.finalizedBy(copyReleaseAabToFlutter)
}