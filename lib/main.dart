// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode

// Keep native splash until initialization completes (prevents double splash).
// Docs: preserve/remove API.
// - Plugin docs: https://pub.dev/packages/flutter_native_splash
// - Android 12 migration guidance: https://developer.android.com/develop/ui/views/launch/splash-screen/migrate
import 'package:flutter_native_splash/flutter_native_splash.dart'; // ONE splash flow
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// App Check (new API accepts provider instances via providerAndroid/providerApple).
// See Dart API signature and Firebase docs.
import 'package:firebase_app_check/firebase_app_check.dart';

import 'models.dart'; // loadPrayerDays(), PrayerDay, PrayerTime
import 'pages/prayer_page.dart';
import 'utils/time_utils.dart';
import 'widgets/announcements_tab.dart';
import 'prayer_times_firebase.dart';

// ---- TWEAK THESE SIZES ----
const double kNavIconSize = 30.0; // Icon size (selected icon adds +3)
const double kNavBarHeight = 72.0; // Bottom NavigationBar height

// GLOBAL: ScaffoldMessenger key for app-wide SnackBars
final GlobalKey<ScaffoldMessengerState> messengerKey =
GlobalKey<ScaffoldMessengerState>();

/// Background FCM: init Firebase, App Check, then refresh local file if instructed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  // NEW API: use provider instances, not the old enums.
  // In debug builds, use Debug providers; in release, production providers.
  // (See Dart API signature defaults and Firebase docs.)
  await FirebaseAppCheck.instance.activate(
    providerAndroid:
    kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
    providerApple:
    kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
  ); // [1](https://www.b4x.com/android/forum/threads/solved-how-to-implement-theme-materialcomponents-daynight.137708/)[2](https://github.com/shafayathossain/AnimatedSplashScreen)

  final repo = PrayerTimesRepository();
  final shouldRefresh = message.data['updatePrayerTimes'] == 'true';
  final yearStr = message.data['year'];
  final year = (yearStr != null) ? int.tryParse(yearStr) : null;
  if (shouldRefresh) {
    await repo.refreshFromFirebase(year: year);
  }
}

Future<void> main() async {
  // IMPORTANT: Keep native splash while we initialize—prevents “double splash”.
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding); // ONE splash

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background handler ONCE at startup
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // App Check (NEW API with provider instances).
  await FirebaseAppCheck.instance.activate(
    providerAndroid:
    kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
    providerApple:
    kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
  ); // [1](https://www.b4x.com/android/forum/threads/solved-how-to-implement-theme-materialcomponents-daynight.137708/)

  // Optional error hook
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  runZonedGuarded(() {
    runApp(const BootstrapApp());
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught async error: $error\n$stack');
  });
}

