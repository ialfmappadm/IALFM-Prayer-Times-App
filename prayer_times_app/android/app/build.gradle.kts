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
    id("com.google.firebase.crashlytics")
}

// Read Flutter-generated properties for versioning
val localProperties = Properties().apply {
    val file = File(rootProject.projectDir, "local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val flutterVersionCode = (localProperties.getProperty("flutter.versionCode") ?: "1").toInt()
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

// ADDED ─ Load keystore credentials from android/key.properties (if present)
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

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
    }

    // Modern locale packaging filter (replaces resConfigs)
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

    // ADDED ─ Define release signing (reads from key.properties)
    signingConfigs {
        create("release") {
            // Supports absolute or project-relative path
            // Example key.properties: storeFile=android/app/release.keystore
            val storeFilePath = keystoreProps.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProps.getProperty("storePassword")
            keyAlias = keystoreProps.getProperty("keyAlias")
            keyPassword = keystoreProps.getProperty("keyPassword")

            // Explicitly enable both schemes; modern Android expects v2+.
            // (These are enabled by default on recent AGP, but called out for clarity.)
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // ADDED ─ Point release at the release signing config
            // (Do NOT point to signingConfigs.debug; that causes unsigned or debug-signed APKs.)
            signingConfig = signingConfigs.getByName("release")

            // While we debug the splash issue you saw in release, you can temporarily disable shrinking.
            // Turn these back ON later and add keep rules once the app runs cleanly.
            isMinifyEnabled = true  // was true
            isShrinkResources = true // was true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        // Ensure profile exists and inherits debug flags
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
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))
    implementation("com.google.firebase:firebase-analytics")

    implementation("com.google.android.material:material:1.13.0")

    // Desugar runtime
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

/* ---------------------------------------------------------------------------
   Helpers to discover build outputs across unflavored & flavored variants.
   (unchanged)
   --------------------------------------------------------------------------- */
fun findSingleApk(baseDir: File, suffix: String): File? {
    if (!baseDir.exists()) return null
    val preferred = File(baseDir, "app-$suffix.apk")
    if (preferred.exists()) return preferred
    return baseDir
        .walkTopDown()
        .firstOrNull { it.isFile && it.name.endsWith("-$suffix.apk") }
}

fun findProfileApk(projectDir: File): File? {
    val unflavored = File(projectDir, "build/outputs/apk/profile")
    findSingleApk(unflavored, "profile")?.let { return it }
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
    val unflavored = File(projectDir, "build/outputs/bundle/release")
    val preferred = File(unflavored, "app-release.aab")
    if (preferred.exists()) return preferred
    return unflavored
        .walkTopDown()
        .firstOrNull { it.isFile && it.name.endsWith("-release.aab") }
}

/* ---------------------------------------------------------------------------
   Copy tasks … (unchanged)
   --------------------------------------------------------------------------- */
fun debugApkFiles(root: File): List<File> =
    findDebugApk(root)?.let { listOf(it) } ?: emptyList()

fun profileApkFiles(root: File): List<File> =
    findProfileApk(root)?.let { listOf(it) } ?: emptyList()

fun releaseAabFiles(root: File): List<File> =
    findReleaseAab(root)?.let { listOf(it) } ?: emptyList()

val copyDebugApkToFlutter by tasks.registering(Copy::class) {
    val outDir = layout.projectDirectory.dir("../../build/app/outputs/flutter-apk")
    from({ debugApkFiles(layout.projectDirectory.asFile) })
    into(outDir)
    rename { _ -> "app-debug.apk" }
    onlyIf { debugApkFiles(layout.projectDirectory.asFile).isNotEmpty() }
    doFirst { outDir.asFile.mkdirs() }
}

val copyProfileApkToFlutter by tasks.registering(Copy::class) {
    val outDir = layout.projectDirectory.dir("../../build/app/outputs/flutter-apk")
    from({ profileApkFiles(layout.projectDirectory.asFile) })
    into(outDir)
    rename { _ -> "app-profile.apk" }
    onlyIf { profileApkFiles(layout.projectDirectory.asFile).isNotEmpty() }
    doFirst { outDir.asFile.mkdirs() }
}

val copyReleaseAabToFlutter by tasks.registering(Copy::class) {
    val outDir = layout.projectDirectory.dir("../../build/app/outputs/bundle/release")
    from({ releaseAabFiles(layout.projectDirectory.asFile) })
    into(outDir)
    rename { _ -> "app-release.aab" }
    onlyIf { releaseAabFiles(layout.projectDirectory.asFile).isNotEmpty() }
    doFirst { outDir.asFile.mkdirs() }
}

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