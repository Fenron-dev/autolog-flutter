import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;
import '../widgets/trip_card.dart';

enum TimeFilter { week, month, year, all }

class HistoryScreen extends ConsumerStatefulWidget {
  final void Function(Trip) onEditTrip;
  const HistoryScreen({super.key, required this.onEditTrip});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  TimeFilter _filter = TimeFilter.week;

  List<Trip> _filterTrips(List<Trip> trips) {
    final completed = trips.where((t) => t.status == TripStatus.completed).toList();
    if (_filter == TimeFilter.all) return completed;
    final now = DateTime.now();
    return completed.where((t) {
      final d = DateTime.tryParse(t.date);
      if (d == null) return false;
      return switch (_filter) {
        TimeFilter.week => du.isSameWeek(d, now),
        TimeFilter.month => du.isSameMonth(d, now),
        TimeFilter.year => du.isSameYear(d, now),
        TimeFilter.all => true,
      };
    }).toList()..sort((a, b) {
      final dc = b.date.compareTo(a.date);
      return dc != 0 ? dc : b.startTime.compareTo(a.startTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTrips = ref.watch(tripsProvider.select((s) => s.activeTrips));
    final vehicles = ref.watch(vehiclesProvider);
    final vehicleMap = {for (final v in vehicles) v.id: v};
    final trips = _filterTrips(activeTrips);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historie', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: TimeFilter.values.map((f) {
                final label = switch (f) { TimeFilter.week => 'Woche', TimeFilter.month => 'Monat', TimeFilter.year => 'Jahr', TimeFilter.all => 'Alle' };
                final selected = _filter == f;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FilledButton.tonal(
                      onPressed: () => setState(() => _filter = f),
                      style: FilledButton.styleFrom(
                        backgroundColor: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                        foregroundColor: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(label, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: trips.isEmpty
                ? Center(child: Text('Keine Fahrten in diesem Zeitraum.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: trips.length,
                    itemBuilder: (ctx, i) => TripCard(
                      trip: trips[i],
                      vehicleMap: vehicleMap,
                      onEdit: () => widget.onEditTrip(trips[i]),
                      onDelete: () => _confirmDelete(context, ref, trips[i]),
                      onReturnTrip: () => ref.read(tripsProvider.notifier).addReturnTrip(trips[i]),
                      onToggle: (field, val) => ref.read(tripsProvider.notifier).toggleField(trips[i].id, field, val),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrt löschen'),
        content: const Text('Fahrt in den Papierkorb verschieben?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); ref.read(tripsProvider.notifier).deleteTrip(trip.id); },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