class BootstrapApp extends StatelessWidget {
  const BootstrapApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      useMaterial3: true,
    );
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      bodyMedium: GoogleFonts.manrope(),
      bodyLarge: GoogleFonts.manrope(),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prayer Times',
      theme: base.copyWith(
        textTheme: textTheme,
        navigationBarTheme: const NavigationBarThemeData(
          // Remove the pill by making indicator transparent
          indicatorColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      scaffoldMessengerKey: messengerKey,
      home: const _BootstrapScreen(),
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

  // schedule a daily refresh at local midnight so today/tomorrow stay current.
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();

    _initFuture = _initializeAll();

    // When initialization is finished (success or error), drop the native splash.
    _initFuture.whenComplete(() {
      if (mounted) FlutterNativeSplash.remove(); // ONE splash
    }); // [3](https://dev.to/programmerhasan/adding-a-splash-screen-to-your-flutter-app-with-flutternativesplash-32kn)[4](https://www.daniweb.com/programming/mobile-development/tutorials/537009/android-native-how-to-add-material-3-top-app-bar)

    _scheduleMidnightRefresh();

    // Foreground FCM -> refresh Storage -> rebuild UI
    FirebaseMessaging.onMessage.listen((m) async {
      if (m.data['updatePrayerTimes'] == 'true') {
        final yearStr = m.data['year'];
        final year = (yearStr != null) ? int.tryParse(yearStr) : null;
        final ok = await _repo.refreshFromFirebase(year: year);
        if (!mounted) return;
        if (ok) {
          setState(() {
            _initFuture = _initializeAll(); // re-read from disk -> rebuild UI
          });
          messengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Prayer times updated')),
          );
        }
      }
    });
  }

  // compute delay to next local midnight and refresh then.
  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _initFuture = _initializeAll(); // pick new today/tomorrow
      });
      // schedule again for the next day
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
          // Ensure native splash is removed if we reached error.
          FlutterNativeSplash.remove();
          return _SplashScaffold(
            key: const ValueKey('bootstrap_error'), // fixes analyzer warning
            title: 'Starting up…',
            subtitle: 'Error:\n${snap.error}',
            onRetry: () => setState(() => _initFuture = _initializeAll()),
          );
        }

        // While waiting, draw nothing—native splash is still visible.
        return const SizedBox.shrink();
      },
    );
  }

  Future<_InitResult> _initializeAll() async {
    // FCM permissions / topic subscription
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');
      await FirebaseMessaging.instance.subscribeToTopic('allUsers');
    } catch (e, st) {
      debugPrint('FCM setup error: $e\n$st');
    }

    // Timezone
    tz.Location location;
    try {
      location = await initCentralTime();
    } catch (_) {
      location = tz.getLocation('America/Chicago');
    }

    // Best-effort refresh from Firebase at startup (fallback to local if missing)
    try {
      final ok = await _repo.refreshFromFirebase(year: DateTime.now().year);
      debugPrint(
          'Startup refresh: ${ok ? 'updated from Firebase' : 'no remote / kept local'}');
    } catch (e, st) {
      debugPrint('Startup refresh error: $e\n$st');
    }

    // Load local canonical file (asset fallback) for current year
    final nowLocal = DateTime.now();
    List<PrayerDay> days;
    try {
      days = await loadPrayerDays(year: nowLocal.year);
    } catch (e, st) {
      debugPrint('loadPrayerDays() error: $e\n$st');
      days = <PrayerDay>[];
    }

    // Pick today / tomorrow from the list
    final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final PrayerDay today =
        _findByDate(days, todayDate) ?? (days.isNotEmpty ? days.first : _dummyDay(todayDate));
    final tomorrowDate = todayDate.add(const Duration(days: 1));
    final PrayerDay? tomorrow = _findByDate(days, tomorrowDate);

    // Weather
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

// --------------------------- NAVIGATION BAR ---------------------------
// (No pill, underline highlight)

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
  bool hasNewNotification = false;

  @override
  void initState() {
    super.initState();

    // Foreground: show badge only for announcement pings
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['newAnnouncement'] == 'true') {
        setState(() => hasNewNotification = true);
      }
    });

    // Background tap -> open Alerts (index 1)
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (m.data['newAnnouncement'] == 'true') {
        setState(() {
          _index = 1;
          hasNewNotification = false; // clear badge
        });
      }
    });

    // Cold start via tap -> open Alerts (index 1)
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m?.data['newAnnouncement'] == 'true') {
        setState(() {
          _index = 1;
          hasNewNotification = false; // clear badge
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
    ];
    return Scaffold(
      // Only show header on Notifications tab
      appBar: _index == 1 ? AppBar(title: const Text('Notifications')) : null,
      body: pages[_index],

      // Material 3 NavigationBar (indicator/pill removed via theme)
      bottomNavigationBar: NavigationBar(
        height: kNavBarHeight,
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
            if (i == 1) hasNewNotification = false; // clear badge when opening Alerts
          });
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            label: 'Prayer',
            icon: _NavUnderlineIcon(
              icon: Icons.access_time, active: false, size: kNavIconSize,
            ),
            selectedIcon: _NavUnderlineIcon(
              icon: Icons.access_time, active: true, size: kNavIconSize + 3,
            ),
          ),
          NavigationDestination(
            label: 'Alerts',
            icon: _NavUnderlineBellIcon(
              active: false, showBadge: hasNewNotification, size: kNavIconSize,
            ),
            selectedIcon: _NavUnderlineBellIcon(
              active: true, showBadge: hasNewNotification, size: kNavIconSize + 3,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Helpers: underline highlight (no pill)
class _NavUnderlineIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final double size;
  const _NavUnderlineIcon({
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
        Icon(icon, size: size),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 3, // underline thickness (try 4 for bolder)
          width: active ? 22 : 0, // underline length (try 26 for wider)
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _NavUnderlineBellIcon extends StatelessWidget {
  final bool active;
  final bool showBadge;
  final double size;
  const _NavUnderlineBellIcon({
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
            Icon(Icons.notifications, size: size),
            if (showBadge)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 3, // underline thickness
          width: active ? 22 : 0, // underline length
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// --------------------------- HELPERS ---------------------------

class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
}

LatLon _coordsForLocation(tz.Location location) {
  final locationName = location.name.toLowerCase(); // renamed from lname
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