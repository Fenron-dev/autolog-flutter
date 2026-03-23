import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';

/// Lädt eine JSON-Datei und gibt geparste Trips zurück.
/// Unterstützt: Google Zeitachsen.json (Timeline), altes Records.json, AutoLog-Backup (Liste).
/// [fromDate] und [toDate] filtern den Zeitraum (optional).
Future<List<Trip>?> importFromJsonFile(
  BuildContext context, {
  DateTime? fromDate,
  DateTime? toDate,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.first.bytes;
    if (bytes == null) return null;

    // 50 MB Limit
    const maxBytes = 50 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datei ist zu groß (max. 50 MB).')),
        );
      }
      return null;
    }

    final dynamic json = jsonDecode(utf8.decode(bytes));
    List<Trip> trips = [];

    if (json is Map<String, dynamic>) {
      // Google Zeitachsen.json – neues Format (semanticSegments)
      if (json.containsKey('semanticSegments')) {
        trips = _parseSemanticSegments(json['semanticSegments'] as List<dynamic>);
      }
      // Google Timeline – altes Format (timelineObjects)
      else if (json.containsKey('timelineObjects')) {
        trips = _parseTimelineObjects(json['timelineObjects'] as List<dynamic>);
      }
      // Altes Google Records.json Format
      else if (json.containsKey('locations')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Records.json erkannt, aber dieses Format wird nicht mehr unterstützt. Bitte nutze Zeitachsen.json aus Google Takeout.')),
          );
        }
        return null;
      }
    }
    // AutoLog JSON-Backup (Liste von Trips)
    else if (json is List) {
      trips = json
          .map((e) { try { return Trip.fromJson(e as Map<String, dynamic>); } catch (_) { return null; } })
          .whereType<Trip>()
          .toList();
    }

    if (trips.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Fahrten erkannt. Unterstützte Formate: Zeitachsen.json, timelineObjects, AutoLog-Backup.')),
      );
      return null;
    }

    // Zeitraumfilter anwenden
    if (fromDate != null || toDate != null) {
      trips = trips.where((t) {
        final d = DateTime.tryParse(t.date);
        if (d == null) return false;
        if (fromDate != null && d.isBefore(fromDate)) return false;
        if (toDate != null && d.isAfter(toDate.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
    }

    return trips;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import fehlgeschlagen: $e')),
      );
    }
    return null;
  }
}

// ─── Parser: semanticSegments (Google Zeitachsen.json, 2024+) ─────────────────

List<Trip> _parseSemanticSegments(List<dynamic> segments) {
  final trips = <Trip>[];
  final vehicleTypes = {'IN_PASSENGER_VEHICLE', 'IN_CAR', 'MOTORCYCLING', 'IN_VEHICLE'};

  for (int i = 0; i < segments.length; i++) {
    final seg = segments[i];
    if (seg is! Map<String, dynamic>) continue;
    final activity = seg['activity'] as Map<String, dynamic>?;
    if (activity == null) continue;

    // Nur Fahrzeug-Aktivitäten
    final topCandidate = activity['topCandidate'] as Map<String, dynamic>?;
    final type = topCandidate?['type'] as String? ?? '';
    if (!vehicleTypes.contains(type)) continue;

    final startTs = seg['startTime'] as String?;
    final endTs = seg['endTime'] as String?;
    if (startTs == null || endTs == null) continue;

    final startDt = DateTime.tryParse(startTs);
    final endDt = DateTime.tryParse(endTs);
    if (startDt == null || endDt == null) continue;

    final distanceM = (activity['distanceMeters'] as num?)?.toDouble() ?? 0.0;

    // Ziel aus nachfolgendem visit-Segment ermitteln
    String destName = '';
    String destAddress = '';
    if (i + 1 < segments.length) {
      final nextSeg = segments[i + 1];
      if (nextSeg is Map<String, dynamic>) {
        final visit = nextSeg['visit'] as Map<String, dynamic>?;
        if (visit != null) {
          final topC = visit['topCandidate'] as Map<String, dynamic>?;
          final semanticType = topC?['semanticType'] as String? ?? '';
          switch (semanticType) {
            case 'TYPE_HOME':
              destName = 'Zuhause';
            case 'TYPE_WORK':
              destName = 'Arbeit';
            default:
              break;
          }
          // Koordinaten aus visit-Segment als Adresse (plain lat,lng für Maps-Link)
          final placeLocation = topC?['placeLocation'] as Map<String, dynamic>?;
          final latLng = placeLocation?['latLng'] as String?;
          if (latLng != null) destAddress = _latLngToPlain(latLng);
        }
      }
    }

    // Fallback: Koordinaten aus activity.end
    if (destAddress.isEmpty) {
      final endLatLng = activity['end']?['latLng'] as String?;
      if (endLatLng != null) destAddress = _latLngToPlain(endLatLng);
    }

    trips.add(Trip(
      id: '',
      date: startDt.toIso8601String().substring(0, 10),
      startTime: _formatTime(startDt),
      endTime: _formatTime(endDt),
      destinationName: destName.isEmpty ? 'Google Import' : destName,
      destinationAddress: destAddress,
      distanceKm: distanceM / 1000.0,
      type: TripType.business,
      status: TripStatus.completed,
      isBilled: false,
      isLogged: false,
      notes: 'Importiert aus Google Zeitachse ($type)',
      vehicleId: null,
    ));
  }

  return trips;
}

// ─── Parser: timelineObjects (älteres Google Format) ─────────────────────────

List<Trip> _parseTimelineObjects(List<dynamic> objects) {
  final trips = <Trip>[];
  final vehicleTypes = {'IN_PASSENGER_VEHICLE', 'IN_CAR', 'MOTORCYCLING', 'IN_VEHICLE', 'CYCLING'};

  for (final obj in objects) {
    if (obj is! Map<String, dynamic>) continue;
    final seg = obj['activitySegment'] as Map<String, dynamic>?;
    if (seg == null) continue;

    final actType = seg['activityType'] as String? ?? '';
    if (!vehicleTypes.contains(actType)) continue;

    final duration = seg['duration'] as Map<String, dynamic>?;
    if (duration == null) continue;

    final startTs = duration['startTimestamp'] as String?;
    final endTs = duration['endTimestamp'] as String?;
    if (startTs == null || endTs == null) continue;

    final startDt = DateTime.tryParse(startTs);
    final endDt = DateTime.tryParse(endTs);
    if (startDt == null || endDt == null) continue;

    final distanceM = (seg['distance'] as num?)?.toDouble() ?? 0.0;

    final endLoc = seg['endLocation'] as Map<String, dynamic>?;
    final destName = endLoc?['name'] as String? ?? 'Google Import';
    final destAddress = endLoc?['address'] as String? ?? '';

    trips.add(Trip(
      id: '',
      date: startDt.toLocal().toIso8601String().substring(0, 10),
      startTime: _formatTime(startDt.toLocal()),
      endTime: _formatTime(endDt.toLocal()),
      destinationName: destName,
      destinationAddress: destAddress,
      distanceKm: distanceM / 1000.0,
      type: TripType.business,
      status: TripStatus.completed,
      isBilled: false,
      isLogged: false,
      notes: 'Importiert aus Google Timeline ($actType)',
      vehicleId: null,
    ));
  }

  return trips;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// "51.1234567, 13.1234567" → "51.123456,13.123456" (Google Maps kompatibel)
String _latLngToPlain(String latLng) {
  final parts = latLng.split(',');
  if (parts.length != 2) return latLng.trim();
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return latLng.trim();
  return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
}

