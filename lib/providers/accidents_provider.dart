import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/photo_storage.dart';

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
      // Migrate legacy base64 photos to file storage in background
      _migratePhotos();
    } catch (_) {
      // FIX: Korrupte Daten crashen die App nicht mehr
      state = [];
    }
  }

  /// Migrates inline base64 photo data to file-based storage.
  Future<void> _migratePhotos() async {
    bool changed = false;
    final updated = <AccidentReport>[];
    for (final report in state) {
      if (!report.photos.any(PhotoStorage.isBase64)) {
        updated.add(report);
        continue;
      }
      final newPhotos = <String>[];
      for (final photo in report.photos) {
        if (PhotoStorage.isBase64(photo)) {
          try {
            newPhotos.add(await PhotoStorage.instance.migrateBase64(photo));
            changed = true;
          } catch (_) {
            newPhotos.add(photo); // Keep original on failure
          }
        } else {
          newPhotos.add(photo);
        }
      }
      updated.add(report.copyWith(photos: newPhotos));
    }
    if (changed) {
      state = updated;
      _save();
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
