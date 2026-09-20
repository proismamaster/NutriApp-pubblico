import 'package:flutter/material.dart';

import 'auth_style.dart';
import '../models/nutrient_field_config.dart';
import 'nutrient_input_field.dart';

class NutrientGroup extends StatelessWidget {
  final String title;
  final List<NutrientFieldConfig> configs;
  final String searchTerm;
  final IconData? icon;

  /// Cascata a tutti i campi del gruppo — vedi `NutrientInputField.outlined`.
  final bool outlined;

  const NutrientGroup({
    super.key,
    required this.title,
    required this.configs,
    this.searchTerm = '',
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final filteredConfigs = configs.where((config) {
      if (searchTerm.isEmpty) return true;
      return config.label.toLowerCase().contains(searchTerm.toLowerCase());
    }).toList();

    if (filteredConfigs.isEmpty && searchTerm.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Nutri.green, size: 24),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        ...filteredConfigs.map((config) => NutrientInputField(
              label: config.label,
              hint: config.hint,
              suffix: config.suffix,
              controller: config.controller,
              keyboardType: config.keyboardType,
              validator: config.validator,
              readOnly: config.readOnly,
              dotColor: config.dotColor,
              trailingHint: config.trailingHint,
              outlined: outlined,
            )),
      ],
    );
  }
}
