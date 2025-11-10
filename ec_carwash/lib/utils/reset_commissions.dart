import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility to reset all team commissions to 0 in Bookings collection
class CommissionResetter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reset all teamCommission values to 0 in Bookings collection
  static Future<int> resetAllCommissions() async {
    try {
      debugPrint('🔄 Starting commission reset...');

      // Get all bookings
      final bookingsSnapshot = await _firestore.collection('Bookings').get();

      debugPrint('📊 Found ${bookingsSnapshot.docs.length} bookings to reset');

      int resetCount = 0;
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final currentCommission = (data['teamCommission'] as num?)?.toDouble() ?? 0.0;

        // Only update if commission is not already 0
        if (currentCommission != 0.0) {
          batch.update(doc.reference, {
            'teamCommission': 0.0,
            'salaryDisbursed': false, // Also reset disbursement flag
          });
          batchCount++;
          resetCount++;

          // Firestore batch limit is 500 operations
          if (batchCount >= 500) {
            debugPrint('💾 Committing batch of $batchCount updates...');
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      // Commit remaining batch
      if (batchCount > 0) {
        debugPrint('💾 Committing final batch of $batchCount updates...');
        await batch.commit();
      }

      debugPrint('✅ Commission reset complete: $resetCount bookings updated');
      return resetCount;
    } catch (e) {
      debugPrint('❌ Error resetting commissions: $e');
      rethrow;
    }
  }

  /// Reset commissions for a specific date range
  static Future<int> resetCommissionsInDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint('🔄 Starting commission reset for date range...');
      debugPrint('   Range: ${startDate.toString()} to ${endDate.toString()}');

      final bookingsSnapshot = await _firestore.collection('Bookings').get();

      int resetCount = 0;
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate() ??
                           (data['updatedAt'] as Timestamp?)?.toDate();

        if (completedAt == null) continue;

        // Check if in date range
        if (completedAt.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            completedAt.isBefore(endDate.add(const Duration(days: 1)))) {

          final currentCommission = (data['teamCommission'] as num?)?.toDouble() ?? 0.0;

          if (currentCommission != 0.0) {
            batch.update(doc.reference, {
              'teamCommission': 0.0,
              'salaryDisbursed': false,
            });
            batchCount++;
            resetCount++;

            if (batchCount >= 500) {
              await batch.commit();
              batch = _firestore.batch();
              batchCount = 0;
            }
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      debugPrint('✅ Commission reset complete: $resetCount bookings updated');
      return resetCount;
    } catch (e) {
      debugPrint('❌ Error resetting commissions: $e');
      rethrow;
    }
  }
}
