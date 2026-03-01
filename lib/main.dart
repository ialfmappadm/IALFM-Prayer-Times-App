// lib/main.dart
// Initializes app, themes, localization, messaging, and local alerts scheduling.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart'; // cloud metadata peek
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// Locale & prefs
import 'locale_controller.dart';
import 'theme_controller.dart';
import 'ux_prefs.dart';
// UI & pages
import 'models.dart';
import 'pages/prayer_page.dart';
import 'widgets/announcements_tab.dart';
import 'pages/social_page.dart';
import 'pages/directory_page.dart';
import 'pages/more_page.dart';
import 'utils/time_utils.dart';
import 'utils/clock_skew.dart';
// Repository (Storage -> local persist)
import 'prayer_times_firebase.dart';
// Hijri override
import 'services/hijri_override_service.dart';
import 'package:hijri/hijri_calendar.dart';
// Haptics
import 'utils/haptics.dart';
// Notifications opt-in + local scheduler
import 'services/notification_optin_service.dart';
import 'services/alerts_scheduler.dart';
// Localization
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';
// Warm-ups (images + glyphs)
import 'warm_up.dart';
// Font Awesome for bottom bar icons
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Iqamah change detector (local JSON only)
import 'services/iqamah_change_service.dart';
// Centralized popup UI (no bullets / 12‑hour / single‑Salah big time)
import 'widgets/iqamah_change_sheet.dart';

import 'dart:ui' as ui show TextDirection;
import 'package:ialfm_prayer_times/debug_tools.dart';
import 'package:flutter/services.dart';


// -- Navigation UI tuning
const double kNavIconSize = 18.0;
const double kNavBarHeight = 50.0;

// Daily check guard: only fetch if cloud stamp is new AND recent
const Duration kFreshCloudStampMaxAge = Duration(hours: 6);

// NEW: debug switch — schedule a local alert 10s after startup (for proving notifications)
// Toggle to true when you want the heads‑up proof; set back to false for normal use.
const bool kDebugKickLocalAlert10s = false;

// Global ScaffoldMessenger (already present) — used to show SnackBars AFTER first frame.
final GlobalKey<ScaffoldMessengerState> messengerKey =
GlobalKey<ScaffoldMessengerState>();

// Navigator key for a safe top‑level BuildContext after first frame
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

// -----------------------------------------------------------------------------
// NEW: one-time suppression for the very first "Prayer times updated" SnackBar
// -----------------------------------------------------------------------------
const String kFirstStartupSnackSuppressedKey =
    'ux.snack.firstStartupSuppressed';

// -----------------------------------------------------------------------------
// Background FCM handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure bindings for background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safe to call multiple times)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Ignore: initializeApp can throw if called more than once in process
  }

  // App Check (keep your original providers & behavior)
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
      kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      providerApple:
      kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
    );
  } catch (_) {
    // Background isolates on some devices/OS versions may fail to init App Check; safe to continue.
  }

  // Your existing payload handling (unchanged)
  final repo = PrayerTimesRepository();
  final shouldRefresh = message.data['updatePrayerTimes'] == 'true';
  final yearStr = message.data['year'];
  final year = (yearStr != null) ? int.tryParse(yearStr) : null;

  if (shouldRefresh) {
    await repo.refreshFromFirebase(year: year);
  }
}

// -----------------------------------------------------------------------------
// App entry point
Future<void> main() async {
  runZonedGuarded(() async {
    // Keep your original fatal flag
    BindingBase.debugZoneErrorsAreFatal = true;

    // Preserve native splash until first frame
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

    // Opt in to edge‑to‑edge (Android 15+ default; enables it on older Android as well)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Keep native splash until first Flutter frame
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // Fonts are asset-only (never HTTP)
    GoogleFonts.config.allowRuntimeFetching = false;

    // ---------------- Firebase core ----------------
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // FCM background handler (your original line)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ---------------- Firebase App Check ----------------
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
      kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      providerApple:
      kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
    );

    // ---------------- Crashlytics wiring ----------------
    // Forward Flutter framework errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // (Optional) Spin up Analytics instance (no-op if not used)
    await initAnalyticsAndLogAppOpen();
    // You can log a startup event if useful:
    // await analytics.logEvent(name: 'app_start');

    // ---------------- App init (unchanged) ----------------
    await UXPrefs.init();
    await ThemeController.init();

    // Cloud Hijri override (uses real resolver)
    await HijriOverrideService.applyIfPresent(resolveAppHijri: _appHijri);

    // Local notifications scheduler
    try {
      await AlertsScheduler.instance.init(androidSmallIcon: 'ic_stat_bell');
    } catch (_) {
      // Fallback (never block first frame)
      try {
        await AlertsScheduler.instance.init(androidSmallIcon: '@mipmap/ic_launcher');
      } catch (_) {}
    }

    // iOS: present notifications while app is in foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Run the app
    runApp(const BootstrapApp());

    // Post-frame async work (unchanged)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_postFrameAsync());
    });
  }, (Object error, StackTrace stack) {
    // Forward any uncaught async errors to Crashlytics
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    debugPrint('Uncaught async error: $error\n$stack');
  });
}

