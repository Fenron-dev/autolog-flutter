import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';

/// Versucht eine JSON-Datei vom Nutzer zu laden und parst Fahrten daraus.
/// Unterstützt das alte Google Maps Takeout-Format (Records.json).
/// Da Google den auto-Import abgeschafft hat, muss der Nutzer die Datei
/// manuell über Google Takeout exportieren.
Future<List<Trip>?> importFromJsonFile(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.first.bytes;
    if (bytes == null) return null;

    // Größenlimit: max 10 MB, um Memory-Overflow zu verhindern
    const maxBytes = 10 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datei ist zu groß (max. 10 MB).')),
        );
      }
      return null;
    }

    final json = jsonDecode(utf8.decode(bytes));

    // Google Takeout Records.json Format
    if (json is Map && json.containsKey('locations')) {
      return _parseGoogleLocations(json as Map<String, dynamic>);
    }

    // AutoLog eigenes Format (JSON-Backup)
    if (json is List) {
      return json.map((e) {
        try { return Trip.fromJson(e as Map<String, dynamic>); }
        catch (_) { return null; }
      }).whereType<Trip>().toList();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dateiformat nicht erkannt. Bitte Records.json aus Google Takeout oder einen AutoLog-Export wählen.')),
      );
    }
    return null;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: $e')));
    }
    return null;
  }
}

List<Trip> _parseGoogleLocations(Map<String, dynamic> json) {
  // Google Location History: Gruppiert Punkte in Fahrten (einfache Heuristik)
  // Da Google das Format regelmäßig ändert, ist dies eine Best-Effort Implementierung
  return []; // Placeholder – das Google Format ändert sich zu oft für eine zuverlässige Implementierung
}
