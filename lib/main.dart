import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/main_shell.dart';
import 'providers/providers.dart';
import 'theme/app_theme.dart';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
const _hiveKeyName = 'autolog_hive_key';

Future<HiveAesCipher> _getOrCreateCipher() async {
  final existing = await _secureStorage.read(key: _hiveKeyName);
  if (existing != null) {
    return HiveAesCipher(base64Decode(existing));
  }
  final key = Hive.generateSecureKey();
  await _secureStorage.write(key: _hiveKeyName, value: base64Encode(key));
  return HiveAesCipher(key);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final cipher = await _getOrCreateCipher();
  await Hive.openBox('autolog', encryptionCipher: cipher);
  runApp(const ProviderScope(child: AutoLogApp()));
}

class AutoLogApp extends ConsumerWidget {
  const AutoLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = switch (settings.theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: 'AutoLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const MainShell(),
    );
  }
}
