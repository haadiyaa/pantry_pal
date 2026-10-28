import 'package:equatable/equatable.dart';

enum Freshness { fresh, useSoon, expired }

class PantryItem extends Equatable {
  const PantryItem({
    this.id,
    required this.name,
    this.quantity = 1,
    this.category = 'Other',
    required this.expiryDate,
    this.barcode,
    required this.addedAt,
    this.notes,
  });

  final int? id;
  final String name;
  final int quantity;
  final String category;
  final DateTime expiryDate;
  final String? barcode;
  final DateTime addedAt;
  final String? notes;

  /// Whole days until expiry from [referenceDate] (defaults to current local date).
  /// A negative value means the item has already expired.
  ///
  /// Uses UTC calendar dates to prevent Daylight Saving Time transitions
  /// (e.g. 23-hour or 25-hour days) from causing off-by-one errors when
  /// calculating difference in days.
  int daysLeftAt(DateTime referenceDate) {
    final refUtc = DateTime.utc(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final expiryUtc = DateTime.utc(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    return expiryUtc.difference(refUtc).inDays;
  }

  /// Whole days until expiry relative to today.
  int get daysLeft => daysLeftAt(DateTime.now());

  /// Freshness classification evaluated at [referenceDate].
  Freshness freshnessAt(DateTime referenceDate) {
    final d = daysLeftAt(referenceDate);
    if (d < 0) return Freshness.expired;
    if (d <= 3) return Freshness.useSoon;
    return Freshness.fresh;
  }

  /// Freshness classification relative to today.
  Freshness get freshness => freshnessAt(DateTime.now());

  PantryItem copyWith({
    int? id,
    String? name,
    int? quantity,
    String? category,
    DateTime? expiryDate,
    String? barcode,
    DateTime? addedAt,
    String? notes,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      barcode: barcode ?? this.barcode,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'category': category,
        'expiry_date': expiryDate.millisecondsSinceEpoch,
        'barcode': barcode,
        'added_at': addedAt.millisecondsSinceEpoch,
        'notes': notes,
      };

  factory PantryItem.fromMap(Map<String, Object?> map) => PantryItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        quantity: map['quantity'] as int,
        category: map['category'] as String,
        expiryDate:
            DateTime.fromMillisecondsSinceEpoch(map['expiry_date'] as int),
        barcode: map['barcode'] as String?,
        addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
        notes: map['notes'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, name, quantity, category, expiryDate, barcode, addedAt, notes];
}
