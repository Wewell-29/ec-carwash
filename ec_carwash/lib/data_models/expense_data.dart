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
    Query query = _firestore.collection(_collection).orderBy('date', descending: true);

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ExpenseData.fromFirestore(doc)).toList();
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