// Async work after first frame (warm-ups + deferred topic subscription)
Future<void> _postFrameAsync() async {
  unawaited(ClockSkew.calibrate()); // ← one‑line drift guard
  // Reacquire and use BuildContext inside helpers so we never hold it across awaits.
  await _warmImages();  // uses ctx immediately, then awaits
  // Non-context work
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = (cache.maximumSize * 1.3).round();

  await warmIntl();                      // pre-warm EN+AR formats (from warm_up.dart)
  await _preReadPrefsAndRemoteConfig();  // pre-read prefs & kick RC in background

  await _warmSalahRow(); // reacquires ctx and uses it immediately, then awaits

  // Defer FCM permission + topic subscription (~1.2s after first paint)
  unawaited(
    Future<void>.delayed(const Duration(milliseconds: 1200)).then((_) async {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
        debugPrint('FCM permission (deferred): ${settings.authorizationStatus}');
        await FirebaseMessaging.instance.subscribeToTopic('allUsers');
      } catch (e, st) {
        debugPrint('Deferred FCM setup error: $e\n$st');
      }
    }),
  );

  if (kDebugKickLocalAlert10s) {
    unawaited(AlertsScheduler.instance.debugScheduleInSeconds(10));
  }
}

// Uses a local ctx and awaits immediately (no ctx after an async gap)
Future<void> _warmImages() async {
  final ctx = navKey.currentContext;
  if (ctx == null) return;
  await warmUpAboveTheFold(ctx);
}

// Uses a local ctx and awaits immediately (no ctx after an async gap)
Future<void> _warmSalahRow() async {
  final ctx = navKey.currentContext;
  if (ctx == null) return;
  final isLight = Theme.of(ctx).brightness == Brightness.light;
  await warmUpSalahRow(ctx, isLight: isLight);
}

// NEW: keep first-tap clean by pre-reading prefs + kicking RC post-frame
Future<void> _preReadPrefsAndRemoteConfig() async {
  try {
    // Touch a few commonly-read prefs so first interaction doesn’t do I/O
    await UXPrefs.getString('flutter.ux.ann.lastSeenFp');
    await UXPrefs.getString('ux.snack.firstStartupSuppressed');

    // Seed Remote Config defaults and fetch in the background
    final rc = FirebaseRemoteConfig.instance;
    await rc.setDefaults({
      'ann_fp': '',               // announcements fingerprint
      'feature_x_enabled': false, // example feature flag
    });

    // Don’t block UI—fire and forget
    unawaited(rc.fetchAndActivate());
  } catch (e, st) {
    debugPrint('preReadPrefs/RC error: $e\n$st');
  }
}

// -- Light Theme
const ColorScheme lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0A2C42),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD6E6F1),
  onPrimaryContainer: Color(0xFF0A2231),
  secondary: Color(0xFFC7A447),
  onSecondary: Color(0xFF231A00),
  secondaryContainer: Color(0xFFFFF0C9),
  onSecondaryContainer: Color(0xFF2A2000),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF0F2432),
  outline: Color(0xFF7B90A0),
  outlineVariant: Color(0xFFC7D3DC),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410002),
  inverseSurface: Color(0xFF102431),
  onInverseSurface: Color(0xFFE7EEF4),
  inversePrimary: Color(0xFF9CC6E7),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

const ColorScheme darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF0A2C42),      // Navy
  onPrimary: Color(0xFFE7EEF4),
  primaryContainer: Color(0xFF0F1A22),
  onPrimaryContainer: Color(0xFFE7EEF4),

  secondary: Color(0xFFC7A447),    // Gold
  onSecondary: Color(0xFF1A1400),

  surface: Color(0xFF0A1116),      // inky canvas
  onSurface: Color(0xFFE8EDF3),

  outline: Color(0x14FFFFFF),      // white @ ~8%
  outlineVariant: Color(0x1AFFFFFF),

  error: Color(0xFFF29682),
  onError: Color(0xFF2B0D08),
  errorContainer: Color(0xFF3A1E1B),
  onErrorContainer: Color(0xFFFAD9D3),

  inverseSurface: Color(0xFFE8EDF3),
  onInverseSurface: Color(0xFF0A1116),

  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

const LinearGradient pageGradientLight = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF6F9FC), Color(0xFFFFFFFF)],
);

const LinearGradient pageGradientDark = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF0A101B), // inky top (blue-true)
    Color(0xFF0D1626), // bottom lift
  ],
  stops: [0.0, 1.0],
);

// ThemeExtension for gradient
@immutable
class AppGradients extends ThemeExtension<AppGradients> {
  final Gradient page;
  const AppGradients({required this.page});

  @override
  AppGradients copyWith({Gradient? page}) =>
      AppGradients(page: page ?? this.page);

  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    return t < 0.5 ? this : other;
  }

  static const light = AppGradients(page: pageGradientLight);
  static const dark  = AppGradients(page: pageGradientDark);
}

