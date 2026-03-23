import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

final _defaultCustomers = [
  Customer(id: 'c1', name: 'Kundenmeeting GmbH', address: 'Musterstraße 1, 12345 Berlin'),
  Customer(id: 'c2', name: 'Steuerberater', address: 'Finanzplatz 1, München'),
  Customer(id: 'c3', name: 'Büro', address: 'Hauptstraße 42, 12345 Berlin'),
];

class CustomersNotifier extends StateNotifier<List<Customer>> {
  static const _boxKey = 'autolog_customers';

  CustomersNotifier() : super([]) {
    _load();
  }

  void _load() {
    try {
      final box = Hive.box('autolog');
      final raw = box.get(_boxKey);
      if (raw == null) {
        state = _defaultCustomers;
        return;
      }
      final List<dynamic> list = jsonDecode(raw as String);
      final customers = list
          .map((e) {
            try {
              return Customer.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<Customer>()
          .toList();
      state = customers.isEmpty ? _defaultCustomers : customers;
    } catch (_) {
      state = _defaultCustomers;
    }
  }

  void _save() {
    final box = Hive.box('autolog');
    box.put(_boxKey, jsonEncode(state.map((c) => c.toJson()).toList()));
  }

  void addCustomer(String name, String address) {
    if (state.any((c) => c.name.toLowerCase() == name.toLowerCase())) return;
    state = [...state, Customer(id: _uuid.v4(), name: name, address: address)];
    _save();
  }

  void loadCustomers(List<Customer> customers) {
    state = customers;
    _save();
  }
}

final customersProvider = StateNotifierProvider<CustomersNotifier, List<Customer>>(
  (ref) => CustomersNotifier(),
);
