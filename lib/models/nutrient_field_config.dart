import 'package:flutter/material.dart';

class NutrientFieldConfig {
  final String label;
  final TextEditingController controller;
  final String suffix;
  final String hint;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final Color? dotColor;
  final String? trailingHint;

  const NutrientFieldConfig({
    required this.label,
    required this.controller,
    this.suffix = '',
    this.hint = '',
    this.keyboardType = TextInputType.number,
    this.validator,
    this.readOnly = false,
    this.dotColor,
    this.trailingHint,
  });
}
