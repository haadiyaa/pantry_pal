import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../inventory/domain/models/pantry_event.dart';
import '../../../inventory/domain/models/pantry_event_reason.dart';

/// Debug-only generator producing ~60 realistic sample events across 4 months.
/// Designed for generating comprehensive screenshot data in developer mode.
class StatsSampleDataGenerator {
  const StatsSampleDataGenerator();

  /// Constant marker embedded in sample event names or handled via repository tracking.
  static const String sampleTag = '[SAMPLE]';

  List<PantryEvent> generateSampleEvents(DateTime now) {
    if (!kDebugMode) {
      // Safety guard: never generate in release builds
      return const [];
    }

    final events = <PantryEvent>[];
    final random = Random(42); // Fixed seed for reproducible realistic screenshots

    final sampleCatalog = [
      _SampleTemplate('Amul Gold Milk', 'Dairy', 3400, 3),
      _SampleTemplate('Greek Yogurt', 'Dairy', 5000, 7),
      _SampleTemplate('Curd', 'Dairy', 4000, 5),
      _SampleTemplate('Paneer', 'Dairy', 9500, 4),
      _SampleTemplate('Spinach', 'Vegetables', 2500, 4),
      _SampleTemplate('Tomatoes', 'Vegetables', 4000, 7),
      _SampleTemplate('Coriander', 'Vegetables', 1500, 3),
      _SampleTemplate('Bananas', 'Fruits', 5000, 5),
      _SampleTemplate('Apples', 'Fruits', 12000, 14),
      _SampleTemplate('Whole Wheat Bread', 'Grains', 4500, 5),
      _SampleTemplate('Basmati Rice', 'Grains', 16000, 180),
      _SampleTemplate('Eggs 6-pack', 'Meat and Fish', 5500, 14),
      _SampleTemplate('Chicken Breast', 'Meat and Fish', 24000, 3),
      _SampleTemplate('Potato Chips', 'Snacks', 3000, 90),
      _SampleTemplate('Orange Juice', 'Beverages', 9000, 10),
    ];

    // Spread ~60 events over past 120 days (4 months)
    for (var i = 118; i >= 1; i -= 2) {
      final daysAgo = i;
      final occurredAt = DateTime(now.year, now.month, now.day - daysAgo, 10 + (i % 8));
      final template = sampleCatalog[random.nextInt(sampleCatalog.length)];

      // 70% used, 25% wasted, 5% deleted
      final roll = random.nextDouble();
      final PantryEventReason reason;
      final DateTime expiryDate;

      if (roll < 0.70) {
        reason = PantryEventReason.used;
        // Mostly used 1-3 days before expiry (rescued), 10% used after expiry (used late)
        final isLate = random.nextDouble() < 0.10;
        expiryDate = isLate
            ? occurredAt.subtract(Duration(days: 1 + random.nextInt(2)))
            : occurredAt.add(Duration(days: 1 + random.nextInt(template.shelfLifeDays)));
      } else if (roll < 0.95) {
        reason = PantryEventReason.wasted;
        // Wasted items expired 1-3 days before being thrown away
        expiryDate = occurredAt.subtract(Duration(days: 1 + random.nextInt(3)));
      } else {
        reason = PantryEventReason.deleted;
        expiryDate = occurredAt.add(Duration(days: template.shelfLifeDays));
      }

      final quantity = 1 + (random.nextInt(10) == 0 ? 1 : 0); // Mostly 1, occasionally 2
      final hasPrice = random.nextDouble() < 0.85; // 85% price coverage

      events.add(
        PantryEvent(
          itemName: '$sampleTag ${template.name}',
          category: template.category,
          quantity: quantity,
          pricePaise: hasPrice ? template.unitPricePaise : null,
          expiryDate: expiryDate,
          reason: reason,
          occurredAt: occurredAt,
        ),
      );
    }

    return events;
  }
}

class _SampleTemplate {
  const _SampleTemplate(
    this.name,
    this.category,
    this.unitPricePaise,
    this.shelfLifeDays,
  );

  final String name;
  final String category;
  final int unitPricePaise;
  final int shelfLifeDays;
}

