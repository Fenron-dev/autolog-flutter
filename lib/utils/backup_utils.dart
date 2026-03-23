import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../providers/providers.dart';

final _fileDateFormat = DateFormat('yyyy-MM-dd');

Future<void> createBackup(BuildContext context, WidgetRef ref) async {
  try {
    final tripsState = ref.read(tripsProvider);
    final vehicles = ref.read(vehiclesProvider);
    final customers = ref.read(customersProvider);
    final accidents = ref.read(accidentsProvider);

    final allTrips = [
      ...tripsState.activeTrips,
      ...tripsState.archivedTrips,
      ...tripsState.deletedTrips,
    ];

    final backup = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'trips': allTrips.map((t) => t.toJson()).toList(),
      'vehicles': vehicles.map((v) => v.toJson()).toList(),
      'customers': customers.map((c) => c.toJson()).toList(),
      'accidents': accidents.map((a) => a.toJson()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);
    final date = _fileDateFormat.format(DateTime.now());
    final fileName = 'AutoLog_Backup_$date.json';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json, encoding: utf8);
    await Share.shareXFiles([XFile(file.path)], text: 'AutoLog Backup');
    await file.delete().catchError((_) => file);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup fehlgeschlagen: $e')),
      );
    }
  }
}

Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    const maxBytes = 50 * 1024 * 1024; // 50 MB – Unfallfotos können groß sein
    if (bytes.length > maxBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup-Datei ist zu groß (max. 50 MB).')),
        );
      }
      return;
    }

    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

    // Version prüfen
    final version = json['version'] as int? ?? 0;
    if (version < 1) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unbekanntes Backup-Format.')),
        );
      }
      return;
    }

    final trips = (json['trips'] as List<dynamic>? ?? [])
        .map((e) { try { return Trip.fromJson(e as Map<String, dynamic>); } catch (_) { return null; } })
        .whereType<Trip>()
        .toList();

    final vehicles = (json['vehicles'] as List<dynamic>? ?? [])
        .map((e) { try { return Vehicle.fromJson(e as Map<String, dynamic>); } catch (_) { return null; } })
        .whereType<Vehicle>()
        .toList();

    final customers = (json['customers'] as List<dynamic>? ?? [])
        .map((e) { try { return Customer.fromJson(e as Map<String, dynamic>); } catch (_) { return null; } })
        .whereType<Customer>()
        .toList();

    final accidents = (json['accidents'] as List<dynamic>? ?? [])
        .map((e) { try { return AccidentReport.fromJson(e as Map<String, dynamic>); } catch (_) { return null; } })
        .whereType<AccidentReport>()
        .toList();

    if (!context.mounted) return;

    final createdAt = json['createdAt'] as String?;
    final dateStr = createdAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(createdAt))
        : 'unbekannt';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup wiederherstellen'),
        content: Text(
          'Backup vom $dateStr\n\n'
          '• ${trips.length} Fahrten\n'
          '• ${vehicles.length} Fahrzeuge\n'
          '• ${customers.length} Ziele\n'
          '• ${accidents.length} Unfallberichte\n\n'
          'Alle aktuellen Daten werden überschrieben.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ref.read(tripsProvider.notifier).loadTrips(trips);
    ref.read(vehiclesProvider.notifier).loadVehicles(vehicles);
    ref.read(customersProvider.notifier).loadCustomers(customers);
    ref.read(accidentsProvider.notifier).loadAccidents(accidents);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup wiederhergestellt (${trips.length} Fahrten).')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wiederherstellung fehlgeschlagen: $e')),
      );
    }
  }
}
