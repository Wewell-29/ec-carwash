import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility to delete all transactions and bookings
class DataDeleter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Delete all documents in Transactions collection
  static Future<int> deleteAllTransactions() async {
    try {
      debugPrint('🗑️ Starting deletion of all transactions...');

      final snapshot = await _firestore.collection('Transactions').get();
      debugPrint('📊 Found ${snapshot.docs.length} transactions to delete');

      int deletedCount = 0;
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        deletedCount++;

        // Firestore batch limit is 500 operations
        if (batchCount >= 500) {
          debugPrint('💾 Committing batch of $batchCount deletions...');
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      // Commit remaining batch
      if (batchCount > 0) {
        debugPrint('💾 Committing final batch of $batchCount deletions...');
        await batch.commit();
      }

      debugPrint('✅ Deletion complete: $deletedCount transactions deleted');
      return deletedCount;
    } catch (e) {
      debugPrint('❌ Error deleting transactions: $e');
      rethrow;
    }
  }

  /// Delete all documents in Bookings collection
  static Future<int> deleteAllBookings() async {
    try {
      debugPrint('🗑️ Starting deletion of all bookings...');

      final snapshot = await _firestore.collection('Bookings').get();
      debugPrint('📊 Found ${snapshot.docs.length} bookings to delete');

      int deletedCount = 0;
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        batchCount++;
        deletedCount++;

        // Firestore batch limit is 500 operations
        if (batchCount >= 500) {
          debugPrint('💾 Committing batch of $batchCount deletions...');
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      // Commit remaining batch
      if (batchCount > 0) {
        debugPrint('💾 Committing final batch of $batchCount deletions...');
        await batch.commit();
      }

      debugPrint('✅ Deletion complete: $deletedCount bookings deleted');
      return deletedCount;
    } catch (e) {
      debugPrint('❌ Error deleting bookings: $e');
      rethrow;
    }
  }

  /// Delete both transactions and bookings
  static Future<Map<String, int>> deleteAllTransactionsAndBookings() async {
    final transactionsDeleted = await deleteAllTransactions();
    final bookingsDeleted = await deleteAllBookings();

    return {
      'transactions': transactionsDeleted,
      'bookings': bookingsDeleted,
    };
  }
}
