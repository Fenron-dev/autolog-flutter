import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback for notification actions (runs even when app is in background).
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  // Forward to the singleton so the auto-detect service can react.
  NotificationService.instance.handleActionResponse(response);
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Stream that emits notification action IDs (e.g. 'pause', 'end_trip').
  final _actions = StreamController<String>.broadcast();
  Stream<String> get actions => _actions.stream;

  // Notification channel / IDs
  static const _channelId = 'autolog_trip';
  static const _channelName = 'Fahrten-Erkennung';
  static const _channelDesc = 'Benachrichtigungen für erkannte Fahrten';

  static const tripStartId = 100;
  static const tripPauseId = 101;
  static const tripEndId = 102;

  // Action IDs
  static const actionResume = 'resume_trip';
  static const actionEndTrip = 'end_trip';

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        handleActionResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // Request notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void handleActionResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      _actions.add(actionId);
    }
  }

  // ── Trip Start ──────────────────────────────────────────────────────────

  Future<void> showTripStarted(String source) async {
    final sourceLabel = source == 'gps' ? 'GPS' : 'Bluetooth';
    await _plugin.show(
      tripStartId,
      'Fahrt erkannt',
      'Aufzeichnung gestartet via $sourceLabel',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.navigation,
        ),
      ),
    );
  }

  // ── Trip Pause (stopped – traffic light / train crossing / traffic jam) ─

  Future<void> showTripPaused() async {
    await _plugin.cancel(tripStartId);
    await _plugin.show(
      tripPauseId,
      'Fahrt unterbrochen?',
      'Du stehst seit 2 Min. Fahrt beendet oder nur Pause (Ampel/Stau)?',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.navigation,
          actions: [
            const AndroidNotificationAction(
              actionResume,
              'Weiterfahrt',
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              actionEndTrip,
              'Fahrt beenden',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── Trip End ────────────────────────────────────────────────────────────

  Future<void> showTripEnded(double distanceKm) async {
    await _plugin.cancel(tripStartId);
    await _plugin.cancel(tripPauseId);
    await _plugin.show(
      tripEndId,
      'Fahrt beendet',
      'Strecke: ${distanceKm.toStringAsFixed(1)} km – Eintrag gespeichert.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ── Clear all ───────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  void dispose() {
    _actions.close();
  }
}
