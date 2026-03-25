import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/trip_card.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback onNewTrip;
  final void Function(Trip) onEditTrip;

  const DashboardScreen({super.key, required this.onNewTrip, required this.onEditTrip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final vehicleMap = {for (final v in vehicles) v.id: v};

    final completed = stats.completed;
    final unbilled = stats.unbilled;
    final unlogged = stats.unlogged;
    final unbilledKm = stats.unbilledKm;
    final todayTrips = stats.todayTrips;

    final defaultVehicle = vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.isNotEmpty ? vehicles.first : const Vehicle(id: '', name: ''));
    double currentMileage = 0;
    if (defaultVehicle.id.isNotEmpty) {
      final validTrips = completed.where((t) {
        if (t.vehicleId != defaultVehicle.id) return false;
        if (defaultVehicle.initialMileageDate != null && t.date.compareTo(defaultVehicle.initialMileageDate!) < 0) return false;
        return true;
      });
      currentMileage = defaultVehicle.initialMileage + validTrips.fold(0.0, (s, t) => s + t.distanceKm);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.map_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('AutoLog', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Fahrzeug-Card
          if (defaultVehicle.id.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Aktuelles Fahrzeug', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.directions_car_outlined, size: 18, color: AppTheme.emerald),
                          const SizedBox(width: 6),
                          Text(defaultVehicle.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ]),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Zählerstand', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('${currentMileage.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                    ]),
                  ],
                ),
              ),
            ),

          if (defaultVehicle.id.isNotEmpty) const SizedBox(height: 12),

          // Offene Fahrten
          if (unbilled.isNotEmpty || unlogged.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade200, width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.warning_amber_outlined, color: Colors.red.shade600),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Offen (Nicht abgerechnet)', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text('${unbilledKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('${unbilled.length} Fahrten, ${unlogged.length} nicht eingetragen', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ])),
                    Icon(Icons.chevron_right, color: Colors.red.shade400),
                  ]),
                ),
              ),
            ),

          if (unbilled.isNotEmpty || unlogged.isNotEmpty) const SizedBox(height: 12),

          // Heute
          Text('Fahrten heute', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (todayTrips.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('Keine Fahrten heute.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
              ),
            )
          else
            ...todayTrips.map((trip) => TripCard(
              trip: trip,
              vehicleMap: vehicleMap,
              onEdit: () => onEditTrip(trip),
              onDelete: () => _confirmDelete(context, ref, trip),
              onReturnTrip: () => ref.read(tripsProvider.notifier).addReturnTrip(trip),
              onToggle: (field, val) => ref.read(tripsProvider.notifier).toggleField(trip.id, field, val),
            )),
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
