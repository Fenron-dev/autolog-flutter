import 'package:uuid/uuid.dart';

class Vehicle {
  final String id;
  final String name;
  final String manufacturer;
  final String licensePlate;
  final double initialMileage;
  final String? initialMileageDate; // YYYY-MM-DD
  final bool isDefault;

  const Vehicle({
    required this.id,
    required this.name,
    this.manufacturer = '',
    this.licensePlate = '',
    this.initialMileage = 0,
    this.initialMileageDate,
    this.isDefault = false,
  });

  Vehicle copyWith({
    String? id,
    String? name,
    String? manufacturer,
    String? licensePlate,
    double? initialMileage,
    Object? initialMileageDate = _sentinel,
    bool? isDefault,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      licensePlate: licensePlate ?? this.licensePlate,
      initialMileage: initialMileage ?? this.initialMileage,
      initialMileageDate: initialMileageDate == _sentinel
          ? this.initialMileageDate
          : initialMileageDate as String?,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'manufacturer': manufacturer,
    'licensePlate': licensePlate,
    'initialMileage': initialMileage,
    'initialMileageDate': initialMileageDate,
    'isDefault': isDefault,
  };

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Fahrzeug',
      manufacturer: json['manufacturer'] as String? ?? '',
      licensePlate: json['licensePlate'] as String? ?? '',
      initialMileage: (json['initialMileage'] as num?)?.toDouble() ?? 0,
      initialMileageDate: json['initialMileageDate'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

const _sentinel = Object();
