
// lib/main.dart
// - Initializes bindings & runApp in the SAME zone.
// - Adds locale-aware text themes: Manrope (en) and Cairo (ar).
// - Preserves your Firebase/AppCheck, gradients, SnackBars, pages, and nav.

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

// Localization (built-in)
import 'package:flutter_localizations/flutter_localizations.dart';
import 'locale_controller.dart';

// Font Awesome
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// App files
import 'models.dart';
import 'pages/prayer_page.dart';
import 'utils/time_utils.dart';
import 'widgets/announcements_tab.dart';
import 'prayer_times_firebase.dart';
import 'pages/social_page.dart';
import 'pages/directory_page.dart';
import 'pages/more_page.dart';
import 'app_colors.dart';
import 'theme_controller.dart';

// GENERATED localizations (gen_l10n)
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

// ---- NAV TUNING ----
const double kNavIconSize = 18.0;
const double kNavBarHeight = 50.0;
final GlobalKey<ScaffoldMessengerState> messengerKey =
GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  await FirebaseAppCheck.instance.activate(
    providerAndroid:
    kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
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
  // Keep init and runApp in the SAME zone to prevent zone mismatch.
  runZonedGuarded(() async {
    BindingBase.debugZoneErrorsAreFatal = true;

    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
      kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
    );

    // Route Flutter framework errors into this zone too
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };

    runApp(const BootstrapApp());
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught async error: $error\n$stack');
  });
}

// -------------------- Light (Cool) ColorScheme --------------------
const ColorScheme lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0A2C42), // Navy
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD6E6F1),
  onPrimaryContainer: Color(0xFF0A2231),

  secondary: Color(0xFFC7A447), // Gold
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

// Light gradient to mirror the dark gradient feel
const LinearGradient pageGradientLight = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF6F9FC), Color(0xFFFFFFFF)],
);

// ---- ThemeExtension to carry a page gradient via Theme ----
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


// === REPLACE ONLY THE BootstrapApp CLASS IN lib/main.dart ===
class BootstrapApp extends StatelessWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: LocaleController.locale,
          builder: (context, appLocale, __) {
            // ---- Base UI text: always Manrope (protects English) ----
            final TextTheme baseLatin = GoogleFonts.manropeTextTheme().copyWith(
              titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              titleLarge:  GoogleFonts.manrope(fontWeight: FontWeight.w700),
              bodyMedium:  GoogleFonts.manrope(),
              bodyLarge:   GoogleFonts.manrope(),
            );

            // ---- ONE fallback chain for Arabic glyphs only ----
            // Order matters: IBM Plex Sans Arabic (crisp, neutral) → Noto Sans Arabic (broad support)
            const arabicFallback = ['IBM Plex Sans Arabic', 'Noto Sans Arabic'];

            TextTheme addFallbacks(TextTheme t) => t.copyWith(
              bodySmall:     t.bodySmall?.copyWith(fontFamilyFallback: arabicFallback),
              bodyMedium:    t.bodyMedium?.copyWith(fontFamilyFallback: arabicFallback),
              bodyLarge:     t.bodyLarge?.copyWith(fontFamilyFallback: arabicFallback),
              titleSmall:    t.titleSmall?.copyWith(fontFamilyFallback: arabicFallback),
              titleMedium:   t.titleMedium?.copyWith(fontFamilyFallback: arabicFallback),
              titleLarge:    t.titleLarge?.copyWith(fontFamilyFallback: arabicFallback),
              labelSmall:    t.labelSmall?.copyWith(fontFamilyFallback: arabicFallback),
              labelMedium:   t.labelMedium?.copyWith(fontFamilyFallback: arabicFallback),
              labelLarge:    t.labelLarge?.copyWith(fontFamilyFallback: arabicFallback),
              displaySmall:  t.displaySmall?.copyWith(fontFamilyFallback: arabicFallback),
              displayMedium: t.displayMedium?.copyWith(fontFamilyFallback: arabicFallback),
              displayLarge:  t.displayLarge?.copyWith(fontFamilyFallback: arabicFallback),
              headlineSmall: t.headlineSmall?.copyWith(fontFamilyFallback: arabicFallback),
              headlineMedium:t.headlineMedium?.copyWith(fontFamilyFallback: arabicFallback),
              headlineLarge: t.headlineLarge?.copyWith(fontFamilyFallback: arabicFallback),
            );

            final TextTheme chosenLight = addFallbacks(baseLatin);
            final TextTheme chosenDark  = addFallbacks(baseLatin);

            // ---- Light theme ----
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              extensions: const <ThemeExtension<dynamic>>[ AppGradients.light ],
            );

            // ---- Dark theme ----
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              extensions: const <ThemeExtension<dynamic>>[ AppGradients.dark ],
            );

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'IALFM',
              themeMode: mode,
              theme: baseLight,
              darkTheme: baseDark,
              scaffoldMessengerKey: messengerKey,

              // Localization (keep both locales)
              locale: appLocale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,

              // 🔒 GLOBAL LTR: prevents any page or bottom bar from mirroring
              builder: (context, child) => Directionality(
                textDirection: TextDirection.ltr,
                child: child!,
              ),

              home: const _BootstrapScreen(),
            );
          },
        );
      },
    );
  }
}