// -----------------------------------------------------------------------------
// Bootstrap App
class BootstrapApp extends StatelessWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure GoogleFonts never tries HTTP; will use your asset TTFs
    GoogleFonts.config.allowRuntimeFetching = false;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: LocaleController.locale,
          builder: (context, appLocale, __) {
            // Build Manrope‑based text theme using ASSET fonts registered in pubspec.yaml
            final TextTheme baseLatin = GoogleFonts.manropeTextTheme(
                ThemeData(brightness: Brightness.light).textTheme)
                .copyWith(
              titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            );

            const arabicFallback = ['IBM Plex Sans Arabic', 'Noto Sans Arabic'];

            TextTheme addFallbacks(TextTheme t) => t.copyWith(
              bodySmall:
              t.bodySmall?.copyWith(fontFamilyFallback: arabicFallback),
              bodyMedium:
              t.bodyMedium?.copyWith(fontFamilyFallback: arabicFallback),
              bodyLarge:
              t.bodyLarge?.copyWith(fontFamilyFallback: arabicFallback),
              titleSmall:
              t.titleSmall?.copyWith(fontFamilyFallback: arabicFallback),
              titleMedium:
              t.titleMedium?.copyWith(fontFamilyFallback: arabicFallback),
              titleLarge:
              t.titleLarge?.copyWith(fontFamilyFallback: arabicFallback),
              labelSmall:
              t.labelSmall?.copyWith(fontFamilyFallback: arabicFallback),
              labelMedium:
              t.labelMedium?.copyWith(fontFamilyFallback: arabicFallback),
              labelLarge:
              t.labelLarge?.copyWith(fontFamilyFallback: arabicFallback),
              displaySmall:
              t.displaySmall?.copyWith(fontFamilyFallback: arabicFallback),
              displayMedium:
              t.displayMedium?.copyWith(fontFamilyFallback: arabicFallback),
              displayLarge:
              t.displayLarge?.copyWith(fontFamilyFallback: arabicFallback),
              headlineSmall:
              t.headlineSmall?.copyWith(fontFamilyFallback: arabicFallback),
              headlineMedium:
              t.headlineMedium?.copyWith(fontFamilyFallback: arabicFallback),
              headlineLarge:
              t.headlineLarge?.copyWith(fontFamilyFallback: arabicFallback),
            );

            final TextTheme chosenLight = addFallbacks(baseLatin);
            final TextTheme chosenDark = addFallbacks(baseLatin);

            final ThemeData baseLight = ThemeData(
              useMaterial3: true,
              colorScheme: lightColorScheme,
              scaffoldBackgroundColor: lightColorScheme.surface,
              textTheme: chosenLight,
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                iconTheme:
                WidgetStateProperty.resolveWith<IconThemeData>((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected
                        ? lightColorScheme.primary.withValues(alpha: 0.95)
                        : const Color(0xFF556978).withValues(alpha: 0.75),
                  );
                }),
              ),
              snackBarTheme: SnackBarThemeData(
                backgroundColor: Colors.white,
                contentTextStyle: const TextStyle(
                    color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
                actionTextColor: Colors.black,
                elevation: 3,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              extensions: const <ThemeExtension<dynamic>>[
                AppGradients.light,
              ],
            );

            const ColorScheme darkColorScheme = ColorScheme(
              brightness: Brightness.dark,
              primary: Color(0xFF0A1E3A),      // Navy
              onPrimary: Color(0xFFE7EEF4),
              primaryContainer: Color(0xFF0F1A22),
              onPrimaryContainer: Color(0xFFE7EEF4),

              secondary: Color(0xFFC7A447),    // Gold
              onSecondary: Color(0xFF1A1400),

              surface: Color(0xFF0A101B),      // inky canvas
              onSurface: Color(0xFFE8EDF3),

              outline: Color(0x14FFFFFF),      // white @ ~8%
              outlineVariant: Color(0x1AFFFFFF),

              error: Color(0xFFF29682),
              onError: Color(0xFF2B0D08),
              errorContainer: Color(0xFF3A1E1B),
              onErrorContainer: Color(0xFFFAD9D3),

              inverseSurface: Color(0xFFE8EDF3),
              onInverseSurface: Color(0xFF0A1116),

              shadow: Color(0xFF000000),
              scrim: Color(0xFF000000),
            );

            final ThemeData baseDark = ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              colorScheme: darkColorScheme, // the const scheme defined above in BootstrapApp
              scaffoldBackgroundColor: darkColorScheme.surface,
              textTheme: chosenDark,

              // Keep your existing nav bar look
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: darkColorScheme.surface,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.72),
                  );
                }),
              ),

              // Make snackbars readable in dark (kept from your current code)
              snackBarTheme: SnackBarThemeData(
                backgroundColor: Colors.white,
                contentTextStyle: const TextStyle(
                    color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
                actionTextColor: Colors.black,
                elevation: 3,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),

              // ---- New: pin common interaction widgets for dark ----
              // Tiles (ListTile + ExpansionTile) should keep onSurface for text/icons even when expanded/pressed.
              listTileTheme: ListTileThemeData(
                textColor: darkColorScheme.onSurface,
                iconColor: darkColorScheme.onSurface,
              ),
              expansionTileTheme: ExpansionTileThemeData(
                textColor: darkColorScheme.onSurface,
                iconColor: darkColorScheme.onSurface,
                collapsedTextColor: darkColorScheme.onSurface,
                collapsedIconColor: darkColorScheme.onSurface,
              ),

              // Buttons — keep readable foregrounds on dark and predictable overlays.
              textButtonTheme: TextButtonThemeData(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(darkColorScheme.onSurface),
                  overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(darkColorScheme.onSurface),
                  side: WidgetStateProperty.all(
                      BorderSide(color: darkColorScheme.outline.withValues(alpha: 0.50))),
                  overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              // Applies to both FilledButton and FilledButton.tonal unless locally overridden.
              filledButtonTheme: FilledButtonThemeData(
                style: ButtonStyle(
                  // Use gold by default for primary filled buttons; your sheets already
                  // specify gold explicitly, so this just unifies elsewhere.
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return darkColorScheme.surface.withValues(alpha: 0.38);
                    }
                    return darkColorScheme.secondary; // gold
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.black),
                  overlayColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.06)),
                ),
              ),
              segmentedButtonTheme: SegmentedButtonThemeData(
                style: ButtonStyle(
                  // Ensure labels stay readable on the dark card background
                  foregroundColor: WidgetStateProperty.all(darkColorScheme.onSurface),
                  overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
                ),
              ),

              // Bottom sheets should stay on your dark surface (no surprise tint)
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Color(0xFF0A101B), // same as dark surface
                modalBackgroundColor: Color(0xFF0A101B),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),

              // Subtle, consistent ink ripple in dark
              splashColor: Colors.white.withValues(alpha: 0.08),
              highlightColor: Colors.white.withValues(alpha: 0.06),

              // Keep your gradients
              extensions: const <ThemeExtension<dynamic>>[
                AppGradients.dark,
              ],
              switchTheme: SwitchThemeData(
                // Track fill
                trackColor: WidgetStateProperty.resolveWith<Color>((states) {
                  final on = states.contains(WidgetState.selected);
                  final disabled = states.contains(WidgetState.disabled);
                  if (disabled) return Colors.white.withValues(alpha: 0.12);
                  return on
                      ? const Color(0xFF34C759).withValues(alpha: 0.70)
                      : Colors.white.withValues(alpha: 0.22);
                }),
                // Track outline (gives definition on dark backgrounds)
                trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
                  final on = states.contains(WidgetState.selected);
                  final disabled = states.contains(WidgetState.disabled);
                  if (disabled) return Colors.white.withValues(alpha: 0.16);
                  return on
                      ? const Color(0xFF9CF7B7)
                      : Colors.white.withValues(alpha: 0.35);
                }),
                // Thumb: bright in both states for readability
                thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                  final on = states.contains(WidgetState.selected);
                  final disabled = states.contains(WidgetState.disabled);
                  if (disabled) return Colors.white.withValues(alpha: 0.40);
                  return on ? Colors.white : Colors.white.withValues(alpha: 0.90);
                }),
              ),
            );


            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'IALFM',
              themeMode: mode,
              theme: baseLight,
              darkTheme: baseDark,
              scaffoldMessengerKey: messengerKey,
              navigatorKey: navKey,
              navigatorObservers: [HapticNavigatorObserver()],
              locale: appLocale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,

              // Enable app-wide state restoration (restores nav + restorable state)
              restorationScopeId: 'app',

              builder: (context, child) {
                return ValueListenableBuilder<double>(
                  valueListenable: UXPrefs.textScale,
                  builder: (context, scale, _) {
                    final mq = MediaQuery.of(context);
                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    // Only control icon brightness; do NOT set status/navigation bar colors.
                    // This avoids deprecated APIs on Android 15+ and is safe on iOS.
                    final uiStyle = SystemUiOverlayStyle(
                      statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                      systemNavigationBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                    );

                    return Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: AnnotatedRegion<SystemUiOverlayStyle>(
                        value: uiStyle,
                        child: MediaQuery(
                          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                          child: child!,
                        ),
                      ),
                    );
                  },
                );
              },
              home: const _BootstrapScreen(),
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Bootstrap Screen
class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();
  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen>
    with WidgetsBindingObserver {
  late Future<_InitResult> _initFuture;
  final PrayerTimesRepository _repo = PrayerTimesRepository();
  Timer? _midnightTimer;

  // NEW: keep the last successfully built result (prevents black flash on resume)
  _InitResult? _lastGood;

  // Daily check prefs keys
  static const _kLastDailyCheckYMD = 'ux.schedule.lastDailyCheckYMD';
  static const _kLastCloudStamp = 'ux.schedule.lastCloudStamp';
  static const _kLastShownUpdatedAt = 'ux.schedule.lastShownUpdatedAt';

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initializeAll();
    _initFuture.whenComplete(() {
      if (mounted) FlutterNativeSplash.remove();
    });
    _scheduleMidnightRefresh();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Badge handled in HomeTabs
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  // NEW: rehydrate from local JSON without disturbing the current UI
  Future<void> _rehydrateLocalSilently() async {
    try {
      final r = await _initializeAll(skipCloud: true);
      if (!mounted) return;
      setState(() {
        _lastGood = r; // swap in the new schedule when ready
      });
    } catch (e, st) {
      debugPrint('Silent rehydrate failed: $e\n$st');
      // Keep showing previous UI; we'll try again next resume.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 1) Refresh from LOCAL only (no cloud hit) but KEEP showing the previous UI
      unawaited(_rehydrateLocalSilently());
      // 2) Keep your once-per-day cloud peek (unchanged behavior)
      unawaited(_maybeDailyCloudCheck());
    }
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _initFuture = _initializeAll();
      });
      _scheduleMidnightRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InitResult>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          final r = snap.data!;
          // NEW: remember the last good result for future resumes
          _lastGood = r;

          // Post-frame: maybe show heads‑up / night‑before prompts
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeShowIqamahChangePrompt(r);
          });
          return HomeTabs(
            location: r.location,
            nowLocal: r.nowLocal,
            today: r.today,
            tomorrow: r.tomorrow,
            temperatureF: r.temperatureF,
          );
        }

        if (snap.hasError) {
          FlutterNativeSplash.remove();
          return _SplashScaffold(
            key: const ValueKey('bootstrap_error'),
            title: 'Starting up...',
            subtitle: 'Error:\n${snap.error}',
            onRetry: () => setState(() => _initFuture = _initializeAll()),
          );
        }

        // NEW: While initial load is pending but we have a prior good UI, show that
        if (_lastGood != null) {
          final r = _lastGood!;
          return HomeTabs(
            location: r.location,
            nowLocal: r.nowLocal,
            today: r.today,
            tomorrow: r.tomorrow,
            temperatureF: r.temperatureF,
          );
        }

        // Initial boot splash (first ever run)
        return const SizedBox.shrink();
      },
    );
  }

  Future<_InitResult> _initializeAll({bool skipCloud = false}) async {
    // Timezone init (central time)
    tz.Location location;
    try {
      location = await initCentralTime();
    } catch (_) {
      location = tz.getLocation('America/Chicago');
    }

    // NEW: Startup refresh only if cloud is NEWER than local (no wasteful downloads)
    bool updatedAtStartup = false;
    if (!skipCloud) {
      updatedAtStartup = await _maybeStartupRefreshFromCloud(_repo);
    }
    debugPrint(
        'Startup refresh: ${updatedAtStartup ? 'updated from Firebase' : 'no change'}');

    // Load local schedule
    final nowLocal = DateTime.now();
    List<PrayerDay> days;
    try {
      days = await loadPrayerDays(year: nowLocal.year);
    } catch (e, st) {
      debugPrint('loadPrayerDays() error: $e\n$st');
      days = <PrayerDay>[];
    }
    final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final PrayerDay today = _findByDate(days, todayDate) ??
        (days.isNotEmpty ? days.first : _dummyDay(todayDate));

    final tomorrowDate = todayDate.add(const Duration(days: 1));
    final PrayerDay? tomorrow = _findByDate(days, tomorrowDate);

    // Weather (non‑blocking)
    final coords = _coordsForLocation(location);

    final double? currentTempF = await _fetchTemperatureF(
      latitude: coords.lat,
      longitude: coords.lon,
    ).timeout(const Duration(seconds: 10), onTimeout: () => null);

    debugPrint('[Weather] final currentTempF=${currentTempF?.toStringAsFixed(1) ?? 'null (will use default)'}');

    // Schedule local alerts (only if OS notifications are enabled)
    await _scheduleLocalAlerts(nowLocal: nowLocal, today: today);

    // Detect upcoming Iqamah change using local JSON only
    final upcoming = IqamahChangeService.detectUpcomingChange(
      allDays: days,
      todayLocal: nowLocal,
    );

    return _InitResult(
      location: location,
      nowLocal: nowLocal,
      today: today,
      tomorrow: tomorrow,
      temperatureF: currentTempF,
      upcomingChange: upcoming,
    );
  }

  // NEW: Only refresh from Firebase at startup if remote metadata is NEWER than local.
  Future<bool> _maybeStartupRefreshFromCloud(PrayerTimesRepository repo) async {
    try {
      final int year = DateTime.now().year;

      // Read local lastUpdated from your persisted meta (if any)
      final localMeta = await repo.readMeta();
      final String localWhen = (localMeta?['lastUpdated'] ?? '') as String;

      // Peek remote metadata (no content download)
      final ref = FirebaseStorage.instance
          .ref()
          .child('prayer_times')
          .child('$year.json');

      FullMetadata meta;
      try {
        meta = await ref.getMetadata();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          // Nothing in cloud → skip quietly
          debugPrint('[StartupCheck] cloud object missing → skip.');
          return false;
        }
        return false;
      }

      final DateTime? remoteStampUtc = meta.updated ?? meta.timeCreated;
      if (remoteStampUtc == null) return false;
      final remoteStamp = remoteStampUtc.toLocal();

      // Compare remote to local: if local empty or remote is newer → download
      final DateTime? localWhenDt = DateTime.tryParse(localWhen)?.toLocal();
      final bool remoteIsNewer =
          (localWhenDt == null) || remoteStamp.isAfter(localWhenDt);
      if (!remoteIsNewer) return false;

      // Download & persist updated file; then show snack (with first-run suppression).
      final updated = await repo.refreshFromFirebase(year: year);
      if (updated) {
        final metaLocal = await repo.readMeta();
        final whenStr = (metaLocal?['lastUpdated'] ?? '') as String;
        await _tryShowUpdatedSnack(whenStr);
        return true;
      }
    } catch (e, st) {
      debugPrint('Startup cloud check error: $e\n$st');
    }
    return false;
  }

  // -- Daily cloud metadata peek
  Future<void> _maybeDailyCloudCheck() async {
    try {
      // only once per day
      final todayYMD = _ymd(DateTime.now());
      final lastYMD = await UXPrefs.getString(_kLastDailyCheckYMD);
      if (lastYMD == todayYMD) return;
      await UXPrefs.setString(_kLastDailyCheckYMD, todayYMD);

      final year = DateTime.now().year;
      // Peek metadata (no content download)
      // CHANGED: use chained child() to avoid leading-slash issues.
      final ref = FirebaseStorage.instance
          .ref()
          .child('prayer_times')
          .child('$year.json');

      FullMetadata meta;
      try {
        meta = await ref.getMetadata();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          // Nothing in cloud → keep using local (quietly skip; no 404 spam).
          debugPrint('[DailyCheck] cloud object missing → skip.');
          return;
        }
        return;
      }

      final stamp = (meta.updated ?? meta.timeCreated); // DateTime?
      if (stamp == null) return;

      final lastKnownStr = await UXPrefs.getString(_kLastCloudStamp);
      final lastKnown = (lastKnownStr != null && lastKnownStr.isNotEmpty)
          ? DateTime.tryParse(lastKnownStr)
          : null;

      // Only care if stamp is recent (few hours) and newer than we know
      final isRecent =
          DateTime.now().difference(stamp.toLocal()) <= kFreshCloudStampMaxAge;
      final isNewer = (lastKnown == null) || stamp.isAfter(lastKnown);
      if (!(isRecent && isNewer)) {
        debugPrint('[DailyCheck] no action (recent=$isRecent, newer=$isNewer).');
        return;
      }

      // Download & persist updated file
      final updated = await _repo.refreshFromFirebase(year: year);
      if (updated) {
        final metaLocal = await _repo.readMeta();
        final whenStr = (metaLocal?['lastUpdated'] ?? '') as String;
        await _tryShowUpdatedSnack(
            whenStr); // safe, one-time-suppressed & post-frame
        await UXPrefs.setString(
            _kLastCloudStamp, stamp.toUtc().toIso8601String());
        debugPrint('[DailyCheck] updated from cloud.');
      } else {
        debugPrint(
            '[DailyCheck] metadata newer but refresh failed → try tomorrow.');
      }
    } catch (e, st) {
      debugPrint('Daily cloud check error: $e\n$st');
    }
  }

  // -- Local alerts scheduling
  Future<void> _scheduleLocalAlerts({
    required DateTime nowLocal,
    required PrayerDay today,
  }) async {
    // App-level authorization
    final status = await NotificationOptInService.getStatus();
    final authorized = NotificationOptInService.isAuthorized(status);

    // Fallback: double-check at the plugin level (Android) to avoid stale false negatives.
    bool finalAuthorized = authorized;
    try {
      final enabled = await AlertsScheduler.instance.areNotificationsEnabledAndroid();
      if (enabled == true && !authorized) {
        debugPrint('[Alerts] App status said "not authorized", but Android reports '
            'notifications ENABLED → proceeding.');
        finalAuthorized = true;
      }
    } catch (_) {
      // ignore; use app-level decision
    }

    if (!finalAuthorized) {
      if (kDebugMode) {
        debugPrint('[Alerts] Skipped scheduling: permission not granted '
            '(appAuthorized=$authorized)');
      }
      return;
    }

    // Parse "HH:mm" -> DateTime
    DateTime? mkTime(DateTime base, String hhmm) {
      if (hhmm.isEmpty) return null;
      final parts = hhmm.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    final base = DateTime(today.date.year, today.date.month, today.date.day);

    // Adhan
    final fajrAdhan = mkTime(base, today.prayers['fajr']?.begin ?? '');
    final dhuhrAdhan = mkTime(base, today.prayers['dhuhr']?.begin ?? '');
    final asrAdhan = mkTime(base, today.prayers['asr']?.begin ?? '');
    final maghribAdhan = mkTime(base, today.prayers['maghrib']?.begin ?? '');
    final ishaAdhan = mkTime(base, today.prayers['isha']?.begin ?? '');

    // Iqamah
    final fajrIqamah = mkTime(base, today.prayers['fajr']?.iqamah ?? '');
    final dhuhrIqamah = mkTime(base, today.prayers['dhuhr']?.iqamah ?? '');
    final asrIqamah = mkTime(base, today.prayers['asr']?.iqamah ?? '');
    final maghribIqamah = mkTime(base, today.prayers['maghrib']?.iqamah ?? '');
    final ishaIqamah = mkTime(base, today.prayers['isha']?.iqamah ?? '');

    // Read toggles from UXPrefs
    final bool adhanEnabled = UXPrefs.adhanAlertEnabled.value;
    final bool iqamahEnabled = UXPrefs.iqamahAlertEnabled.value;
    final bool jumuahEnabled = UXPrefs.jumuahReminderEnabled.value;

    await _schedulePrayerAlertsForDay(
      dateLocal: base,
      fajrAdhan: fajrAdhan,
      dhuhrAdhan: dhuhrAdhan,
      asrAdhan: asrAdhan,
      maghribAdhan: maghribAdhan,
      ishaAdhan: ishaAdhan,
      fajrIqamah: fajrIqamah,
      dhuhrIqamah: dhuhrIqamah,
      asrIqamah: asrIqamah,
      maghribIqamah: maghribIqamah,
      ishaIqamah: ishaIqamah,
      adhanEnabled: adhanEnabled,
      iqamahEnabled: iqamahEnabled,
    );

    await AlertsScheduler.instance.scheduleJumuahReminderForWeek(
      anyDateThisWeekLocal: base,
      enabled: jumuahEnabled,
    );

    // DEV audit: list all pending after scheduling
    final pending = await AlertsScheduler.instance.dumpPending(printLog: true);
    debugPrint('[Alerts] Total pending after schedule: ${pending.length}');
  }

  // Extracted to avoid very long `_scheduleLocalAlerts`
  Future<void> _schedulePrayerAlertsForDay({
    required DateTime dateLocal,
    DateTime? fajrAdhan,
    DateTime? dhuhrAdhan,
    DateTime? asrAdhan,
    DateTime? maghribAdhan,
    DateTime? ishaAdhan,
    DateTime? fajrIqamah,
    DateTime? dhuhrIqamah,
    DateTime? asrIqamah,
    DateTime? maghribIqamah,
    DateTime? ishaIqamah,
    required bool adhanEnabled,
    required bool iqamahEnabled,
  }) async {
    await AlertsScheduler.instance.schedulePrayerAlertsForDay(
      dateLocal: dateLocal,
      fajrAdhan: fajrAdhan,
      dhuhrAdhan: dhuhrAdhan,
      asrAdhan: asrAdhan,
      maghribAdhan: maghribAdhan,
      ishaAdhan: ishaAdhan,
      fajrIqamah: fajrIqamah,
      dhuhrIqamah: dhuhrIqamah,
      asrIqamah: asrIqamah,
      maghribIqamah: maghribIqamah,
      ishaIqamah: ishaIqamah,
      adhanEnabled: adhanEnabled,
      iqamahEnabled: iqamahEnabled,
    );
  }

  // -- Iqamah change prompt helpers (unified sheet)
  Future<void> _maybeShowIqamahChangePrompt(_InitResult r) async {
    final ch = r.upcomingChange;
    if (ch == null || !ch.anyChange) return;

    // First-open-of-day guard (prevents re-prompting if user reopens app)
    final firstOpen = await UXPrefs.markOpenToday(r.nowLocal);
    if (!mounted) return;
    if (!firstOpen) return;

    final changeYMD = ch.changeYMD;
    final delta = ch.daysToChange; // use detector’s own delta

    if (delta == 2) {
      if (!UXPrefs.wasShownHeadsUp(changeYMD)) {
        await showIqamahChangeSheet(context, ch); // new UI (no bullets)
        if (!mounted) return;
        await UXPrefs.markShownHeadsUp(changeYMD);
      }
      return;
    }

    if (delta == 1) {
      final afterCutoff = IqamahChangeService.isAfterMaghrib(
        today: r.today,
        nowLocal: r.nowLocal,
      );
      if (afterCutoff && !UXPrefs.wasShownNightBefore(changeYMD)) {
        await showIqamahChangeSheet(context, ch); // new UI (no bullets)
        if (!mounted) return;
        await UXPrefs.markShownNightBefore(changeYMD);
      }
      return;
    }
  }

  // NEW: Safe, one‑time‑suppressed SnackBar for "Prayer times updated".
  // • Suppresses the very first auto Snack after install/clear‑data AND marks it as shown.
  // • Only shows if the 'lastUpdated' stamp is fresh (<= 2 min).
  // • Shows after first frame via messengerKey to avoid Scaffold assertion.
  Future<void> _tryShowUpdatedSnack(String whenStr) async {
    if (whenStr.isEmpty) return;

    // Compute freshness
    final when = DateTime.tryParse(whenStr)?.toLocal();
    final isFresh = when != null &&
        DateTime.now().difference(when) <= const Duration(minutes: 2);
    if (!isFresh) return;

    // First ever auto‑startup snack? Suppress AND mark as already shown
    final firstSuppressed =
    await UXPrefs.getString(kFirstStartupSnackSuppressedKey);
    if (firstSuppressed == null) {
      await UXPrefs.setString(kFirstStartupSnackSuppressedKey, '1');
      await UXPrefs.setString(_kLastShownUpdatedAt, whenStr); // <- mark shown
      await UXPrefs.setString(_kLastCloudStamp, whenStr);
      return; // swallow first startup snack only
    }

    // De‑duplicate by lastShown
    final lastShown = await UXPrefs.getString(_kLastShownUpdatedAt);
    if (lastShown == whenStr) return;

    // Show safely AFTER a frame, using the root messenger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ms = messengerKey.currentState;
      if (ms != null) {
        ms.showSnackBar(const SnackBar(
          content: Text('Prayer times updated'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
    await UXPrefs.setString(_kLastShownUpdatedAt, whenStr);
    await UXPrefs.setString(_kLastCloudStamp, whenStr);
  }

  PrayerDay? _findByDate(List<PrayerDay> days, DateTime target) {
    for (final d in days) {
      if (d.date.year == target.year &&
          d.date.month == target.month &&
          d.date.day == target.day) {
        return d;
      }
    }
    return null;
  }

  PrayerDay _dummyDay(DateTime date) {
    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final begin = fmt(date);
    final Map<String, PrayerTime> prayers = {
      'fajr':    PrayerTime(begin: begin, iqamah: ''),
      'dhuhr':   PrayerTime(begin: begin, iqamah: ''),
      'asr':     PrayerTime(begin: begin, iqamah: ''),
      'maghrib': PrayerTime(begin: begin, iqamah: ''),
      'isha':    PrayerTime(begin: begin, iqamah: ''),
    };
    return PrayerDay(
      date: date,
      prayers: prayers,
      sunrise: begin,
      sunset:  begin,
      serial:  0,
    );
  }
}

// -----------------------------------------------------------------------------
// Result wrapper
class _InitResult {
  final tz.Location location;
  final DateTime nowLocal;
  final PrayerDay today;
  final PrayerDay? tomorrow;
  final double? temperatureF;
  final IqamahChange? upcomingChange;
  _InitResult({
    required this.location,
    required this.nowLocal,
    required this.today,
    required this.tomorrow,
    required this.temperatureF,
    required this.upcomingChange,
  });
}

// -----------------------------------------------------------------------------
// Splash
class _SplashScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  const _SplashScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, size: 56, color: Color(0xFF2E7D32)),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Navigation (HomeTabs)
class HomeTabs extends StatefulWidget {
  final tz.Location location;
  final DateTime nowLocal;
  final PrayerDay today;
  final PrayerDay? tomorrow;
  final double? temperatureF;
  const HomeTabs({
    super.key,
    required this.location,
    required this.nowLocal,
    required this.today,
    required this.tomorrow,
    required this.temperatureF,
  });

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs>
    with WidgetsBindingObserver, RestorationMixin {
  // Restorable selected index
  final RestorableInt _restorableIndex = RestorableInt(0);

  bool hasNewAnnouncement = false;

  // Announcement fingerprint keys
  static const _kAnnSeenFp = 'ux.ann.lastSeenFp'; // last seen by the user
  String? _annFp;                                 // latest fetched/received fp

  @override
  String? get restorationId => 'home_tabs';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorableIndex, 'home_tabs_index');
  }

  int get _index => _restorableIndex.value;
  set _index(int v) => _restorableIndex.value = v;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // --- FCM fast path: nudge the dot on new announcements ---
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Prefer fingerprint if provided; else accept the old 'newAnnouncement=true'
      final fp = message.data['ann_fp'] as String?;
      if (fp != null && fp.isNotEmpty) {
        unawaited(_applyAnnFp(fp));
      } else if (message.data['newAnnouncement'] == 'true') {
        if (mounted) setState(() => hasNewAnnouncement = true);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final fp = m.data['ann_fp'] as String?;
      if (fp != null && fp.isNotEmpty) {
        unawaited(_applyAnnFp(fp));
      } else if (m.data['newAnnouncement'] == 'true') {
        if (mounted) setState(() => _index = 1); // open tab; dot cleared on open
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((m) {
      final fp = m?.data['ann_fp'] as String?;
      if (fp != null && fp.isNotEmpty) {
        unawaited(_applyAnnFp(fp));
      } else if (m?.data['newAnnouncement'] == 'true') {
        if (mounted) setState(() => _index = 1);
      }
    });

    // RC fallback: pick up changes even when no FCM was sent
    unawaited(_fetchAnnFpFromRC());

    // (You already call _restoreTabIntent(); keep that if present)
    // unawaited(_restoreTabIntent());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh from RC when app returns to foreground
    if (state == AppLifecycleState.resumed) {
      unawaited(_fetchAnnFpFromRC());
    }
  }

  // --- RC fetch + apply ---
  Future<void> _fetchAnnFpFromRC() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      // Keep fetch fast; 0–15 min interval is fine — we only call on resume/start
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(minutes: 15),
      ));
      await rc.fetchAndActivate();
      final fp = rc.getString('ann_fp').trim();
      await _applyAnnFp(fp.isEmpty ? null : fp);
    } catch (_) {
      // swallow — dot just won't update from RC this time
    }
  }

  // Compare new fingerprint to what user last saw; light the dot if different.
  Future<void> _applyAnnFp(String? fp) async {
    if (fp == null || fp.isEmpty) return;
    _annFp = fp;
    final lastSeen = await UXPrefs.getString(_kAnnSeenFp);
    final hasNew = (lastSeen == null || lastSeen != fp);
    if (!mounted) return;
    setState(() => hasNewAnnouncement = hasNew);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restorableIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      PrayerPage(
        location: widget.location,
        nowLocal: widget.nowLocal,
        today: widget.today,
        tomorrow: widget.tomorrow,
        temperatureF: widget.temperatureF,
      ),
      AnnouncementsTab(location: widget.location),
      const SocialPage(),
      const DirectoryPage(),
      const MorePage(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: RepaintBoundary(
        child: NavigationBar(
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: kNavBarHeight,
          selectedIndex: _index,
          onDestinationSelected: (i) async {
            // Correct clearing: when user OPENS the Announcements tab,
            // mark current fingerprint as "seen" and clear the dot.
            setState(() {
              _index = i;
              if (i == 1) hasNewAnnouncement = false;
            });
            if (i == 1) {
              final fp = _annFp;
              if (fp != null && fp.isNotEmpty) {
                await UXPrefs.setString(_kAnnSeenFp, fp);
              }
            }
            Haptics.tap();
          },
          destinations: [
            const NavigationDestination(label: '', icon: Icon(Icons.schedule)),
            // 🔔 with red dot
            NavigationDestination(
              label: '',
              icon: Stack(clipBehavior: Clip.none, children: [
                const FaIcon(FontAwesomeIcons.bell, size: 20),
                if (hasNewAnnouncement)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.white : Colors.black,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ]),
              selectedIcon: Stack(clipBehavior: Clip.none, children: [
                const FaIcon(FontAwesomeIcons.bell, size: 20),
                if (hasNewAnnouncement)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.white : Colors.black,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const NavigationDestination(
              label: '', icon: FaIcon(FontAwesomeIcons.instagram, size: 20),
            ),
            const NavigationDestination(
              label: '', icon: FaIcon(FontAwesomeIcons.addressBook, size: 20),
            ),
            const NavigationDestination(label: '', icon: Icon(Icons.more_horiz)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helpers (coords & weather)
class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
}

LatLon _coordsForLocation(tz.Location location) {
  final locationName = location.name.toLowerCase();
  if (locationName.contains('america/chicago')) {
    return const LatLon(33.0354, -97.0830); // IALFM Masjid Coordinates
  }
  return const LatLon(33.0354, -97.0830); // IALFM Masjid Coodrinates (fallback)
}

Future<double?> _fetchTemperatureF({
  required double latitude,
  required double longitude,
}) async {
  try {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current_weather': 'true',
      'temperature_unit': 'fahrenheit',
      'timezone': 'auto',
    });

    debugPrint('[Weather] GET $uri');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final cw = data['current_weather'] as Map<String, dynamic>?;
      final t = cw?['temperature'];
      if (t is num) {
        final val = t.toDouble();
        debugPrint('[Weather] current_temperature_f=$val');
        return val;
      } else {
        debugPrint('[Weather] current_weather.temperature missing or not a number. body=${resp.body}');
      }
    } else {
      debugPrint('[Weather] HTTP ${resp.statusCode}: ${resp.body}');
    }
  } on TimeoutException {
    debugPrint('[Weather] request timeout after 10s');
  } catch (e, st) {
    debugPrint('[Weather] fetch error: $e\n$st');
  }
  return null;
}

// -- Hijri resolver
Future<HijriYMD> _appHijri(DateTime g) async {
  final h = HijriCalendar.fromDate(g);
  return HijriYMD(h.hYear, h.hMonth, h.hDay);
}