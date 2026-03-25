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
  final String? deletedAt; // ISO timestamp – for auto-purge after 30 days
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
    this.deletedAt,
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
    Object? deletedAt = _sentinel,
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
      deletedAt: deletedAt == _sentinel ? this.deletedAt : deletedAt as String?,
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
    'deletedAt': deletedAt,
    'vehicleId': vehicleId,
  };

  static final _dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _timeRegex = RegExp(r'^\d{2}:\d{2}$');

  factory Trip.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String? ?? '';
    // Validate date format: must be YYYY-MM-DD and parseable
    final date = (_dateRegex.hasMatch(rawDate) && DateTime.tryParse(rawDate) != null)
        ? rawDate : '';
    final rawStart = json['startTime'] as String? ?? '';
    final rawEnd = json['endTime'] as String? ?? '';
    return Trip(
      id: json['id'] as String? ?? const Uuid().v4(),
      date: date,
      startTime: _timeRegex.hasMatch(rawStart) ? rawStart : '',
      endTime: _timeRegex.hasMatch(rawEnd) ? rawEnd : '',
      destinationName: json['destinationName'] as String? ?? '',
      destinationAddress: json['destinationAddress'] as String? ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] == 'private' ? TripType.private : TripType.business,
      status: json['status'] == 'planned' ? TripStatus.planned : TripStatus.completed,
      isBilled: json['isBilled'] as bool? ?? false,
      isLogged: json['isLogged'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] as String?,
      vehicleId: json['vehicleId'] as String?,
    );
  }
}

const _sentinel = Object();
