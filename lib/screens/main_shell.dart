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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
