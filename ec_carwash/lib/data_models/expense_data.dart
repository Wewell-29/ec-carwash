import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseData {
  final String? id;
  final DateTime date;
  final String category; // Utilities, Maintenance, Supplies, Miscellaneous
  final String description;
  final double amount;
  final int? quantity; // For supplies
  final String? vendor;
  final String? notes;
  final String? inventoryItemId; // Link to inventory if category is Supplies
  final String? inventoryItemName;
  final String addedBy;
  final DateTime createdAt;

  ExpenseData({
    this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    this.quantity,
    this.vendor,
    this.notes,
    this.inventoryItemId,
    this.inventoryItemName,
    required this.addedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'category': category,
      'description': description,
      'amount': amount,
      'quantity': quantity,
      'vendor': vendor,
      'notes': notes,
      'inventoryItemId': inventoryItemId,
      'inventoryItemName': inventoryItemName,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ExpenseData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseData(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      quantity: data['quantity'],
      vendor: data['vendor'],
      notes: data['notes'],
      inventoryItemId: data['inventoryItemId'],
      inventoryItemName: data['inventoryItemName'],
      addedBy: data['addedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

class ExpenseManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'expenses';

  // Add expense
  static Future<String> addExpense(ExpenseData expense) async {
    final docRef = await _firestore.collection(_collection).add(expense.toFirestore());
    return docRef.id;
  }

  // Get all expenses
  static Future<List<ExpenseData>> getExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    // To avoid Firebase composite index requirement, we'll use client-side filtering
    // when combining category filter with date range

    Query query = _firestore.collection(_collection).orderBy('date', descending: true);

    // Only apply server-side filters if using date range WITHOUT category
    // or category WITHOUT date range to avoid index requirement
    bool needsClientSideFiltering = false;

    // Strategy: Avoid composite indexes by doing client-side filtering when needed
    if (category != null && category != 'All') {
      // Category filter - just get by category, sort client-side
      query = _firestore.collection(_collection).where('category', isEqualTo: category);
      needsClientSideFiltering = true; // Will filter dates and sort client-side
    } else if (startDate != null || endDate != null) {
      // Date filter only - can use server-side with orderBy
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
    }
    // else: no filters, just orderBy date (already set above)

    final snapshot = await query.get();
    List<ExpenseData> expenses = snapshot.docs.map((doc) => ExpenseData.fromFirestore(doc)).toList();

    // Apply client-side filtering if needed
    if (needsClientSideFiltering) {
      // Filter by date range if specified
      if (startDate != null) {
        expenses = expenses.where((expense) => !expense.date.isBefore(startDate)).toList();
      }
      if (endDate != null) {
        expenses = expenses.where((expense) => !expense.date.isAfter(endDate)).toList();
      }

      // Sort by date descending (client-side)
      expenses.sort((a, b) => b.date.compareTo(a.date));
    }

    // Apply limit after filtering
    if (limit != null && expenses.length > limit) {
      expenses = expenses.sublist(0, limit);
    }

    return expenses;
  }

  // Get expense by ID
  static Future<ExpenseData?> getExpense(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return ExpenseData.fromFirestore(doc);
    }
    return null;
  }

  // Update expense
  static Future<void> updateExpense(String id, ExpenseData expense) async {
    await _firestore.collection(_collection).doc(id).update(expense.toFirestore());
  }

  // Delete expense
  static Future<void> deleteExpense(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Get total expenses by category
  static Future<Map<String, double>> getTotalsByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final expenses = await getExpenses(
      startDate: startDate,
      endDate: endDate,
    );

    final Map<String, double> totals = {
      'Utilities': 0.0,
      'Maintenance': 0.0,
      'Supplies': 0.0,
      'Miscellaneous': 0.0,
    };

    for (final expense in expenses) {
      totals[expense.category] = (totals[expense.category] ?? 0.0) + expense.amount;
    }

    return totals;
  }
}
