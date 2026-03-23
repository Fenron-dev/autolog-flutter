import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/import_utils.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _markBilled = false;
  bool _markLogged = false;
  bool _loading = false;

  Future<void> _pickFromDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime(DateTime.now().year, 1, 1),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    if (d != null) setState(() => _fromDate = d);
  }

  Future<void> _pickToDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    if (d != null) setState(() => _toDate = d);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _startImport() async {
    setState(() => _loading = true);
    final trips = await importFromJsonFile(
      context,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (trips == null || trips.isEmpty) return;

    // Apply billed/logged flags
    final finalTrips = (_markBilled || _markLogged)
        ? trips.map((t) => t.copyWith(
              isBilled: _markBilled ? true : t.isBilled,
              isLogged: _markLogged ? true : t.isLogged,
            )).toList()
        : trips;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import bestätigen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${finalTrips.length} Fahrten erkannt.'),
            if (_fromDate != null || _toDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Zeitraum: ${_fromDate != null ? _formatDate(_fromDate!) : '–'} bis ${_toDate != null ? _formatDate(_toDate!) : 'heute'}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (_markBilled || _markLogged) ...[
              const SizedBox(height: 4),
              Text(
                'Markiert als: ${[if (_markBilled) 'abgerechnet', if (_markLogged) 'eingetragen'].join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(tripsProvider.notifier).loadTrips(finalTrips);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${finalTrips.length} Fahrten importiert.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Maps Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.map_outlined, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Google Zeitachse importieren', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
                const SizedBox(height: 8),
                const Text('Importiere Fahrten aus deiner Google Maps Zeitachse (Zeitachsen.json aus Google Takeout).'),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Date range
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Zeitraum (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Nur Fahrten in diesem Zeitraum importieren.', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(_fromDate != null ? _formatDate(_fromDate!) : 'Von: unbegrenzt', style: const TextStyle(fontSize: 12)),
                      onPressed: _pickFromDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(_toDate != null ? _formatDate(_toDate!) : 'Bis: heute', style: const TextStyle(fontSize: 12)),
                      onPressed: _pickToDate,
                    ),
                  ),
                ]),
                if (_fromDate != null || _toDate != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Zeitraum zurücksetzen', style: TextStyle(fontSize: 12)),
                    onPressed: () => setState(() { _fromDate = null; _toDate = null; }),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Mark options
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Importierte Fahrten markieren', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Gilt nur für geschäftliche Fahrten.', style: TextStyle(fontSize: 12)),
                CheckboxListTile(
                  value: _markBilled,
                  onChanged: (v) => setState(() => _markBilled = v ?? false),
                  title: const Text('Als abgerechnet markieren', style: TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _markLogged,
                  onChanged: (v) => setState(() => _markLogged = v ?? false),
                  title: const Text('Als eingetragen markieren', style: TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Import button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _startImport,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_loading ? 'Wird geladen...' : 'Zeitachsen.json auswählen'),
            ),
          ),
          const SizedBox(height: 12),

          // Warning card
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Row(children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Hinweis', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
                SizedBox(height: 8),
                Text('Der Import ersetzt alle bestehenden Fahrten. Erstelle vorher ein Backup unter Einstellungen → Backup.'),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
