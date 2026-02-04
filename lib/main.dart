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

// Locale & prefs
import 'locale_controller.dart';
import 'theme_controller.dart';
import 'ux_prefs.dart';

// UI & pages
import 'app_colors.dart';
import 'models.dart';
import 'pages/prayer_page.dart';
import 'widgets/announcements_tab.dart';
import 'pages/social_page.dart';
import 'pages/directory_page.dart';
import 'pages/more_page.dart';
import 'utils/time_utils.dart';

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

// -- Navigation UI tuning
const double kNavIconSize = 18.0;
const double kNavBarHeight = 50.0;

// Daily check guard: only fetch if cloud stamp is new AND recent
const Duration kFreshCloudStampMaxAge = Duration(hours: 6);

final GlobalKey<ScaffoldMessengerState> messengerKey =
GlobalKey<ScaffoldMessengerState>();

// Navigator key for a safe top‑level BuildContext after first frame
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

// Background FCM handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  await FirebaseAppCheck.instance.activate(
    providerAndroid:
    kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
    providerApple:
    kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
  );
  final repo = PrayerTimesRepository();
  final shouldRefresh = message.data['updatePrayerTimes'] == 'true';
  final yearStr = message.data['year'];
  final year = (yearStr != null) ? int.tryParse(yearStr) : null;
  if (shouldRefresh) {
    await repo.refreshFromFirebase(year: year);
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    BindingBase.debugZoneErrorsAreFatal = true;
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // Enable detector logs if needed
    //IqamahChangeService.logEnabled = true;
    
    // Fonts are asset-only (never HTTP)
    GoogleFonts.config.allowRuntimeFetching = false;

    // Firebase init + App Check
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
      kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      providerApple:
      kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
    );

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };

    // Prefs & Theme
    await UXPrefs.init();
    await ThemeController.init();

    // Cloud Hijri override (uses real resolver)
    await HijriOverrideService.applyIfPresent(resolveAppHijri: _appHijri);

    // Local notifications scheduler
    await AlertsScheduler.instance.init(androidSmallIcon: 'ic_stat_bell');

    // iOS: present notifications while app is in foreground
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    runApp(const BootstrapApp());

    // Post-frame must be sync; kick off async work via helper
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_postFrameAsync());
    });
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught async error: $error\n$stack');
  });
}

// Async work after first frame (warm-ups + deferred topic subscription)
Future<void> _postFrameAsync() async {
  final ctx = navKey.currentContext;
  if (ctx != null) {
    await warmUpAboveTheFold(ctx);
  }
  // Slightly increase image cache to avoid early evictions of small assets
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = (cache.maximumSize * 1.3).round();

  // Defer FCM permission + topic subscription ~1.2s after first paint
  unawaited(Future<void>.delayed(const Duration(milliseconds: 1200)).then((_) async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      debugPrint('FCM permission (deferred): ${settings.authorizationStatus}');
      await FirebaseMessaging.instance.subscribeToTopic('allUsers');
    } catch (e, st) {
      debugPrint('Deferred FCM setup error: $e\n$st');
    }
  }));
}

// ---------------- Light Color Scheme ----------------
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

const LinearGradient pageGradientLight = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF6F9FC), Color(0xFFFFFFFF)],
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
  static const dark = AppGradients(page: AppColors.pageGradient);
}

