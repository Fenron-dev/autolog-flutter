import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

class AccidentsNotifier extends StateNotifier<List<AccidentReport>> {
  static const _boxKey = 'autolog_accidents';

  AccidentsNotifier() : super([]) {
    _load();
  }

  void _load() {
    try {
      final box = Hive.box('autolog');
      final raw = box.get(_boxKey);
      if (raw == null) {
        state = [];
        return;
      }
      final List<dynamic> list = jsonDecode(raw as String);
      state = list
          .map((e) {
            try {
              return AccidentReport.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<AccidentReport>()
          .toList();
    } catch (_) {
      // FIX: Korrupte Daten crashen die App nicht mehr
      state = [];
    }
  }

  void _save() {
    final box = Hive.box('autolog');
    box.put(_boxKey, jsonEncode(state.map((a) => a.toJson()).toList()));
  }

  void addAccident(AccidentReport accident) {
    final newAccident = accident.copyWith(id: _uuid.v4());
    state = [newAccident, ...state];
    _save();
  }

  void updateAccident(String id, AccidentReport updated) {
    state = state.map((a) => a.id == id ? updated : a).toList();
    _save();
  }

  void deleteAccident(String id) {
    state = state.where((a) => a.id != id).toList();
    _save();
  }

  void loadAccidents(List<AccidentReport> accidents) {
    state = accidents;
    _save();
  }
}

final accidentsProvider = StateNotifierProvider<AccidentsNotifier, List<AccidentReport>>(
  (ref) => AccidentsNotifier(),
);
