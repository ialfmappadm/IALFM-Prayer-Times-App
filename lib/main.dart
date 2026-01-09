
// lib/main.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'models.dart';               // loadPrayerDays(), PrayerDay, PrayerTime
import 'pages/prayer_page.dart';    // your existing page
import 'utils/time_utils.dart';     // initCentralTime()

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface Flutter framework errors as visible red screens + log
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Catch uncaught async errors (e.g., Future errors outside widgets)
  runZonedGuarded(() {
    // Render FIRST FRAME immediately; do heavy work in the background.
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
      theme: base.copyWith(textTheme: textTheme),
      home: const _BootstrapScreen(),
      // Handy in debug to confirm frames paint; set to false for production
      showPerformanceOverlay: kDebugMode ? false : false,
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

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeAll();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InitResult>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          final r = snap.data!;
          return PrayerTimesApp(
            location: r.location,
            nowLocal: r.nowLocal,
            today: r.today,
            tomorrow: r.tomorrow,
            temperatureF: r.temperatureF,
          );
        }

        if (snap.hasError) {
          return _SplashScaffold(
            title: 'Starting up…',
            subtitle: 'Something went wrong:\n${snap.error}',
            onRetry: () => setState(() => _initFuture = _initializeAll()),
          );
        }

        // Splash/loading while we initialize.
        return const _SplashScaffold(
          title: 'Starting up…',
          subtitle: 'Preparing prayer times and settings',
        );
      },
    );
  }
}

class _SplashScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const _SplashScaffold({super.key, required this.title, this.subtitle, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Explicit white so the device never looks “black” while loading
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

Future<_InitResult> _initializeAll() async {
  // 1) Firebase (guarded)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized.');
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  // 2) Timezone & data (guarded to avoid startup crash)
  tz.Location location;
  try {
    location = await initCentralTime();
  } catch (e, st) {
    debugPrint('Timezone init error: $e\n$st');
    location = tz.getLocation('America/Chicago'); // fallback
  }

  List<PrayerDay> days;
  try {
    days = await loadPrayerDays();
  } catch (e, st) {
    debugPrint('loadPrayerDays() error: $e\n$st');
    days = <PrayerDay>[];
  }

  final nowLocal = DateTime.now();
  final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final PrayerDay today =
      _findByDate(days, todayDate) ?? (days.isNotEmpty ? days.first : _dummyDay(todayDate));

  final tomorrowDate = todayDate.add(const Duration(days: 1));
  final PrayerDay? tomorrow = _findByDate(days, tomorrowDate);

  // 3) Weather with timeout (avoid long waits at startup)
  final coords = _coordsForLocation(location);
  final double? currentTempF = await _fetchTemperatureF(
    latitude: coords.lat,
    longitude: coords.lon,
  ).timeout(const Duration(seconds: 5), onTimeout: () {
    debugPrint('Weather fetch timed out; starting without temperature.');
    return null;
  });

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

// ✅ Fallback that matches your PrayerDay/PrayerTime model exactly.
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
    sunrise: begin,  // placeholder strings
    sunset: begin,
    serial: 0,
  );
}

class PrayerTimesApp extends StatelessWidget {
  final tz.Location location;
  final DateTime nowLocal;
  final PrayerDay today;
  final PrayerDay? tomorrow;
  final double? temperatureF;

  const PrayerTimesApp({
    super.key,
    required this.location,
    required this.nowLocal,
    required this.today,
    required this.tomorrow,
    required this.temperatureF,
  });

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
      theme: base.copyWith(textTheme: textTheme),
      home: HomeTabs(
        location: location,
        nowLocal: nowLocal,
        today: today,
        tomorrow: tomorrow,
        temperatureF: temperatureF,
      ),
    );
  }
}

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
      const Center(child: Text('Announcements tab coming soon')),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: ''),
        ],
      ),
    );
  }
}

/// Small helper for coordinates based on timezone location.
class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
}

LatLon _coordsForLocation(tz.Location location) {
  final lname = location.name.toLowerCase();
  if (lname.contains('america/chicago')) {
    return const LatLon(33.0354, -97.0830); // IALFM, FLOMO
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