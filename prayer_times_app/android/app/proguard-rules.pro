############################################################
# Crashlytics — keep file & line numbers for deobfuscation
############################################################
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

############################################################
# Firebase Cloud Messaging (FCM)
# Keep MessagingService subclasses created at runtime.
############################################################
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

############################################################
# Flutter embedding / plugin entry points
# Safe to keep — prevents over‑aggressive stripping.
############################################################
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

############################################################
# Gson + TypeToken (fixes "Missing type parameter" errors)
# Gson relies on generic signatures, which R8 strips unless preserved.
# Required for flutter_local_notifications scheduled notification cache.
# (Verified via Gson + R8 compatibility documentation.)
############################################################
-keepattributes Signature,InnerClasses,EnclosingMethod

# Keep TypeToken & its subclasses
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# (Optional) If you use Gson to parse your own models:
# -keep class org.ialfm.prayertimes.** { *; }

############################################################
# flutter_local_notifications
# Prevent shrinker from removing scheduler/cache classes.
############################################################
-keep class com.dexterous.flutterlocalnotifications.** { *; }

############################################################
# Disable Play Core deferred‑components warnings
# Safe because you are NOT using dynamic feature modules.
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