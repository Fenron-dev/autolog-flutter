import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;

// ─── Events ──────────────────────────────────────────────────────────────────

sealed class AutoDetectEvent {}

class TripStartDetected extends AutoDetectEvent {
  final String source; // 'gps' | 'bluetooth'
  final String startDate; // ISO yyyy-MM-dd
  final String startTime; // HH:mm
  final bool autoRecord;
  TripStartDetected({
    required this.source,
    required this.startDate,
    required this.startTime,
    required this.autoRecord,
  });
}

class TripEndDetected extends AutoDetectEvent {
  final String source;
  final String endTime; // HH:mm
  final double distanceKm;
  TripEndDetected({
    required this.source,
    required this.endTime,
    required this.distanceKm,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class AutoDetectService {
  AutoDetectService._();
  static final instance = AutoDetectService._();

  final _events = StreamController<AutoDetectEvent>.broadcast();
  Stream<AutoDetectEvent> get events => _events.stream;

  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<BluetoothConnectionState>? _btSub;

  bool _inTrip = false;
  DateTime? _movingSince;
  DateTime? _tripStartedAt;
  double _accumulatedDistanceM = 0;
  Position? _lastPosition;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> startMonitoring(AppSettings settings) async {
    await stopMonitoring();
    if (settings.speedDetectionEnabled) {
      await _startGps(settings);
    }
    if (settings.bluetoothDetectionEnabled) {
      await _startBluetooth(settings);
    }
  }

  Future<void> stopMonitoring() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _btSub?.cancel();
    _btSub = null;
    _reset();
  }

  Future<void> restartMonitoring(AppSettings settings) async {
    await startMonitoring(settings);
  }

  void dispose() {
    stopMonitoring();
    _events.close();
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _startGps(AppSettings settings) async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'AutoLog überwacht Fahrten im Hintergrund',
        notificationTitle: 'AutoLog – Fahrtenerkennung aktiv',
        enableWakeLock: true,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      ),
    );

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: androidSettings,
    ).listen(
      (pos) => _handlePosition(pos, settings),
      onError: (_) {},
    );
  }

  void _handlePosition(Position pos, AppSettings settings) {
    final speedKmh = (pos.speed < 0 ? 0 : pos.speed) * 3.6;
    final now = DateTime.now();

    if (speedKmh >= settings.speedThresholdKmh) {
      // Accumulate distance if in trip
      if (_lastPosition != null && _inTrip) {
        _accumulatedDistanceM += Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
      }
      _lastPosition = pos;

      _movingSince ??= now;
      final movingDuration = now.difference(_movingSince!);

      // Start trip after 30 seconds above threshold
      if (!_inTrip && movingDuration.inSeconds >= 30) {
        _inTrip = true;
        _tripStartedAt = _movingSince;
        _accumulatedDistanceM = 0;
        _events.add(TripStartDetected(
          source: 'gps',
          startDate: du.todayIso(),
          startTime: _formatTime(_tripStartedAt!),
          autoRecord: settings.speedAutoRecord,
        ));
      }
    } else {
      // Below threshold
      if (_movingSince != null) {
        final slowDuration = now.difference(_lastPosition?.timestamp ?? now);
        // End trip after being slow for 2 minutes
        if (_inTrip && slowDuration.inSeconds >= 120) {
          _endTrip('gps');
        } else if (!_inTrip) {
          _movingSince = null;
        }
      }
    }
  }

  // ── Bluetooth ─────────────────────────────────────────────────────────────

  Future<void> _startBluetooth(AppSettings settings) async {
    if (settings.bluetoothDeviceAddress.isEmpty) return;

    try {
      final bonded = await FlutterBluePlus.bondedDevices;
      final target = bonded.where(
        (d) => d.remoteId.str == settings.bluetoothDeviceAddress,
      ).firstOrNull;

      if (target == null) return;

      _btSub = target.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected && !_inTrip) {
          _inTrip = true;
          _tripStartedAt = DateTime.now();
          _accumulatedDistanceM = 0;
          _events.add(TripStartDetected(
            source: 'bluetooth',
            startDate: du.todayIso(),
            startTime: _formatTime(_tripStartedAt!),
            autoRecord: settings.bluetoothAutoRecord,
          ));
        } else if (state == BluetoothConnectionState.disconnected && _inTrip) {
          _endTrip('bluetooth');
        }
      });
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _endTrip(String source) {
    final distanceKm = _accumulatedDistanceM / 1000.0;
    _events.add(TripEndDetected(
      source: source,
      endTime: _formatTime(DateTime.now()),
      distanceKm: distanceKm,
    ));
    _reset();
  }

  void _reset() {
    _inTrip = false;
    _movingSince = null;
    _tripStartedAt = null;
    _accumulatedDistanceM = 0;
    _lastPosition = null;
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
