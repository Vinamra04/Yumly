import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String name;
  final double quantity;
  final DateTime expiryDate;
  final String category;
  final String unit;
  final String userId;

  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.expiryDate,
    required this.category,
    required this.unit,
    required this.userId,
  });

  // Factory constructor to create an InventoryItem from a Map (Firestore document)
  factory InventoryItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return InventoryItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      category: data['category'] ?? '',
      unit: data['unit'] ?? '',
      userId: data['userId'] ?? '',
    );
  }

  // Convert InventoryItem to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'category': category,
      'unit': unit,
      'userId': userId,
    };
  }

  // Create a copy of InventoryItem with optional new values
  InventoryItem copyWith({
    String? id,
    String? name,
    double? quantity,
    DateTime? expiryDate,
    String? category,
    String? unit,
    String? userId,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate ?? this.expiryDate,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      userId: userId ?? this.userId,
    );
  }

  bool get isExpiringSoon {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry >= 0;
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiryDate);
  }
} 