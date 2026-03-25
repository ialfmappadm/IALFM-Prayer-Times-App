# Android Release Readme — Prayer Times App

This document captures the changes and procedures we used to ship a **minified + resource‑shrunk** Android release safely (R8 enabled), along with how to validate the AAB locally on a real device before pushing to Play Internal Testing.

---

## 1) What changed (high‑level)

- **R8/ProGuard hardening** via `android/app/proguard-rules.pro`:
    - Preserve Crashlytics line numbers for readable stack traces after obfuscation.
    - Keep only what’s necessary for FCM, Flutter embedding, `flutter_local_notifications`, and Gson’s `TypeToken` to avoid runtime errors (e.g., “Missing type parameter”). This issue is a known interaction between Gson generics and code shrinkers; preserving generic signatures and `TypeToken` fixes it. [1](https://flutterfixes.com/firebase-proguard-r8/)
    - Suppress warnings for **Play Core splitinstall** classes because we **do not** use Flutter’s Deferred Components; Flutter references those classes optionally. Suppression is the pragmatic/safe choice. [2](https://stackoverflow.com/questions/70656628/flutterfire-configure-command-not-working-i-need-to-set-firebase-in-my-flutte)

- **Resource shrinking stability** via `android/app/src/main/res/raw/keep_resources.xml`:
    - Explicitly **keep the notification small icon** (`@drawable/ic_stat_bell`) and **splash** drawable(s). Resource shrinking can remove resources referenced only by name or from platform channels; the **tools:keep** file is the official approach to keep them. [3](https://docs.flutter.dev/deployment/obfuscate)

- **Debug‑only crash testing tools** in `lib/debug_tools.dart`:
    - Adds a **Crash Test panel** (fatal + non‑fatal) that appears only in **debug** (and with a flag).
    - Helper to ping Analytics without leaving unused locals.

- **Local AAB validation** using **bundletool** to install device-targeted splits. This mirrors Play delivery so we can catch splash/runtime issues before upload. [4](https://pub.dev/packages/firebase_crashlytics)

- **App Check**: We’re leaving **Monitoring** ON (not enforcing). In Monitoring mode, requests aren’t blocked if the token is placeholder/invalid—so we **don’t** need SHA‑256 setup right now. We can enable enforcement later if we decide to protect Storage strictly. [5](https://github.com/0xbinder/proguard-rules)

---

## 2) R8 / ProGuard rules we ship

**File:** `android/app/proguard-rules.pro`

```pro
############################################################
# Crashlytics — keep file & line numbers for deobfuscation
############################################################
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

############################################################
# Firebase Cloud Messaging (FCM)
############################################################
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

############################################################
# Flutter embedding / plugin entry points
############################################################
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

############################################################
# Gson + TypeToken (prevents “Missing type parameter”)
############################################################
-keepattributes Signature,InnerClasses,EnclosingMethod
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
# -keep class org.ialfm.prayertimes.** { *; }  # (optional if we parse our own models)

############################################################
# flutter_local_notifications
############################################################
-keep class com.dexterous.flutterlocalnotifications.** { *; }

############################################################
# Suppress Play Core deferred-components warnings (not used)
############################################################
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task