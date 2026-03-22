import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_form.dart';

class ArchiveScreen extends ConsumerWidget {
  final String title;
  final List<Trip> trips;
  final List<Vehicle> vehicles;
  final bool isTrash;

  const ArchiveScreen({super.key, required this.title, required this.trips, required this.vehicles, this.isTrash = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = [...trips]..sort((a, b) => b.date.compareTo(a.date));
    final vehicleMap = {for (final v in vehicles) v.id: v};
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
      body: sorted.isEmpty
          ? Center(child: Text('Keine Fahrten vorhanden.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (ctx, i) => TripCard(
                trip: sorted[i],
                vehicleMap: vehicleMap,
                onEdit: () => _showEdit(context, ref, sorted[i]),
                onDelete: () => _confirmDelete(context, ref, sorted[i]),
                onReturnTrip: () => ref.read(tripsProvider.notifier).addReturnTrip(sorted[i]),
                onToggle: (field, val) => ref.read(tripsProvider.notifier).toggleField(sorted[i].id, field, val),
                onRestore: isTrash ? () => ref.read(tripsProvider.notifier).restoreTrip(sorted[i].id) : null,
              ),
            ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripForm(
        initialData: trip,
        onSave: (updated, _) => ref.read(tripsProvider.notifier).updateTrip(trip.id, updated.copyWith(id: trip.id)),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTrash ? 'Endgültig löschen' : 'Fahrt löschen'),
        content: Text(isTrash ? 'Diese Fahrt kann nicht wiederhergestellt werden.' : 'Fahrt in den Papierkorb verschieben?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isTrash) {
                ref.read(tripsProvider.notifier).hardDeleteTrip(trip.id);
              } else {
                ref.read(tripsProvider.notifier).deleteTrip(trip.id);
              }
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
