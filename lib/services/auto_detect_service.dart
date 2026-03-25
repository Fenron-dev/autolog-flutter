import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;
import 'notification_service.dart';

// ─── Events ──────────────────────────────────────────────────────────────────

sealed class AutoDetectEvent {}

class TripStartDetected extends AutoDetectEvent {
  final String source; // 'gps' | 'bluetooth' | 'manual'
  final String startDate; // ISO yyyy-MM-dd
  final String startTime; // HH:mm
  final bool autoRecord;
  final double? startLat;
  final double? startLng;
  TripStartDetected({
    required this.source,
    required this.startDate,
    required this.startTime,
    required this.autoRecord,
    this.startLat,
    this.startLng,
  });
}

/// Emitted when trip seems to have paused (e.g. traffic light, traffic jam).
/// UI should show a dialog or the notification already asked the user.
class TripPauseDetected extends AutoDetectEvent {
  final String source;
  TripPauseDetected({required this.source});
}

class TripEndDetected extends AutoDetectEvent {
  final String source;
  final String endTime; // HH:mm
  final double distanceKm;
  final double? endLat;
  final double? endLng;
  TripEndDetected({
    required this.source,
    required this.endTime,
    required this.distanceKm,
    this.endLat,
    this.endLng,
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
  StreamSubscription<List<ScanResult>>? _btScanSub;
  StreamSubscription<String>? _notifActionSub;
  Timer? _btScanTimer;
  Timer? _gpsStopTimer;
  Timer? _autoEndTimer;

  bool _inTrip = false;
  bool _isPaused = false; // waiting for user decision (pause vs end)
  String? _tripSource; // 'gps' | 'bluetooth' | 'manual'
  DateTime? _movingSince;
  DateTime? _belowThresholdSince;
  DateTime? _tripStartedAt;
  double _accumulatedDistanceM = 0;
  Position? _lastPosition;
  Position? _startPosition; // GPS position at trip start

  String _btTargetAddress = '';

  /// Whether a trip is currently in progress (for UI state).
  bool get inTrip => _inTrip;
  bool get isPaused => _isPaused;
  String? get tripSource => _tripSource;

  // ── Public API ────────────────────────────────────────────────────────────

  bool _isStarting = false;

  Future<void> startMonitoring(AppSettings settings) async {
    if (_isStarting) return; // Prevent overlapping start calls
    _isStarting = true;
    await stopMonitoring();
    // Listen for notification button presses (Resume / End Trip)
    _notifActionSub = NotificationService.instance.actions.listen(_handleNotificationAction);

    if (settings.speedDetectionEnabled) {
      await _startGps(settings);
    }
    if (settings.bluetoothDetectionEnabled) {
      await _startBluetooth(settings);
    }
    _isStarting = false;
  }

  Future<void> stopMonitoring() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    _gpsStopTimer?.cancel();
    _gpsStopTimer = null;
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
    await _btSub?.cancel();
    _btSub = null;
    await _btScanSub?.cancel();
    _btScanSub = null;
    _btScanTimer?.cancel();
    _btScanTimer = null;
    await _notifActionSub?.cancel();
    _notifActionSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _reset();
  }

  Future<void> restartMonitoring(AppSettings settings) async {
    await startMonitoring(settings);
  }

  /// Called when user taps "Weiterfahrt" in the pause dialog/notification.
  void resumeTrip() {
    if (!_inTrip || !_isPaused) return;
    _isPaused = false;
    _belowThresholdSince = null;
    _gpsStopTimer?.cancel();
    _gpsStopTimer = null;
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
    // Show ongoing notification again
    NotificationService.instance.showTripStarted(_tripSource ?? 'gps');
  }

  /// Called when user taps "Fahrt beenden" in the pause dialog/notification.
  void confirmEndTrip() {
    if (!_inTrip) return;
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
    _endTrip(_tripSource ?? 'gps');
  }

  /// Start a trip manually (user pressed "Aufzeichnung starten" button).
  Future<void> startManualTrip() async {
    if (_inTrip) return;

    // Try to get current position for start coordinates
    Position? pos;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {}

    _inTrip = true;
    _isPaused = false;
    _tripSource = 'manual';
    _tripStartedAt = DateTime.now();
    _accumulatedDistanceM = 0;
    _startPosition = pos;
    _lastPosition = pos;

    _events.add(TripStartDetected(
      source: 'manual',
      startDate: du.todayIso(),
      startTime: _formatTime(_tripStartedAt!),
      autoRecord: true,
      startLat: pos?.latitude,
      startLng: pos?.longitude,
    ));
    NotificationService.instance.showTripStarted('manual');

    // If GPS speed detection is not already running, start a lightweight
    // position stream so we can track distance for manual trips too.
    if (_gpsSub == null) {
      _startManualGpsTracking();
    }
  }

  void _startManualGpsTracking() async {
    // Cancel any existing GPS subscription before creating a new one
    await _gpsSub?.cancel();
    _gpsSub = null;
    try {
      final androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // for manual, 10m is fine (saves battery)
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'AutoLog zeichnet Fahrt auf',
          notificationTitle: 'AutoLog – Manuelle Aufzeichnung',
          enableWakeLock: true,
          notificationIcon:
              AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      );
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: androidSettings,
      ).listen((pos) {
        if (_lastPosition != null && _inTrip) {
          _accumulatedDistanceM += Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            pos.latitude,
            pos.longitude,
          );
        }
        _lastPosition = pos;
      }, onError: (_) {});
    } catch (_) {}
  }

  void dispose() {
    stopMonitoring();
    _events.close();
  }

  // ── Notification actions ────────────────────────────────────────────────

  void _handleNotificationAction(String actionId) {
    if (actionId == NotificationService.actionResume) {
      resumeTrip();
    } else if (actionId == NotificationService.actionEndTrip) {
      confirmEndTrip();
    }
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
      // distanceFilter: 0 ensures we keep getting updates even when stationary,
      // which is critical for detecting "trip ended".
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'AutoLog überwacht Fahrten im Hintergrund',
        notificationTitle: 'AutoLog – Fahrtenerkennung aktiv',
        enableWakeLock: true,
        notificationIcon:
            AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      ),
    );

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: androidSettings,
    ).listen(
      (pos) => _handlePosition(pos, settings),
      onError: (e) {},
    );
  }

  void _handlePosition(Position pos, AppSettings settings) {
    // If user is deciding (pause dialog shown), keep accumulating distance
    // but don't trigger start/end transitions.
    final speedKmh = (pos.speed < 0 ? 0 : pos.speed) * 3.6;
    final now = DateTime.now();

    if (speedKmh >= settings.speedThresholdKmh) {
      // Above threshold – we're moving
      _belowThresholdSince = null;
      _gpsStopTimer?.cancel();
      _gpsStopTimer = null;

      // If we were in a pause state and started moving again → auto-resume
      if (_isPaused && _inTrip) {
        resumeTrip();
      }

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

      // Start trip after 30s above threshold (only if not already in trip)
      if (!_inTrip && movingDuration.inSeconds >= 30) {
        _startGpsTrip(settings);
      }
    } else {
      // Below threshold
      _lastPosition = pos;

      if (_inTrip && !_isPaused) {
        // Trip started by GPS or both → GPS can trigger pause
        // Trip started by BT only → GPS should NOT end it
        if (_tripSource == 'bluetooth') return;

        _belowThresholdSince ??= now;
        final slowDuration = now.difference(_belowThresholdSince!);

        // After 2 minutes below threshold → ask user (pause vs end)
        if (slowDuration.inSeconds >= 120) {
          _triggerPause('gps');
        } else if (_gpsStopTimer == null) {
          final remaining = const Duration(seconds: 120) - slowDuration;
          _gpsStopTimer =
              Timer(remaining + const Duration(seconds: 5), () {
            if (_inTrip && !_isPaused && _belowThresholdSince != null) {
              _triggerPause('gps');
            }
          });
        }
      } else if (!_inTrip) {
        _movingSince = null;
      }
    }
  }

  void _startGpsTrip(AppSettings settings) {
    if (_inTrip) return;
    _inTrip = true;
    _isPaused = false;
    _tripSource = 'gps';
    _tripStartedAt = _movingSince ?? DateTime.now();
    _accumulatedDistanceM = 0;
    _startPosition = _lastPosition;

    final event = TripStartDetected(
      source: 'gps',
      startDate: du.todayIso(),
      startTime: _formatTime(_tripStartedAt!),
      autoRecord: settings.speedAutoRecord,
      startLat: _startPosition?.latitude,
      startLng: _startPosition?.longitude,
    );
    _events.add(event);
    NotificationService.instance.showTripStarted('gps');
  }

  // ── Bluetooth ─────────────────────────────────────────────────────────────

  Future<void> _startBluetooth(AppSettings settings) async {
    if (settings.bluetoothDeviceAddress.isEmpty) return;
    _btTargetAddress = settings.bluetoothDeviceAddress;

    _tryBondedDeviceMonitoring(settings);
    _startPeriodicBluetoothScan(settings);
  }

  void _tryBondedDeviceMonitoring(AppSettings settings) {
    FlutterBluePlus.bondedDevices.then((bonded) {
      final target = bonded
          .where((d) => d.remoteId.str == settings.bluetoothDeviceAddress)
          .firstOrNull;
      if (target == null) return;

      _btSub = target.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected && !_inTrip) {
          _startBluetoothTrip(settings);
        } else if (state == BluetoothConnectionState.disconnected &&
            _inTrip &&
            _tripSource == 'bluetooth') {
          // BT disconnected – ask user instead of immediately ending
          _triggerPause('bluetooth');
        }
      });
    }).catchError((_) {});
  }

  void _startPeriodicBluetoothScan(AppSettings settings) {
    bool targetWasVisible = false;
    int notSeenCount = 0;
    const scanInterval = Duration(seconds: 15);
    const scanDuration = Duration(seconds: 4);
    const missedScansToEnd = 8; // ~2 min

    void doScan() async {
      if (!settings.bluetoothDetectionEnabled) return;

      try {
        bool foundInScan = false;
        await _btScanSub?.cancel();

        _btScanSub = FlutterBluePlus.onScanResults.listen((results) {
          for (final r in results) {
            if (r.device.remoteId.str == _btTargetAddress) {
              foundInScan = true;
              break;
            }
          }
        });

        await FlutterBluePlus.startScan(
          timeout: scanDuration,
          androidUsesFineLocation: true,
        );

        await Future.delayed(scanDuration + const Duration(milliseconds: 500));

        if (foundInScan) {
          notSeenCount = 0;
          if (!targetWasVisible && !_inTrip) {
            targetWasVisible = true;
            _startBluetoothTrip(settings);
          }
          // If we were paused (BT trip) and device is visible again → resume
          if (_isPaused && _inTrip && _tripSource == 'bluetooth') {
            resumeTrip();
          }
          targetWasVisible = true;
        } else {
          notSeenCount++;
          if (targetWasVisible &&
              _inTrip &&
              _tripSource == 'bluetooth' &&
              !_isPaused &&
              notSeenCount >= missedScansToEnd) {
            targetWasVisible = false;
            notSeenCount = 0;
            _triggerPause('bluetooth');
          }
        }
      } catch (_) {}
    }

    doScan();
    _btScanTimer = Timer.periodic(scanInterval, (_) => doScan());
  }

  void _startBluetoothTrip(AppSettings settings) {
    if (_inTrip) return;
    _inTrip = true;
    _isPaused = false;
    _tripSource = 'bluetooth';
    _tripStartedAt = DateTime.now();
    _accumulatedDistanceM = 0;
    _startPosition = _lastPosition; // may be null if GPS not active

    final event = TripStartDetected(
      source: 'bluetooth',
      startDate: du.todayIso(),
      startTime: _formatTime(_tripStartedAt!),
      autoRecord: settings.bluetoothAutoRecord,
      startLat: _startPosition?.latitude,
      startLng: _startPosition?.longitude,
    );
    _events.add(event);
    NotificationService.instance.showTripStarted('bluetooth');
  }

  // ── Pause / End logic ─────────────────────────────────────────────────────

  /// Instead of ending immediately, enter pause state and ask the user.
  void _triggerPause(String source) {
    if (_isPaused) return; // already paused
    _isPaused = true;

    _events.add(TripPauseDetected(source: source));
    NotificationService.instance.showTripPaused();

    // Auto-end after 3 more minutes if user doesn't respond
    _autoEndTimer?.cancel();
    _autoEndTimer = Timer(const Duration(minutes: 3), () {
      if (_inTrip && _isPaused) {
        _endTrip(source);
      }
    });
  }

  void _endTrip(String source) {
    _autoEndTimer?.cancel();
    _autoEndTimer = null;

    final distanceKm = _accumulatedDistanceM / 1000.0;
    _events.add(TripEndDetected(
      source: source,
      endTime: _formatTime(DateTime.now()),
      distanceKm: distanceKm,
      endLat: _lastPosition?.latitude,
      endLng: _lastPosition?.longitude,
    ));
    NotificationService.instance.showTripEnded(distanceKm);
    _reset();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _reset() {
    _inTrip = false;
    _isPaused = false;
    _tripSource = null;
    _movingSince = null;
    _belowThresholdSince = null;
    _tripStartedAt = null;
    _accumulatedDistanceM = 0;
    _lastPosition = null;
    _startPosition = null;
    _gpsStopTimer?.cancel();
    _gpsStopTimer = null;
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
