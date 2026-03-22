import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../utils/date_utils.dart' as du;
import '../widgets/accident_form.dart';

class AccidentsScreen extends ConsumerWidget {
  const AccidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accidents = ref.watch(accidentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Unfallberichte', style: TextStyle(fontWeight: FontWeight.w600))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: accidents.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Keine Unfallberichte', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accidents.length,
              itemBuilder: (ctx, i) {
                final a = accidents[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(du.formatDate(a.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(a.time, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const Spacer(),
                        if (a.photos.isNotEmpty)
                          Chip(
                            label: Text('${a.photos.length} Foto${a.photos.length != 1 ? 's' : ''}'),
                            avatar: const Icon(Icons.photo_camera_outlined, size: 14),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(child: Text(a.location, style: const TextStyle(fontWeight: FontWeight.w500))),
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a.location)}');
                            if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          child: const Icon(Icons.location_on_outlined, size: 16, color: Colors.blue),
                        ),
                      ]),
                      if (a.otherPartyName.isNotEmpty)
                        Text('Gegner: ${a.otherPartyName}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const Divider(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton.icon(onPressed: () => _showForm(context, ref, a), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Bearbeiten')),
                        TextButton.icon(
                          onPressed: () => _confirmDelete(context, ref, a),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          label: const Text('Löschen', style: TextStyle(color: Colors.red)),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, AccidentReport? accident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccidentForm(
        initialData: accident,
        onSave: (a) {
          if (accident != null) {
            ref.read(accidentsProvider.notifier).updateAccident(accident.id, a.copyWith(id: accident.id));
          } else {
            ref.read(accidentsProvider.notifier).addAccident(a);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AccidentReport a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfallbericht löschen'),
        content: const Text('Diesen Unfallbericht wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(onPressed: () { Navigator.pop(ctx); ref.read(accidentsProvider.notifier).deleteAccident(a.id); }, child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
