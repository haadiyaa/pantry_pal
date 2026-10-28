import 'package:flutter/material.dart';

/// Fixed pantry categories with associated icons and labels.
enum PantryCategory {
  dairy('Dairy', Icons.egg_alt_outlined),
  vegetables('Vegetables', Icons.eco_outlined),
  fruits('Fruits', Icons.apple_outlined),
  meatAndFish('Meat and Fish', Icons.set_meal_outlined),
  grains('Grains', Icons.grain_outlined),
  snacks('Snacks', Icons.cookie_outlined),
  beverages('Beverages', Icons.local_cafe_outlined),
  frozen('Frozen', Icons.ac_unit_outlined),
  other('Other', Icons.inventory_2_outlined);

  const PantryCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Safely parse a category from a string stored in the database.
  /// Falls back to [PantryCategory.other] if not matched.
  static PantryCategory fromString(String? name) {
    if (name == null || name.trim().isEmpty) return PantryCategory.other;
    return PantryCategory.values.firstWhere(
      (c) => c.label.toLowerCase() == name.trim().toLowerCase(),
      orElse: () => PantryCategory.other,
    );
  }
}

