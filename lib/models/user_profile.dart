import 'nutrient_limits.dart';

class UserProfile {
  final String name;
  final String? surname;
  final String email;
  final String? photoPath;
  final bool personalizedPlan;
  final String? gender;
  final int? age;
  final double? heightCm;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final NutrientLimits? nutrientLimits;
  final DateTime? createdAt;

  const UserProfile({
    required this.name,
    this.surname,
    required this.email,
    this.photoPath,
    this.personalizedPlan = false,
    this.gender,
    this.age,
    this.heightCm,
    this.currentWeightKg,
    this.targetWeightKg,
    this.nutrientLimits,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      'personalized_plan': personalizedPlan ? 1 : 0,
    };

    if (gender != null) data['gender'] = gender;
    if (surname != null) data['surname'] = surname;
    if (photoPath != null) data['photo_path'] = photoPath;
    if (age != null) data['age'] = age;
    if (heightCm != null) data['height_cm'] = heightCm;
    if (currentWeightKg != null) data['current_weight_kg'] = currentWeightKg;
    if (targetWeightKg != null) data['target_weight_kg'] = targetWeightKg;
    if (createdAt != null) {
      data['created_at'] =
          '${createdAt!.year}-${createdAt!.month.toString().padLeft(2, '0')}-${createdAt!.day.toString().padLeft(2, '0')}';
    }
    if (nutrientLimits != null) {
      data['nutrient_limits'] = nutrientLimits!.toJson();
    }

    return data;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return UserProfile(
      name: json['name'] ?? '',
      surname: json['surname'],
      email: json['email'] ?? '',
      photoPath: json['photo_path'],
      personalizedPlan: json['personalized_plan'] == 1 ||
          json['personalized_plan'] == '1' ||
          json['personalized_plan'] == true,
      gender: json['gender'],
      age: json['age'] != null ? int.tryParse(json['age'].toString()) : null,
      heightCm: json['height_cm'] != null
          ? double.tryParse(json['height_cm'].toString().replaceAll(',', '.'))
          : null,
      currentWeightKg: json['current_weight_kg'] != null
          ? double.tryParse(
              json['current_weight_kg'].toString().replaceAll(',', '.'))
          : null,
      targetWeightKg: json['target_weight_kg'] != null
          ? double.tryParse(
              json['target_weight_kg'].toString().replaceAll(',', '.'))
          : null,
      nutrientLimits: json['nutrient_limits'] is Map<String, dynamic>
          ? NutrientLimits.fromJson(json['nutrient_limits'])
          : null,
      createdAt: parseDate(json['created_at']),
    );
  }
}
