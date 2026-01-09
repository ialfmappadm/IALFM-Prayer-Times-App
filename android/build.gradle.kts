
// android/build.gradle.kts (project-level)

plugins {
    // Declare the Google Services plugin here and don't apply it at the project level
    id("com.google.gms.google-services") version "4.4.4" apply false
}

// For Flutter projects this is fine; newer Gradle recommends per-module repos or DRMs in settings,
// but keeping allprojects here maintains compatibility with Flutter tooling.
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
