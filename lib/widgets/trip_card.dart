import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;

class TripCard extends StatelessWidget {
  final Trip trip;
  final Map<String, Vehicle> vehicleMap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReturnTrip;
  final void Function(String field, bool value) onToggle;
  final VoidCallback? onRestore;

  const TripCard({
    super.key,
    required this.trip,
    required this.vehicleMap,
    required this.onEdit,
    required this.onDelete,
    required this.onReturnTrip,
    required this.onToggle,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = trip.vehicleId != null ? vehicleMap[trip.vehicleId] : null;
    final isBusiness = trip.type == TripType.business;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(du.formatDate(trip.date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 8),
                        Text('${trip.startTime} – ${trip.endTime}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(child: Text(trip.destinationName, style: const TextStyle(fontWeight: FontWeight.w500))),
                        if (trip.destinationAddress.isNotEmpty)
                          GestureDetector(
                            onTap: () => _openMaps(trip.destinationAddress),
                            child: const Icon(Icons.location_on_outlined, size: 16, color: Colors.blue),
                          ),
                      ]),
                      if (trip.destinationAddress.isNotEmpty)
                        Text(trip.destinationAddress, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (vehicle != null && vehicle.id.isNotEmpty)
                        Row(children: [
                          Icon(Icons.directions_car_outlined, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(vehicle.name, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${trip.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBusiness ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isBusiness ? 'Geschäftlich' : 'Privat',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isBusiness ? Colors.green.shade700 : Colors.amber.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                if (isBusiness)
                  Expanded(
                    child: Row(children: [
                      Flexible(child: _ToggleChip(
                        label: 'Abgerechnet',
                        active: trip.isBilled,
                        onTap: () => onToggle('isBilled', !trip.isBilled),
                      )),
                      const SizedBox(width: 8),
                      Flexible(child: _ToggleChip(
                        label: 'Eingetragen',
                        active: trip.isLogged,
                        onTap: () => onToggle('isLogged', !trip.isLogged),
                      )),
                    ]),
                  )
                else
                  const Spacer(),
                if (onRestore != null)
                  IconButton(onPressed: onRestore, icon: const Icon(Icons.restore, size: 18), tooltip: 'Wiederherstellen', constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                IconButton(onPressed: onReturnTrip, icon: const Icon(Icons.sync_alt, size: 18), tooltip: 'Rückfahrt erstellen', constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), tooltip: 'Bearbeiten', constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), tooltip: 'Löschen', constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openMaps(String address) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': address});
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(active ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: active ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}
