import 'package:uuid/uuid.dart';

enum TripType { business, private }
enum TripStatus { completed, planned }

class Trip {
  final String id;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String destinationName;
  final String destinationAddress;
  final double distanceKm;
  final TripType type;
  final TripStatus status;
  final bool isBilled;
  final bool isLogged;
  final String notes;
  final bool isDeleted;
  final String? vehicleId;

  const Trip({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.destinationName,
    required this.destinationAddress,
    required this.distanceKm,
    required this.type,
    required this.status,
    required this.isBilled,
    required this.isLogged,
    this.notes = '',
    this.isDeleted = false,
    this.vehicleId,
  });

  Trip copyWith({
    String? id,
    String? date,
    String? startTime,
    String? endTime,
    String? destinationName,
    String? destinationAddress,
    double? distanceKm,
    TripType? type,
    TripStatus? status,
    bool? isBilled,
    bool? isLogged,
    String? notes,
    bool? isDeleted,
    Object? vehicleId = _sentinel,
  }) {
    return Trip(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      destinationName: destinationName ?? this.destinationName,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      distanceKm: distanceKm ?? this.distanceKm,
      type: type ?? this.type,
      status: status ?? this.status,
      isBilled: isBilled ?? this.isBilled,
      isLogged: isLogged ?? this.isLogged,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      vehicleId: vehicleId == _sentinel ? this.vehicleId : vehicleId as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'destinationName': destinationName,
    'destinationAddress': destinationAddress,
    'distanceKm': distanceKm,
    'type': type.name,
    'status': status.name,
    'isBilled': isBilled,
    'isLogged': isLogged,
    'notes': notes,
    'isDeleted': isDeleted,
    'vehicleId': vehicleId,
  };

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String? ?? const Uuid().v4(),
      date: json['date'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      destinationName: json['destinationName'] as String? ?? '',
      destinationAddress: json['destinationAddress'] as String? ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] == 'private' ? TripType.private : TripType.business,
      status: json['status'] == 'planned' ? TripStatus.planned : TripStatus.completed,
      isBilled: json['isBilled'] as bool? ?? false,
      isLogged: json['isLogged'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
      vehicleId: json['vehicleId'] as String?,
    );
  }
}

const _sentinel = Object();
