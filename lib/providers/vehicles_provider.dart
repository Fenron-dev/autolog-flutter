import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

final _defaultVehicle = Vehicle(
  id: 'default-vehicle',
  name: 'Mein Auto',
  isDefault: true,
);

class VehiclesNotifier extends StateNotifier<List<Vehicle>> {
  static const _boxKey = 'autolog_vehicles';

  VehiclesNotifier() : super([]) {
    _load();
  }

  void _load() {
    try {
      final box = Hive.box('autolog');
      final raw = box.get(_boxKey);
      if (raw == null) {
        state = [_defaultVehicle];
        return;
      }
      final List<dynamic> list = jsonDecode(raw as String);
      final vehicles = list
          .map((e) {
            try {
              return Vehicle.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<Vehicle>()
          .toList();
      state = vehicles.isEmpty ? [_defaultVehicle] : vehicles;
    } catch (_) {
      state = [_defaultVehicle];
    }
  }

  void _save() {
    final box = Hive.box('autolog');
    box.put(_boxKey, jsonEncode(state.map((v) => v.toJson()).toList()));
  }

  void addVehicle(Vehicle vehicle) {
    final newVehicle = vehicle.copyWith(id: _uuid.v4());
    if (newVehicle.isDefault) {
      state = [...state.map((v) => v.copyWith(isDefault: false)), newVehicle];
    } else {
      state = [...state, newVehicle];
    }
    _save();
  }

  void updateVehicle(String id, Vehicle updated) {
    if (updated.isDefault) {
      state = state
          .map((v) => v.id == id ? updated : v.copyWith(isDefault: false))
          .toList();
    } else {
      state = state.map((v) => v.id == id ? updated : v).toList();
    }
    _save();
  }

  /// FIX: Kein direktes Mutieren mehr – immutable update
  void deleteVehicle(String id) {
    final next = state.where((v) => v.id != id).toList();
    if (next.isEmpty) {
      state = next;
      _save();
      return;
    }
    final hasDefault = next.any((v) => v.isDefault);
    if (!hasDefault) {
      state = [next.first.copyWith(isDefault: true), ...next.skip(1)];
    } else {
      state = next;
    }
    _save();
  }

  void setDefault(String id) {
    state = state.map((v) => v.copyWith(isDefault: v.id == id)).toList();
    _save();
  }
}

final vehiclesProvider = StateNotifierProvider<VehiclesNotifier, List<Vehicle>>(
  (ref) => VehiclesNotifier(),
);
