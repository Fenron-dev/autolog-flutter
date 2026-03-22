import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;

class PlannedScreen extends ConsumerWidget {
  final void Function(Trip) onEditTrip;
  const PlannedScreen({super.key, required this.onEditTrip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planned = ref.watch(tripsProvider.select((s) =>
        s.activeTrips.where((t) => t.status == TripStatus.planned).toList()
          ..sort((a, b) => a.date.compareTo(b.date))));

    return Scaffold(
      appBar: AppBar(title: const Text('Geplante Fahrten', style: TextStyle(fontWeight: FontWeight.w600))),
      body: planned.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Keine geplanten Fahrten.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: planned.length,
              itemBuilder: (ctx, i) {
                final trip = planned[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(children: [
                      Text(du.formatDate(trip.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(trip.startTime, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 4),
                      Text(trip.destinationName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (trip.destinationAddress.isNotEmpty)
                        Text(trip.destinationAddress, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (trip.destinationAddress.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.navigation_outlined, color: Colors.blue),
                          onPressed: () => _openMaps(context, trip.destinationAddress),
                          tooltip: 'Navigation starten',
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEditTrip(trip),
                        tooltip: 'Bearbeiten',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, trip),
                        tooltip: 'Löschen',
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openMaps(BuildContext context, String address) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}');
    if (!await canLaunchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Maps konnte nicht geöffnet werden.')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrt löschen'),
        content: const Text('Geplante Fahrt löschen?'),
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
