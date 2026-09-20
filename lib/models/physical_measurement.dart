class PhysicalMeasurement {
  final DateTime date;
  final double weight; // in kg
  final double? height; // in cm, optional
  final double? bodyFat; // percentage, optional

  PhysicalMeasurement({
    required this.date,
    required this.weight,
    this.height,
    this.bodyFat,
  });

  factory PhysicalMeasurement.fromJson(Map<String, dynamic> json) {
    return PhysicalMeasurement(
      date: DateTime.parse(json['date']),
      weight: double.tryParse(json['weight'].toString()) ?? 0.0,
      height: json['height'] != null ? double.tryParse(json['height'].toString()) : null,
      bodyFat: json['body_fat'] != null ? double.tryParse(json['body_fat'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson(String userEmail) {
    return {
      'user_email': userEmail,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
      'weight': weight,
      'height': height,
      'body_fat': bodyFat,
    };
  }
}
