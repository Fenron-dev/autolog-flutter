import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  final String name;
  final String address;

  const Customer({
    required this.id,
    required this.name,
    this.address = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }
}
