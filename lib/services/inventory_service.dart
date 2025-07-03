import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inventory_item.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's inventory collection reference
  CollectionReference<Map<String, dynamic>> _getInventoryRef() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('inventory');
  }

  // Stream of inventory items
  Stream<List<InventoryItem>> getInventoryItems() {
    return _getInventoryRef().snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => InventoryItem.fromFirestore(doc))
          .toList();
    });
  }

  // Add new inventory item
  Future<void> addItem(InventoryItem item) async {
    await _getInventoryRef().add(item.toMap());
  }

  // Update existing inventory item
  Future<void> updateItem(InventoryItem item) async {
    await _getInventoryRef().doc(item.id).update(item.toMap());
  }

  // Delete inventory item
  Future<void> deleteItem(String itemId) async {
    await _getInventoryRef().doc(itemId).delete();
  }

  // Get items expiring soon (within 7 days)
  Stream<List<InventoryItem>> getExpiringItems() {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));

    return _getInventoryRef()
        .where('expiryDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(now),
            isLessThanOrEqualTo: Timestamp.fromDate(sevenDaysLater))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InventoryItem.fromFirestore(doc))
          .toList();
    });
  }
} 