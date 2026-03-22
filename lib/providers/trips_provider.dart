import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

class TripsState {
  final List<Trip> activeTrips;
  final List<Trip> deletedTrips;
  final List<Trip> archivedTrips;

  const TripsState({
    this.activeTrips = const [],
    this.deletedTrips = const [],
    this.archivedTrips = const [],
  });

  int get plannedCount => activeTrips.where((t) => t.status == TripStatus.planned).length;
}

class TripsNotifier extends StateNotifier<TripsState> {
  static const _boxKey = 'autolog_trips';

  TripsNotifier() : super(const TripsState()) {
    _load();
  }

  void _load() {
    try {
      final box = Hive.box('autolog');
      final raw = box.get(_boxKey);
      if (raw == null) {
        state = const TripsState();
        return;
      }
      final List<dynamic> list = jsonDecode(raw as String);
      final trips = list
          .map((e) {
            try {
              return Trip.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<Trip>()
          .toList();
      state = _compute(trips);
    } catch (_) {
      state = const TripsState();
    }
  }

  void _save(List<Trip> trips) {
    final box = Hive.box('autolog');
    box.put(_boxKey, jsonEncode(trips.map((t) => t.toJson()).toList()));
  }

  TripsState _compute(List<Trip> all) {
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    final deleted = all.where((t) => t.isDeleted).toList();
    final nonDeleted = all.where((t) => !t.isDeleted).toList();
    final archived = nonDeleted.where((t) {
      final d = DateTime.tryParse(t.date);
      return d != null && d.isBefore(oneYearAgo);
    }).toList();
    final active = nonDeleted.where((t) {
      final d = DateTime.tryParse(t.date);
      return d == null || !d.isBefore(oneYearAgo);
    }).toList();
    return TripsState(activeTrips: active, deletedTrips: deleted, archivedTrips: archived);
  }

  List<Trip> get _all => [...state.activeTrips, ...state.deletedTrips, ...state.archivedTrips];

  void addTrip(Trip trip) {
    final trips = [..._all, trip];
    state = _compute(trips);
    _save(trips);
  }

  void updateTrip(String id, Trip updated) {
    final trips = _all.map((t) => t.id == id ? updated : t).toList();
    state = _compute(trips);
    _save(trips);
  }

  void deleteTrip(String id) {
    final trips = _all.map((t) => t.id == id ? t.copyWith(isDeleted: true) : t).toList();
    state = _compute(trips);
    _save(trips);
  }

  void hardDeleteTrip(String id) {
    final trips = _all.where((t) => t.id != id).toList();
    state = _compute(trips);
    _save(trips);
  }

  void restoreTrip(String id) {
    final trips = _all.map((t) => t.id == id ? t.copyWith(isDeleted: false) : t).toList();
    state = _compute(trips);
    _save(trips);
  }

  void toggleField(String id, String field, bool value) {
    final trips = _all.map((t) {
      if (t.id != id) return t;
      return field == 'isBilled'
          ? t.copyWith(isBilled: value)
          : t.copyWith(isLogged: value);
    }).toList();
    state = _compute(trips);
    _save(trips);
  }

  /// Erstellt eine Rückfahrt. Behebt Bug aus Web-App:
  /// - Datum wird auf nächsten Tag gesetzt wenn Endzeit der Hinfahrt < Startzeit
  /// - Duration wird korrekt berechnet
  void addReturnTrip(Trip original) {
    final startParts = original.startTime.split(':').map(int.tryParse).toList();
    final endParts = original.endTime.split(':').map(int.tryParse).toList();

    // Ungültiges Zeitformat – Rückfahrt kann nicht erstellt werden
    if (startParts.length < 2 || endParts.length < 2 ||
        startParts[0] == null || startParts[1] == null ||
        endParts[0] == null || endParts[1] == null) {
      return;
    }

    final startMins = startParts[0]! * 60 + startParts[1]!;
    final endMins = endParts[0]! * 60 + endParts[1]!;

    int durationMins = endMins - startMins;
    if (durationMins <= 0) durationMins += 24 * 60; // Mitternacht

    final returnEndMins = (endMins + durationMins);
    final returnEndH = (returnEndMins ~/ 60) % 24;
    final returnEndM = returnEndMins % 60;

    // FIX: Datum anpassen wenn Rückfahrt-Ende in den nächsten Tag fällt
    String returnDate = original.date;
    if (returnEndMins >= 24 * 60) {
      final d = DateTime.tryParse(original.date);
      if (d != null) {
        returnDate = d.add(const Duration(days: 1)).toIso8601String().substring(0, 10);
      }
    }

    final endTime = '${returnEndH.toString().padLeft(2, '0')}:${returnEndM.toString().padLeft(2, '0')}';

    final returnTrip = Trip(
      id: _uuid.v4(),
      date: returnDate,
      startTime: original.endTime,
      endTime: endTime,
      destinationName: 'Rückweg von ${original.destinationName}',
      destinationAddress: original.destinationAddress,
      distanceKm: original.distanceKm,
      type: original.type,
      status: TripStatus.completed,
      isBilled: false,
      isLogged: false,
      vehicleId: original.vehicleId,
    );
    addTrip(returnTrip);
  }

  void loadTrips(List<Trip> trips) {
    state = _compute(trips);
    _save(trips);
  }
}

final tripsProvider = StateNotifierProvider<TripsNotifier, TripsState>(
  (ref) => TripsNotifier(),
);
