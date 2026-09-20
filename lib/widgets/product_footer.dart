import 'package:flutter/material.dart';

import 'auth_style.dart';

class ProductFooter extends StatelessWidget {
  const ProductFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          Divider(color: Nutri.divider, thickness: 0.5),
          const SizedBox(height: 12),
          Text(
            '© 2025/2026 I.I.S. Galileo Galilei',
            style: TextStyle(fontSize: 12, color: Nutri.muted),
          ),
          const SizedBox(height: 4),
          Text(
            'NutriApp v1.0.0',
            style: TextStyle(fontSize: 11, color: Nutri.hint),
          ),
        ],
      ),
    );
  }
}
