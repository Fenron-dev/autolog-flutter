import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const _boxKey = 'autolog_settings';

  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  void _load() {
    try {
      final box = Hive.box('autolog');
      final raw = box.get(_boxKey);
      if (raw == null) {
        state = const AppSettings();
        return;
      }
      state = AppSettings.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
    } catch (_) {
      state = const AppSettings();
    }
  }

  void _save() {
    final box = Hive.box('autolog');
    box.put(_boxKey, jsonEncode(state.toJson()));
  }

  void updateSettings(AppSettings updated) {
    state = updated;
    _save();
  }

  ThemeMode get themeMode {
    switch (state.theme) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
