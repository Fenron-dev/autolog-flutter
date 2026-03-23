import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/import_utils.dart';

class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Maps Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.map_outlined, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Google Maps Standortverlauf', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
                const SizedBox(height: 12),
                const Text('Importiere deine Standortdaten aus Google Takeout (Records.json). Fahrten werden automatisch aus dem Standortverlauf erkannt.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final trips = await importFromJsonFile(context);
                    if (trips != null && trips.isNotEmpty && context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Import bestätigen'),
                          content: Text('${trips.length} Fahrten gefunden. Importieren?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ref.read(tripsProvider.notifier).loadTrips(trips);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${trips.length} Fahrten importiert.')),
                                );
                              },
                              child: const Text('Importieren'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('JSON-Datei auswählen'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Row(children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Hinweis zu Google Maps', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
                SizedBox(height: 8),
                Text('Google hat den automatischen Standortverlauf-Export eingestellt. Ein direkter Import aus Google Maps ist nicht mehr möglich.\n\nDu kannst weiterhin Fahrten manuell erfassen.'),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