// ---------------- Bootstrap App ----------------
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
            // Build Manrope-based text theme using ASSET fonts registered in pubspec.yaml
            final TextTheme baseLatin =
            GoogleFonts.manropeTextTheme(ThemeData(brightness: Brightness.light).textTheme)
                .copyWith(
              titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            );
            const arabicFallback = ['IBM Plex Sans Arabic', 'Noto Sans Arabic'];

            TextTheme addFallbacks(TextTheme t) => t.copyWith(
              bodySmall: t.bodySmall ?.copyWith(fontFamilyFallback: arabicFallback),
              bodyMedium: t.bodyMedium ?.copyWith(fontFamilyFallback: arabicFallback),
              bodyLarge: t.bodyLarge ?.copyWith(fontFamilyFallback: arabicFallback),
              titleSmall: t.titleSmall ?.copyWith(fontFamilyFallback: arabicFallback),
              titleMedium: t.titleMedium ?.copyWith(fontFamilyFallback: arabicFallback),
              titleLarge: t.titleLarge ?.copyWith(fontFamilyFallback: arabicFallback),
              labelSmall: t.labelSmall ?.copyWith(fontFamilyFallback: arabicFallback),
              labelMedium: t.labelMedium ?.copyWith(fontFamilyFallback: arabicFallback),
              labelLarge: t.labelLarge ?.copyWith(fontFamilyFallback: arabicFallback),
              displaySmall: t.displaySmall ?.copyWith(fontFamilyFallback: arabicFallback),
              displayMedium:t.displayMedium?.copyWith(fontFamilyFallback: arabicFallback),
              displayLarge: t.displayLarge ?.copyWith(fontFamilyFallback: arabicFallback),
              headlineSmall:t.headlineSmall?.copyWith(fontFamilyFallback: arabicFallback),
              headlineMedium:t.headlineMedium?.copyWith(fontFamilyFallback: arabicFallback),
              headlineLarge:t.headlineLarge?.copyWith(fontFamilyFallback: arabicFallback),
            );

            final TextTheme chosenLight = addFallbacks(baseLatin);
            final TextTheme chosenDark  = addFallbacks(baseLatin);

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
                iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              extensions: const <ThemeExtension<dynamic>>[
                AppGradients.light,
              ],
            );

            final ThemeData baseDark = ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.bgPrimary,
              textTheme: chosenDark,
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: AppColors.bgPrimary,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.70),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              extensions: const <ThemeExtension<dynamic>>[
                AppGradients.dark,
              ],
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
              builder: (context, child) {
                return ValueListenableBuilder<double>(
                  valueListenable: UXPrefs.textScale,
                  builder: (context, scale, _) {
                    final mq = MediaQuery.of(context);
                    return Directionality(
                      textDirection: TextDirection.ltr,
                      child: MediaQuery(
                        data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!,
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

// ---------------- Bootstrap Screen ----------------
class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();
  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> with WidgetsBindingObserver {
  late Future<_InitResult> _initFuture;
  final PrayerTimesRepository _repo = PrayerTimesRepository();
  Timer? _midnightTimer;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Once per day (first foreground after midnight), do a cheap metadata peek
    if (state == AppLifecycleState.resumed) {
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
          // Post-frame: maybe show heads-up / night-before prompts
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
        return const SizedBox.shrink();
      },
    );
  }

  Future<_InitResult> _initializeAll() async {
    // Timezone init (central time)
    tz.Location location;
    try {
      location = await initCentralTime();
    } catch (_) {
      location = tz.getLocation('America/Chicago');
    }

    // Pull latest prayer times from Firebase (best‑effort) once at startup
    try {
      final updated = await _repo.refreshFromFirebase(year: DateTime.now().year);
      debugPrint('Startup refresh: ${updated ? 'updated from Firebase' : 'no remote / kept local'}');

      // Discreet update SnackBar — only once per 'lastUpdated' and only if fresh (<= 2 min)
      if (updated) {
        final meta = await _repo.readMeta();
        final whenStr = (meta?['lastUpdated'] ?? '') as String;
        final when = DateTime.tryParse(whenStr)?.toLocal();

        final isFresh = when != null &&
            DateTime.now().difference(when) <= const Duration(minutes: 2);

        final lastShown = await UXPrefs.getString(_kLastShownUpdatedAt);

        if (isFresh && whenStr.isNotEmpty && whenStr != lastShown) {
          messengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Prayer times updated'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await UXPrefs.setString(_kLastShownUpdatedAt, whenStr);
          await UXPrefs.setString(_kLastCloudStamp, whenStr); // record baseline
        }
      }
    } catch (e, st) {
      debugPrint('Startup refresh error: $e\n$st');
    }

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
    final PrayerDay today =
        _findByDate(days, todayDate) ??
            (days.isNotEmpty ? days.first : _dummyDay(todayDate));
    final tomorrowDate = todayDate.add(const Duration(days: 1));
    final PrayerDay? tomorrow = _findByDate(days, tomorrowDate);

    // Weather (non‑blocking)
    final coords = _coordsForLocation(location);
    final double? currentTempF = await _fetchTemperatureF(
      latitude: coords.lat,
      longitude: coords.lon,
    ).timeout(const Duration(seconds: 5), onTimeout: () => null);

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

  // ---- Daily cloud metadata peek ----
  Future<void> _maybeDailyCloudCheck() async {
    try {
      // only once per day
      final todayYMD = _ymd(DateTime.now());
      final lastYMD = await UXPrefs.getString(_kLastDailyCheckYMD);
      if (lastYMD == todayYMD) return;

      await UXPrefs.setString(_kLastDailyCheckYMD, todayYMD);

      final year = DateTime.now().year;

      // Peek metadata (no content download)
      final ref = FirebaseStorage.instance.ref('prayer_times/$year.json');
      FullMetadata meta;
      try {
        meta = await ref.getMetadata();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          // nothing in cloud → keep using local, do nothing
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
      final isRecent = DateTime.now().difference(stamp.toLocal()) <= kFreshCloudStampMaxAge;
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
        final when = DateTime.tryParse(whenStr)?.toLocal();
        final isFresh = when != null &&
            DateTime.now().difference(when) <= const Duration(minutes: 2);
        final lastShown = await UXPrefs.getString(_kLastShownUpdatedAt);

        if (isFresh && whenStr.isNotEmpty && whenStr != lastShown) {
          messengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Prayer times updated'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await UXPrefs.setString(_kLastShownUpdatedAt, whenStr);
        }
        await UXPrefs.setString(_kLastCloudStamp, stamp.toUtc().toIso8601String());
        debugPrint('[DailyCheck] updated from cloud.');
      } else {
        debugPrint('[DailyCheck] metadata newer but refresh failed → try tomorrow.');
      }
    } catch (e, st) {
      debugPrint('Daily cloud check error: $e\n$st');
    }
  }

  // ---- Local alerts scheduling
  Future<void> _scheduleLocalAlerts({
    required DateTime nowLocal,
    required PrayerDay today,
  }) async {
    final status = await NotificationOptInService.getStatus();
    final authorized = NotificationOptInService.isAuthorized(status);
    if (!authorized) {
      if (kDebugMode) {
        debugPrint('[Alerts] Skipped scheduling: permission not granted');
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
    final fajrAdhan = mkTime(base, today.prayers['fajr']?.begin ?? '');
    final dhuhrAdhan = mkTime(base, today.prayers['dhuhr']?.begin ?? '');
    final asrAdhan = mkTime(base, today.prayers['asr']?.begin ?? '');
    final maghribAdhan = mkTime(base, today.prayers['maghrib']?.begin ?? '');
    final ishaAdhan = mkTime(base, today.prayers['isha']?.begin ?? '');
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

  // ---- Iqamah change prompt helpers (unified sheet)
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
      'fajr': PrayerTime(begin: begin, iqamah: ''),
      'dhuhr': PrayerTime(begin: begin, iqamah: ''),
      'asr': PrayerTime(begin: begin, iqamah: ''),
      'maghrib': PrayerTime(begin: begin, iqamah: ''),
      'isha': PrayerTime(begin: begin, iqamah: ''),
    };
    return PrayerDay(
      date: date,
      prayers: prayers,
      sunrise: begin,
      sunset: begin,
      serial: 0,
    );
  }
}

// ---------------- Result wrapper ----------------
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

// ---------------- Splash ----------------
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

// ---------------- Navigation (HomeTabs) ----------------
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

class _HomeTabsState extends State<HomeTabs> with WidgetsBindingObserver {
  int _index = 0;
  bool hasNewAnnouncement = false;

  static const _kAnnSeenFp = 'ux.ann.lastSeenFp';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // FCM "nudge" path — the ONLY way we light the dot (no polling).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['newAnnouncement'] == 'true') {
        setState(() => hasNewAnnouncement = true);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (m.data['newAnnouncement'] == 'true') {
        setState(() { _index = 1; hasNewAnnouncement = false; });
      }
    });
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m?.data['newAnnouncement'] == 'true') {
        setState(() { _index = 1; hasNewAnnouncement = false; });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // event-driven; no RC polling for announcements
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            // Optional: reset "seen" when leaving the notifications tab
            if (_index == 1 && i != 1) {
              await UXPrefs.setString(_kAnnSeenFp, null);
            }

            setState(() {
              _index = i;
              if (i == 1) hasNewAnnouncement = false; // clear dot when opening tab
            });
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
                          color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
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
                          color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),

            const NavigationDestination(label: '', icon: FaIcon(FontAwesomeIcons.instagram, size: 20)),
            const NavigationDestination(label: '', icon: FaIcon(FontAwesomeIcons.addressBook, size: 20)),
            const NavigationDestination(label: '', icon: Icon(Icons.more_horiz)),
          ],
        ),
      ),
    );
  }
}

// ---- Helpers (coords & weather)
class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
}

LatLon _coordsForLocation(tz.Location location) {
  final locationName = location.name.toLowerCase();
  if (locationName.contains('america/chicago')) {
    return const LatLon(33.0354, -97.0830);
  }
  return const LatLon(33.0354, -97.0830);
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
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final cw = data['current_weather'] as Map<String, dynamic>?;
      final t = cw?['temperature'];
      if (t is num) return t.toDouble();
    } else {
      debugPrint('Weather HTTP ${resp.statusCode}: ${resp.body}');
    }
  } catch (e, st) {
    debugPrint('Weather fetch error: $e\n$st');
  }
  return null;
}

// ---- Hijri resolver
Future<HijriYMD> _appHijri(DateTime g) async {
  final h = HijriCalendar.fromDate(g);
  return HijriYMD(h.hYear, h.hMonth, h.hDay);
}