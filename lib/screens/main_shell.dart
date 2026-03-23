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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      AutoDetectService.instance.startMonitoring(settings);
      _detectSub = AutoDetectService.instance.events.listen(_handleDetectEvent);
    });
  }

  @override
  void dispose() {
    _detectSub?.cancel();
    AutoDetectService.instance.stopMonitoring();
    super.dispose();
  }

  void _handleDetectEvent(AutoDetectEvent event) {
    if (event is TripStartDetected) {
      _pendingTripStart = event;
      if (!event.autoRecord) {
        _showTripDetectedDialog(event);
      }
    } else if (event is TripEndDetected) {
      final start = _pendingTripStart;
      _pendingTripStart = null;
      if (start != null && start.autoRecord) {
        _autoSaveTrip(start, event);
      }
    }
  }

  void _showTripDetectedDialog(TripStartDetected event) {
    if (!mounted) return;
    final source = event.source == 'gps' ? 'GPS-Geschwindigkeit' : 'Bluetooth-Verbindung';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrt erkannt'),
        content: Text('$source hat eine mögliche Fahrt erkannt (${event.startTime} Uhr). Jetzt aufzeichnen?'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _pendingTripStart = null; },
            child: const Text('Ignorieren'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showTripFormWithPrefilledTime(event);
            },
            child: const Text('Aufzeichnen'),
          ),
        ],
      ),
    );
  }

  void _showTripFormWithPrefilledTime(TripStartDetected event) {
    // Create a partial trip with just the start info pre-filled
    // The user completes destination, distance etc. in the form
    _showTripForm();
  }

  void _autoSaveTrip(TripStartDetected start, TripEndDetected end) {
    final notifier = ref.read(tripsProvider.notifier);
    final source = start.source == 'gps' ? 'GPS' : 'Bluetooth';
    notifier.addTrip(Trip(
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
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fahrt automatisch gespeichert (${end.distanceKm.toStringAsFixed(1)} km)'),
          action: SnackBarAction(label: 'Bearbeiten', onPressed: () {}),
        ),
      );
    }
  }

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
      DashboardScreen(onNewTrip: () => _showTripForm(), onEditTrip: (t) => _showTripForm(trip: t)),
      PlannedScreen(onEditTrip: (t) => _showTripForm(trip: t)),
      HistoryScreen(onEditTrip: (t) => _showTripForm(trip: t)),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
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
        height: 64,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', index: 0, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
            _NavItem(
              icon: Icons.calendar_today_outlined,
              label: 'Geplant',
              index: 1,
              current: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              badge: tripsState.plannedCount > 0 ? tripsState.plannedCount : null,
            ),
            const SizedBox(width: 48), // FAB gap
            _NavItem(icon: Icons.history_outlined, label: 'Historie', index: 2, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
            _NavItem(icon: Icons.settings_outlined, label: 'Einstellungen', index: 3, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
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

  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    final color = selected ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
