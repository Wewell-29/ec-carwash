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

class InventoryManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'inventory';

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
}
