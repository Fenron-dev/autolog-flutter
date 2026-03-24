import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'planned_screen.dart';
import 'settings_screen.dart';
import '../widgets/trip_form.dart';
import '../models/models.dart';
import '../services/auto_detect_service.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  StreamSubscription<AutoDetectEvent>? _detectSub;
  TripStartDetected? _pendingTripStart;

  /// True while a trip is being recorded – drives the recording banner.
  bool _isRecording = false;
  bool _isPaused = false;
  String _recordingSource = '';
  DateTime? _recordingSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      AutoDetectService.instance.startMonitoring(settings);
      _detectSub =
          AutoDetectService.instance.events.listen(_handleDetectEvent);
    });
  }

  @override
  void dispose() {
    _detectSub?.cancel();
    AutoDetectService.instance.stopMonitoring();
    super.dispose();
  }

  // ── Event handling ──────────────────────────────────────────────────────

  void _handleDetectEvent(AutoDetectEvent event) {
    if (event is TripStartDetected) {
      _pendingTripStart = event;
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingSource = event.source == 'gps' ? 'GPS' : 'Bluetooth';
        _recordingSince = DateTime.now();
      });
      if (!event.autoRecord) {
        _showTripDetectedDialog(event);
      }
    } else if (event is TripPauseDetected) {
      setState(() => _isPaused = true);
      _showTripPauseDialog(event);
    } else if (event is TripEndDetected) {
      final start = _pendingTripStart;
      _pendingTripStart = null;
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      if (start != null) {
        _saveTripAndNotify(start, event);
      }
    }
  }

  // ── Trip Start dialog (autoRecord = false) ─────────────────────────────

  void _showTripDetectedDialog(TripStartDetected event) {
    if (!mounted) return;
    final source =
        event.source == 'gps' ? 'GPS-Geschwindigkeit' : 'Bluetooth-Verbindung';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrt erkannt'),
        content: Text(
          '$source hat eine Fahrt erkannt (${event.startTime} Uhr).\n\n'
          'Soll diese Fahrt aufgezeichnet werden?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // User doesn't want this trip → clear pending, stop recording indicator
              _pendingTripStart = null;
              setState(() {
                _isRecording = false;
                _isPaused = false;
              });
            },
            child: const Text('Ignorieren'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // _pendingTripStart stays set → trip will auto-save when it ends
            },
            child: const Text('Aufzeichnen'),
          ),
        ],
      ),
    );
  }

  // ── Trip Pause dialog ──────────────────────────────────────────────────

  void _showTripPauseDialog(TripPauseDetected event) {
    if (!mounted) return;
    final source = event.source == 'gps' ? 'GPS' : 'Bluetooth';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrt unterbrochen?'),
        content: Text(
          'Die $source-Erkennung hat festgestellt, dass du seit 2 Minuten stehst.\n\n'
          'Bist du an einer Ampel, Bahnschranke oder im Stau? '
          'Oder ist die Fahrt beendet?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AutoDetectService.instance.resumeTrip();
              setState(() => _isPaused = false);
            },
            child: const Text('Weiterfahrt / Pause'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              AutoDetectService.instance.confirmEndTrip();
            },
            child: const Text('Fahrt beenden'),
          ),
        ],
      ),
    );
  }

  // ── Save trip ──────────────────────────────────────────────────────────

  void _saveTripAndNotify(TripStartDetected start, TripEndDetected end) {
    final notifier = ref.read(tripsProvider.notifier);
    final source = start.source == 'gps' ? 'GPS' : 'Bluetooth';
    final trip = Trip(
      id: '',
      date: start.startDate,
      startTime: start.startTime,
      endTime: end.endTime,
      destinationName: 'Erkannte Fahrt ($source)',
      destinationAddress: '',
      distanceKm: end.distanceKm > 0 ? end.distanceKm : 0,
      type: TripType.business,
      status: TripStatus.completed,
      isBilled: false,
      isLogged: false,
      notes: 'Automatisch erfasst via $source',
      vehicleId: null,
    );
    notifier.addTrip(trip);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Fahrt gespeichert: ${end.distanceKm.toStringAsFixed(1)} km '
            '(${start.startTime} – ${end.endTime})',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Bearbeiten',
            onPressed: () {
              // Open the trip form pre-filled with the saved trip data
              // so the user can adjust destination, type, etc.
              _showTripForm(trip: trip);
            },
          ),
        ),
      );
    }
  }

  // ── Trip form ──────────────────────────────────────────────────────────

  void _showTripForm({Trip? trip}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripForm(
        initialData: trip,
        onSave: (newTrip, saveAsCustomer) {
          final notifier = ref.read(tripsProvider.notifier);
          if (trip != null) {
            notifier.updateTrip(trip.id, newTrip.copyWith(id: trip.id));
          } else {
            notifier.addTrip(newTrip);
          }
          if (saveAsCustomer && newTrip.destinationName.isNotEmpty) {
            ref.read(customersProvider.notifier)
                .addCustomer(newTrip.destinationName, newTrip.destinationAddress);
          }
        },
      ),
    );
  }

  // ── Recording banner ───────────────────────────────────────────────────

  Widget _buildRecordingBanner() {
    final minutes = _recordingSince != null
        ? DateTime.now().difference(_recordingSince!).inMinutes
        : 0;
    return Material(
      color: _isPaused ? Colors.orange : AppTheme.emerald,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                _isPaused ? Icons.pause_circle : Icons.fiber_manual_record,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isPaused
                      ? 'Fahrt pausiert – warte auf Antwort…'
                      : 'Fahrt wird aufgezeichnet via $_recordingSource'
                          '${minutes > 0 ? ' ($minutes Min.)' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!_isPaused)
                TextButton(
                  onPressed: () {
                    AutoDetectService.instance.confirmEndTrip();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Beenden', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tripsState = ref.watch(tripsProvider);

    ref.listen(settingsProvider, (prev, next) {
      if (prev?.speedDetectionEnabled != next.speedDetectionEnabled ||
          prev?.speedThresholdKmh != next.speedThresholdKmh ||
          prev?.bluetoothDetectionEnabled != next.bluetoothDetectionEnabled ||
          prev?.bluetoothDeviceAddress != next.bluetoothDeviceAddress) {
        AutoDetectService.instance.restartMonitoring(next);
      }
    });

    final screens = [
      DashboardScreen(
        onNewTrip: () => _showTripForm(),
        onEditTrip: (t) => _showTripForm(trip: t),
      ),
      PlannedScreen(onEditTrip: (t) => _showTripForm(trip: t)),
      HistoryScreen(onEditTrip: (t) => _showTripForm(trip: t)),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (_isRecording) _buildRecordingBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTripForm(),
        backgroundColor: AppTheme.emerald,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                index: 0,
                current: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.calendar_today_outlined,
                label: 'Geplant',
                index: 1,
                current: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
                badge: tripsState.plannedCount > 0
                    ? tripsState.plannedCount
                    : null,
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: _NavItem(
                icon: Icons.history_outlined,
                label: 'Historie',
                index: 2,
                current: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.settings_outlined,
                label: 'Einst.',
                index: 3,
                current: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;
  final int? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    final color = selected
        ? AppTheme.emerald
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
