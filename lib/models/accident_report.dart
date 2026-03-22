import 'package:uuid/uuid.dart';

class AccidentReport {
  final String id;
  final String date; // YYYY-MM-DD
  final String time; // HH:mm
  final String location;
  final String otherPartyName;
  final String otherPartyAddress;
  final String otherPartyPhone;
  final String otherPartyInsurance;
  final String remarks;
  final List<String> photos; // base64 strings

  const AccidentReport({
    required this.id,
    required this.date,
    required this.time,
    required this.location,
    this.otherPartyName = '',
    this.otherPartyAddress = '',
    this.otherPartyPhone = '',
    this.otherPartyInsurance = '',
    this.remarks = '',
    this.photos = const [],
  });

  AccidentReport copyWith({
    String? id,
    String? date,
    String? time,
    String? location,
    String? otherPartyName,
    String? otherPartyAddress,
    String? otherPartyPhone,
    String? otherPartyInsurance,
    String? remarks,
    List<String>? photos,
  }) {
    return AccidentReport(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      otherPartyName: otherPartyName ?? this.otherPartyName,
      otherPartyAddress: otherPartyAddress ?? this.otherPartyAddress,
      otherPartyPhone: otherPartyPhone ?? this.otherPartyPhone,
      otherPartyInsurance: otherPartyInsurance ?? this.otherPartyInsurance,
      remarks: remarks ?? this.remarks,
      photos: photos ?? this.photos,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'time': time,
    'location': location,
    'otherPartyName': otherPartyName,
    'otherPartyAddress': otherPartyAddress,
    'otherPartyPhone': otherPartyPhone,
    'otherPartyInsurance': otherPartyInsurance,
    'remarks': remarks,
    'photos': photos,
  };

  factory AccidentReport.fromJson(Map<String, dynamic> json) {
    return AccidentReport(
      id: json['id'] as String? ?? const Uuid().v4(),
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      location: json['location'] as String? ?? '',
      otherPartyName: json['otherPartyName'] as String? ?? '',
      otherPartyAddress: json['otherPartyAddress'] as String? ?? '',
      otherPartyPhone: json['otherPartyPhone'] as String? ?? '',
      otherPartyInsurance: json['otherPartyInsurance'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