class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();
  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  late Future<_InitResult> _initFuture;
  final PrayerTimesRepository _repo = PrayerTimesRepository();
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeAll();
    _initFuture.whenComplete(() {
      if (mounted) FlutterNativeSplash.remove();
    });
    _scheduleMidnightRefresh();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Badge handled in HomeTabs
    });
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
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InitResult>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          final r = snap.data!;
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
            title: 'Starting up…',
            subtitle: 'Error:\n${snap.error}',
            onRetry: () => setState(() => _initFuture = _initializeAll()),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<_InitResult> _initializeAll() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');
      await FirebaseMessaging.instance.subscribeToTopic('allUsers');
    } catch (e, st) {
      debugPrint('FCM setup error: $e\n$st');
    }

    tz.Location location;
    try {
      location = await initCentralTime();
    } catch (_) {
      location = tz.getLocation('America/Chicago');
    }

    try {
      final ok = await _repo.refreshFromFirebase(year: DateTime.now().year);
      debugPrint('Startup refresh: ${ok ? 'updated from Firebase' : 'no remote / kept local'}');
    } catch (e, st) {
      debugPrint('Startup refresh error: $e\n$st');
    }

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
        _findByDate(days, todayDate) ?? (days.isNotEmpty ? days.first : _dummyDay(todayDate));
    final tomorrowDate = todayDate.add(const Duration(days: 1));
    final PrayerDay? tomorrow = _findByDate(days, tomorrowDate);

    final coords = _coordsForLocation(location);
    final double? currentTempF = await _fetchTemperatureF(
      latitude: coords.lat,
      longitude: coords.lon,
    ).timeout(const Duration(seconds: 5), onTimeout: () => null);

    return _InitResult(
      location: location,
      nowLocal: nowLocal,
      today: today,
      tomorrow: tomorrow,
      temperatureF: currentTempF,
    );
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

class _InitResult {
  final tz.Location location;
  final DateTime nowLocal;
  final PrayerDay today;
  final PrayerDay? tomorrow;
  final double? temperatureF;
  _InitResult({
    required this.location,
    required this.nowLocal,
    required this.today,
    required this.tomorrow,
    required this.temperatureF,
  });
}

class _SplashScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  const _SplashScaffold({super.key, required this.title, this.subtitle, this.onRetry});
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

// ------------------------ NAVIGATION BAR ------------------------
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

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;
  bool hasNewAnnouncement = false;

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['newAnnouncement'] == 'true') {
        setState(() => hasNewAnnouncement = true);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (m.data['newAnnouncement'] == 'true') {
        setState(() {
          _index = 1;
          hasNewAnnouncement = false;
        });
      }
    });
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m?.data['newAnnouncement'] == 'true') {
        setState(() {
          _index = 1;
          hasNewAnnouncement = false;
        });
      }
    });
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
      bottomNavigationBar: NavigationBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: kNavBarHeight,
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
            if (i == 1) hasNewAnnouncement = false;
          });
        },
        destinations: [
          NavigationDestination(
            label: '',
            icon: _NavUnderlineFaIcon(
              icon: FontAwesomeIcons.clock,
              active: false,
              size: kNavIconSize,
            ),
            selectedIcon: _NavUnderlineFaIcon(
              icon: FontAwesomeIcons.clock,
              active: true,
              size: kNavIconSize + 2,
            ),
          ),
          NavigationDestination(
            label: '',
            icon: _NavUnderlineFaBadgeIcon(
              icon: FontAwesomeIcons.bullhorn,
              active: false,
              showBadge: hasNewAnnouncement,
              size: kNavIconSize,
            ),
            selectedIcon: _NavUnderlineFaBadgeIcon(
              icon: FontAwesomeIcons.bullhorn,
              active: true,
              showBadge: hasNewAnnouncement,
              size: kNavIconSize + 2,
            ),
          ),
          NavigationDestination(
            label: '',
            icon: _NavUnderlineFaIcon(
              icon: FontAwesomeIcons.hashtag,
              active: false,
              size: kNavIconSize,
            ),
            selectedIcon: _NavUnderlineFaIcon(
              icon: FontAwesomeIcons.hashtag,
              active: true,
              size: kNavIconSize + 2,
            ),
          ),
          NavigationDestination(
            label: '',
            icon: _NavUnderlineFaIcon(
              icon: FontAwesomeIcons.addressBook,
              active: false,
              size: kNavIconSize,
            ),
            selectedIcon: _NavUnderlineFaIcon(
              icon: FontAwesomeIcons.addressBook,
              active: true,
              size: kNavIconSize + 2,
            ),
          ),
          NavigationDestination(
            label: '',
            icon: _NavUnderlineFaIcon(
              icon: FontAwesomeIcons.ellipsis,
              active: false,
              size: kNavIconSize,
            ),
            selectedIcon: _NavUnderlineFaIcon(
              icon: FontAwesomeIcons.ellipsis,
              active: true,
              size: kNavIconSize + 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Underline helpers (subtle) ----
class _NavUnderlineFaIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final double size;
  const _NavUnderlineFaIcon({
    required this.icon,
    required this.active,
    required this.size,
  });
  @override
  Widget build(BuildContext context) {
    final Color lineColor =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icon, size: size),
        const SizedBox(height: 3),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 1.5,
          width: active ? 14 : 0,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _NavUnderlineFaBadgeIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool showBadge;
  final double size;
  const _NavUnderlineFaBadgeIcon({
    required this.icon,
    required this.active,
    required this.showBadge,
    required this.size,
  });
  @override
  Widget build(BuildContext context) {
    final Color lineColor =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            FaIcon(icon, size: size),
            if (showBadge)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 2,
          width: active ? 18 : 0,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// ---- HELPERS (coords & weather) ----
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
