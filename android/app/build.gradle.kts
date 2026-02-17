// android/app/build.gradle.kts
@file:Suppress("UnstableApiUsage") // suppress incubating DSL warnings (e.g., androidResources.localeFilters)

import java.util.Properties
import java.io.File
import org.gradle.api.tasks.Copy
//import org.gradle.api.tasks.StopExecutionException

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

    // AGP 8.x supports API 36
    compileSdk = 36

    defaultConfig {
        applicationId = "org.ialfm.prayertimes"
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = flutterVersionCode
        versionName = flutterVersionName
        // (deprecated) resConfigs(...) → use androidResources.localeFilters below
        // resConfigs("en", "ar")
    }

    // ✅ Modern locale packaging filter (replaces resConfigs)
    androidResources {
        // Use addAll for cross-AGP compatibility
        localeFilters.addAll(listOf("en", "ar"))
    }

    // JDK 17 toolchain for source/target compatibility
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Some plugins use Java 8+ APIs on older Android → enable desugaring
        isCoreLibraryDesugaringEnabled = true
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
        // ✅ Ensure profile exists and inherits debug flags
        maybeCreate("profile").apply {
            initWith(getByName("debug"))
            matchingFallbacks += listOf("debug")
            // signingConfig = signingConfigs.debug // optional for local profile installs
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// --- Dependencies ---
// If all Firebase usage is via FlutterFire (Dart), you can remove native Firebase deps below.
dependencies {
    // Up-to-date suggestions to clear IDE hints
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))
    implementation("com.google.firebase:firebase-analytics")

    implementation("com.google.android.material:material:1.13.0")

    // Desugar runtime
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Add others if you call them natively:
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
    // implementation("com.google.firebase:firebase-messaging")
    // implementation("com.google.firebase:firebase-storage")
}

/* ---------------------------------------------------------------------------
   Helpers to discover build outputs across unflavored & flavored variants.
   --------------------------------------------------------------------------- */
fun findSingleApk(baseDir: File, suffix: String): File? {
    if (!baseDir.exists()) return null
    // Prefer a universal APK in the expected dir
    val preferred = File(baseDir, "app-$suffix.apk")
    if (preferred.exists()) return preferred
    // Otherwise, look for the first matching split APK under the baseDir
    return baseDir
        .walkTopDown()
        .firstOrNull { it.isFile && it.name.endsWith("-$suffix.apk") }
}

fun findProfileApk(projectDir: File): File? {
    // Unflavored: build/outputs/apk/profile/app-profile.apk
    val unflavored = File(projectDir, "build/outputs/apk/profile")
    findSingleApk(unflavored, "profile")?.let { return it }

    // Flavored: build/outputs/apk/<flavor>/profile/app-<flavor>-profile.apk
    val apkRoot = File(projectDir, "build/outputs/apk")
    if (!apkRoot.exists()) return null
    apkRoot.listFiles { f -> f.isDirectory }?.forEach { flavorDir ->
        val flavorProfile = File(flavorDir, "profile")
        findSingleApk(flavorProfile, "profile")?.let { return it }
    }
    return null
}

fun findDebugApk(projectDir: File): File? {
    val debugDir = File(projectDir, "build/outputs/apk/debug")
    return findSingleApk(debugDir, "debug")
}

fun findReleaseAab(projectDir: File): File? {
    // Unflavored AAB
    val unflavored = File(projectDir, "build/outputs/bundle/release")
    val preferred = File(unflavored, "app-release.aab")
    if (preferred.exists()) return preferred

    // Flavored AABs: app-<flavor>-release.aab
    return unflavored
        .walkTopDown()
        .firstOrNull { it.isFile && it.name.endsWith("-release.aab") }
}

/* ---------------------------------------------------------------------------
   Copy tasks that mirror AGP outputs to the paths Flutter expects.
   Late-evaluated callables (no Provider#get), skip cleanly if nothing to copy.
   --------------------------------------------------------------------------- */

// Callable producers that return [] when nothing exists (avoids provider realization errors)
fun debugApkFiles(root: File): List<File> =
    findDebugApk(root)?.let { listOf(it) } ?: emptyList()

fun profileApkFiles(root: File): List<File> =
    findProfileApk(root)?.let { listOf(it) } ?: emptyList()

fun releaseAabFiles(root: File): List<File> =
    findReleaseAab(root)?.let { listOf(it) } ?: emptyList()

// DEBUG → <root>/build/app/outputs/flutter-apk/app-debug.apk
val copyDebugApkToFlutter by tasks.registering(Copy::class) {
    val outDir = layout.projectDirectory.dir("../../build/app/outputs/flutter-apk")
    // Late evaluation; Copy accepts a Callable/closure
    from({ debugApkFiles(layout.projectDirectory.asFile) })
    into(outDir)
    rename { _ -> "app-debug.apk" }
    // Skip if no files
    onlyIf { debugApkFiles(layout.projectDirectory.asFile).isNotEmpty() }
    doFirst { outDir.asFile.mkdirs() }
}

// PROFILE → <root>/build/app/outputs/flutter-apk/app-profile.apk
val copyProfileApkToFlutter by tasks.registering(Copy::class) {
    val outDir = layout.projectDirectory.dir("../../build/app/outputs/flutter-apk")
    from({ profileApkFiles(layout.projectDirectory.asFile) })
    into(outDir)
    rename { _ -> "app-profile.apk" }
    onlyIf { profileApkFiles(layout.projectDirectory.asFile).isNotEmpty() }
    doFirst { outDir.asFile.mkdirs() }
}

// RELEASE AAB → <root>/build/app/outputs/bundle/release/app-release.aab
val copyReleaseAabToFlutter by tasks.registering(Copy::class) {
    val outDir = layout.projectDirectory.dir("../../build/app/outputs/bundle/release")
    from({ releaseAabFiles(layout.projectDirectory.asFile) })
    into(outDir)
    rename { _ -> "app-release.aab" }
    onlyIf { releaseAabFiles(layout.projectDirectory.asFile).isNotEmpty() }
    doFirst { outDir.asFile.mkdirs() }
}

/* ---------------------------------------------------------------------------
   Hook the copy tasks to run *after* the corresponding assemble/bundle tasks.
   Matches both unflavored & flavored task names.
   --------------------------------------------------------------------------- */
tasks.configureEach {
    when (name) {
        "assembleDebug" -> finalizedBy(copyDebugApkToFlutter)
        else -> {
            if (Regex("^assemble(\\w+)?Profile$").matches(name)) {
                finalizedBy(copyProfileApkToFlutter)
            }
            if (name == "bundleRelease" || Regex("^bundle(\\w+)?Release$").matches(name)) {
                finalizedBy(copyReleaseAabToFlutter)
            }
        }
    }
}