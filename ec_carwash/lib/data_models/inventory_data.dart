import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final int currentStock;
  final int minStock;
  final double unitPrice;
  final String unit;
  final DateTime lastUpdated;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.minStock,
    required this.unitPrice,
    required this.unit,
    required this.lastUpdated,
  });

  bool get isLowStock => currentStock <= minStock;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? currentStock,
    int? minStock,
    double? unitPrice,
    String? unit,
    DateTime? lastUpdated,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'currentStock': currentStock,
      'minStock': minStock,
      'unitPrice': unitPrice,
      'unit': unit,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      currentStock: json['currentStock'],
      minStock: json['minStock'],
      unitPrice: json['unitPrice'].toDouble(),
      unit: json['unit'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  factory InventoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItem(
      id: doc.id,
      name: data['name'],
      category: data['category'],
      currentStock: data['currentStock'],
      minStock: data['minStock'],
      unitPrice: data['unitPrice'].toDouble(),
      unit: data['unit'],
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'currentStock': currentStock,
      'minStock': minStock,
      'unitPrice': unitPrice,
      'unit': unit,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

List<InventoryItem> inventoryData = [
  InventoryItem(
    id: 'INV001',
    name: 'Car Shampoo',
    category: 'Cleaning Supplies',
    currentStock: 25,
    minStock: 10,
    unitPrice: 250.0,
    unit: 'bottles',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV002',
    name: 'Tire Cleaner',
    category: 'Cleaning Supplies',
    currentStock: 8,
    minStock: 10,
    unitPrice: 180.0,
    unit: 'bottles',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV003',
    name: 'Armor All Spray Wax',
    category: 'Wax & Polish',
    currentStock: 15,
    minStock: 5,
    unitPrice: 320.0,
    unit: 'bottles',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV004',
    name: 'Hand Wax',
    category: 'Wax & Polish',
    currentStock: 12,
    minStock: 8,
    unitPrice: 450.0,
    unit: 'containers',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV005',
    name: 'Polishing Compound',
    category: 'Wax & Polish',
    currentStock: 6,
    minStock: 5,
    unitPrice: 380.0,
    unit: 'containers',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV006',
    name: 'Glass Cleaner',
    category: 'Cleaning Supplies',
    currentStock: 20,
    minStock: 10,
    unitPrice: 150.0,
    unit: 'bottles',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV007',
    name: 'Engine Degreaser',
    category: 'Cleaning Supplies',
    currentStock: 14,
    minStock: 8,
    unitPrice: 220.0,
    unit: 'bottles',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV008',
    name: 'Microfiber Towels',
    category: 'Equipment',
    currentStock: 30,
    minStock: 20,
    unitPrice: 25.0,
    unit: 'pieces',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV009',
    name: 'Foam Brushes',
    category: 'Equipment',
    currentStock: 12,
    minStock: 8,
    unitPrice: 45.0,
    unit: 'pieces',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV010',
    name: 'Vacuum Bags',
    category: 'Equipment',
    currentStock: 5,
    minStock: 10,
    unitPrice: 35.0,
    unit: 'pieces',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV011',
    name: 'Interior Cleaner',
    category: 'Cleaning Supplies',
    currentStock: 18,
    minStock: 12,
    unitPrice: 280.0,
    unit: 'bottles',
    lastUpdated: DateTime.now(),
  ),
  InventoryItem(
    id: 'INV012',
    name: 'Tire Shine',
    category: 'Finishing Products',
    currentStock: 22,
    minStock: 15,
    unitPrice: 195.0,
    unit: 'bottles',
    lastUpdated: DateTime.now(),
  ),
];

class InventoryLog {
  final String? id;
  final String itemId;
  final String itemName;
  final int quantity;
  final String staffName;
  final String action; // 'withdraw', 'add', 'adjust'
  final String? notes;
  final DateTime timestamp;
  final int stockBefore;
  final int stockAfter;

  InventoryLog({
    this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.staffName,
    required this.action,
    this.notes,
    required this.timestamp,
    required this.stockBefore,
    required this.stockAfter,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'staffName': staffName,
      'action': action,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
      'stockBefore': stockBefore,
      'stockAfter': stockAfter,
    };
  }

  factory InventoryLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryLog(
      id: doc.id,
      itemId: data['itemId'],
      itemName: data['itemName'],
      quantity: data['quantity'],
      staffName: data['staffName'],
      action: data['action'],
      notes: data['notes'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      stockBefore: data['stockBefore'],
      stockAfter: data['stockAfter'],
    );
  }
}

class InventoryManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'inventory';
  static const String _logsCollection = 'inventory_logs';

  static Stream<List<InventoryItem>> getItemsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InventoryItem.fromFirestore(doc))
            .toList());
  }

  static Future<List<InventoryItem>> getItems() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => InventoryItem.fromFirestore(doc))
        .toList();
  }

  static Future<List<InventoryItem>> getLowStockItems() async {
    final items = await getItems();
    return items.where((item) => item.isLowStock).toList();
  }

  static Future<void> updateStock(String itemId, int newStock) async {
    await _firestore.collection(_collection).doc(itemId).update({
      'currentStock': newStock,
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
    });
  }

  static Future<void> addItem(InventoryItem item) async {
    await _firestore.collection(_collection).add(item.toFirestore());
  }

  static Future<void> removeItem(String itemId) async {
    await _firestore.collection(_collection).doc(itemId).delete();
  }

  static Future<InventoryItem?> getItem(String itemId) async {
    final doc = await _firestore.collection(_collection).doc(itemId).get();
    if (doc.exists) {
      return InventoryItem.fromFirestore(doc);
    }
    return null;
  }

  static Future<void> consumeStock(String itemId, int quantity) async {
    final item = await getItem(itemId);
    if (item != null && item.currentStock >= quantity) {
      await updateStock(itemId, item.currentStock - quantity);
    }
  }

  static Future<List<String>> getCategories() async {
    final items = await getItems();
    return items.map((item) => item.category).toSet().toList();
  }

  static Future<void> updateItem(String itemId, InventoryItem updatedItem) async {
    await _firestore.collection(_collection).doc(itemId).update(updatedItem.toFirestore());
  }

  static Future<void> initializeWithSampleData() async {
    final snapshot = await _firestore.collection(_collection).get();
    if (snapshot.docs.isEmpty) {
      for (final item in inventoryData) {
        await addItem(item);
      }
    }
  }

  // Inventory Log Methods
  static Future<void> addLog(InventoryLog log) async {
    await _firestore.collection(_logsCollection).add(log.toFirestore());
  }

  static Future<List<InventoryLog>> getLogs({String? itemId, int? limit}) async {
    Query query = _firestore.collection(_logsCollection).orderBy('timestamp', descending: true);

    if (itemId != null) {
      query = query.where('itemId', isEqualTo: itemId);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => InventoryLog.fromFirestore(doc)).toList();
  }

  static Future<void> withdrawStock(String itemId, int quantity, String staffName, String? notes) async {
    final item = await getItem(itemId);
    if (item != null && item.currentStock >= quantity) {
      final newStock = item.currentStock - quantity;

      // Create log entry
      final log = InventoryLog(
        itemId: itemId,
        itemName: item.name,
        quantity: quantity,
        staffName: staffName,
        action: 'withdraw',
        notes: notes,
        timestamp: DateTime.now(),
        stockBefore: item.currentStock,
        stockAfter: newStock,
      );

      // Update stock and add log
      await updateStock(itemId, newStock);
      await addLog(log);
    } else {
      throw Exception('Insufficient stock');
    }
  }

  static Future<void> addStockWithLog(String itemId, int quantity, String staffName, String? notes) async {
    final item = await getItem(itemId);
    if (item != null) {
      final newStock = item.currentStock + quantity;

      // Create log entry
      final log = InventoryLog(
        itemId: itemId,
        itemName: item.name,
        quantity: quantity,
        staffName: staffName,
        action: 'add',
        notes: notes,
        timestamp: DateTime.now(),
        stockBefore: item.currentStock,
        stockAfter: newStock,
      );

      // Update stock and add log
      await updateStock(itemId, newStock);
      await addLog(log);
    }
  }

  static Future<void> adjustStockWithLog(String itemId, int newStock, String staffName, String? notes) async {
    final item = await getItem(itemId);
    if (item != null) {
      final quantity = (newStock - item.currentStock).abs();

      // Create log entry
      final log = InventoryLog(
        itemId: itemId,
        itemName: item.name,
        quantity: quantity,
        staffName: staffName,
        action: 'adjust',
        notes: notes,
        timestamp: DateTime.now(),
        stockBefore: item.currentStock,
        stockAfter: newStock,
      );

      // Update stock and add log
      await updateStock(itemId, newStock);
      await addLog(log);
    }
  }
}
