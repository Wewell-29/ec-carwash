import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ec_carwash/data_models/unified_transaction_data.dart' as txn_model;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

/// Utility class for importing historical transaction data from CSV
class CSVImporter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Parse CSV content and return list of transactions
  static List<txn_model.Transaction> parseCSV(String csvContent) {
    try {
      // Handle different line endings (Windows \r\n, Unix \n, Mac \r)
      final normalizedContent = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final lines = normalizedContent.split('\n');
      debugPrint('Total lines in CSV: ${lines.length}');

      if (lines.isEmpty) {
        throw Exception('CSV file is empty');
      }

      // Skip header row
      final dataLines = lines.skip(1).where((line) => line.trim().isNotEmpty).toList();
      debugPrint('Data lines to parse: ${dataLines.length}');

      final transactions = <txn_model.Transaction>[];
      int lineNumber = 2; // Start at 2 (after header)

      for (final line in dataLines) {
        try {
          final transaction = _parseCSVLine(line, lineNumber);
          transactions.add(transaction);
        } catch (e) {
          debugPrint('Error parsing line $lineNumber: $e');
          debugPrint('Line content: $line');
          throw Exception('Error parsing line $lineNumber: $e\n$line');
        }
        lineNumber++;
      }

      debugPrint('Successfully parsed ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      debugPrint('CSV parsing failed: $e');
      rethrow;
    }
  }

  /// Parse a single CSV line into a Transaction object
  static txn_model.Transaction _parseCSVLine(String line, int lineNumber) {
    final parts = _parseCSVRow(line);

    if (parts.length < 7) {
      throw Exception('Invalid CSV format. Expected 8 columns, got ${parts.length}');
    }

    // Extract fields with fallbacks for empty values
    final dateStr = parts[0].trim();
    final timeStr = parts[1].trim();
    final team = parts[2].trim().isEmpty ? 'Team A' : parts[2].trim();
    final carType = parts[3].trim().isEmpty ? 'SUV' : parts[3].trim();
    final plateNumber = parts[4].trim().isEmpty ? 'N/A' : parts[4].trim();
    final serviceStr = parts[5].trim();
    final priceStr = parts[6].trim();
    // parts[7] is Status - currently unused

    // Parse date and time
    final transactionDateTime = _parseDateTime(dateStr, timeStr);

    // Parse price
    final price = double.tryParse(priceStr) ?? 0.0;

    if (price == 0.0) {
      debugPrint('Warning: Line $lineNumber has zero price');
    }

    // Parse services (can be comma-separated like "EC2, PROMO1")
    final serviceCodes = serviceStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (serviceCodes.isEmpty) {
      throw Exception('No service code found');
    }

    // Create transaction services
    final services = serviceCodes.map((code) {
      return txn_model.TransactionService(
        serviceCode: code,
        serviceName: code, // Will be resolved from Firestore later
        vehicleType: _normalizeVehicleType(carType),
        price: serviceCodes.length > 1 ? price / serviceCodes.length : price,
        quantity: 1,
      );
    }).toList();

    return txn_model.Transaction(
      customerName: 'Historical Import',
      vehiclePlateNumber: plateNumber.isEmpty ? 'N/A' : plateNumber,
      contactNumber: 'N/A',
      vehicleType: _normalizeVehicleType(carType),
      services: services,
      subtotal: price,
      discount: 0.0,
      total: price,
      cash: price,
      change: 0.0,
      paymentMethod: 'cash',
      paymentStatus: 'paid',
      assignedTeam: team,
      teamCommission: price * 0.35, // 35% commission
      transactionDate: DateTime(
        transactionDateTime.year,
        transactionDateTime.month,
        transactionDateTime.day,
      ),
      transactionAt: transactionDateTime,
      createdAt: transactionDateTime,
      source: 'import',
      status: 'completed',
      notes: 'Imported from CSV on ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
  }

  /// Parse CSV row handling quoted fields
  static List<String> _parseCSVRow(String row) {
    final fields = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < row.length; i++) {
      final char = row[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    fields.add(current.toString());
    return fields;
  }

  /// Parse date and time from CSV format
  static DateTime _parseDateTime(String dateStr, String timeStr) {
    try {
      // Parse date (e.g., "1/2/2025" or "2/2/2025")
      final dateParts = dateStr.split('/');
      if (dateParts.length != 3) {
        throw Exception('Invalid date format: $dateStr');
      }

      final month = int.parse(dateParts[0]);
      final day = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      // If time is empty or invalid, default to 12:00 (noon)
      int hour = 12;
      int minute = 0;

      if (timeStr.trim().isNotEmpty) {
        // Parse time (e.g., "7:45" or "1:20" or "10:09")
        final timeParts = timeStr.split(':');
        if (timeParts.length == 2) {
          hour = int.tryParse(timeParts[0]) ?? 12;
          minute = int.tryParse(timeParts[1]) ?? 0;
        } else {
          debugPrint('Warning: Invalid time format "$timeStr", using 12:00');
        }
      } else {
        debugPrint('Warning: Empty time field on line, using 12:00');
      }

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      throw Exception('Failed to parse date/time: $dateStr $timeStr - $e');
    }
  }

  /// Normalize vehicle type to match system standards
  static String _normalizeVehicleType(String carType) {
    final normalized = carType.trim().toLowerCase();

    if (normalized.contains('car') || normalized == 'sedan') {
      return 'Sedan';
    } else if (normalized.contains('suv')) {
      return 'SUV';
    } else if (normalized.contains('van')) {
      return 'Van';
    } else if (normalized.contains('pick') || normalized.contains('pickup')) {
      return 'Pick-Up';
    } else if (normalized.contains('motor')) {
      return 'Motorcycle';
    } else if (normalized.contains('tricycle')) {
      return 'Tricycle';
    }

    // Default: return original with proper casing
    return carType.trim();
  }

  /// Resolve service names from Firestore based on service codes
  static Future<void> resolveServiceNames(List<txn_model.Transaction> transactions) async {
    try {
      final servicesSnapshot = await _firestore.collection('Services').get();
      final serviceMap = <String, String>{};

      for (final doc in servicesSnapshot.docs) {
        final data = doc.data();
        final code = data['code'] as String?;
        final name = data['name'] as String?;
        if (code != null && name != null) {
          serviceMap[code] = name;
        }
      }

      // Update service names in transactions
      for (final transaction in transactions) {
        for (var i = 0; i < transaction.services.length; i++) {
          final service = transaction.services[i];
          final serviceName = serviceMap[service.serviceCode];
          if (serviceName != null) {
            transaction.services[i] = txn_model.TransactionService(
              serviceCode: service.serviceCode,
              serviceName: serviceName,
              vehicleType: service.vehicleType,
              price: service.price,
              quantity: service.quantity,
            );
          }
        }
      }
    } catch (e) {
      // If service resolution fails, continue with service codes as names
      debugPrint('Warning: Could not resolve service names: $e');
    }
  }

  /// Import transactions to Firestore
  static Future<int> importToFirestore(List<txn_model.Transaction> transactions) async {
    int importedCount = 0;
    WriteBatch batch = _firestore.batch();
    int batchCount = 0;

    debugPrint('Starting import of ${transactions.length} transactions...');

    for (final transaction in transactions) {
      final docRef = _firestore.collection('Transactions').doc();
      batch.set(docRef, transaction.toJson());
      batchCount++;
      importedCount++;

      // Firestore batch limit is 500 operations
      if (batchCount >= 500) {
        debugPrint('Committing batch of $batchCount transactions...');
        await batch.commit();
        batch = _firestore.batch(); // Create new batch
        batchCount = 0;
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      debugPrint('Committing final batch of $batchCount transactions...');
      await batch.commit();
    }

    debugPrint('Import complete: $importedCount transactions imported');
    return importedCount;
  }

  /// Validate CSV format
  static bool validateCSVFormat(String csvContent) {
    try {
      // Handle different line endings
      final normalizedContent = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final lines = normalizedContent.split('\n');
      if (lines.isEmpty) {
        debugPrint('CSV validation failed: No lines found');
        return false;
      }

      // Check header
      final header = lines[0].toLowerCase().trim();
      debugPrint('CSV Header: $header');

      final hasDate = header.contains('date');
      final hasTime = header.contains('time');
      final hasTeam = header.contains('team');
      final hasService = header.contains('service');
      final hasPrice = header.contains('price');

      debugPrint('Validation: date=$hasDate, time=$hasTime, team=$hasTeam, service=$hasService, price=$hasPrice');

      return hasDate && hasTime && hasTeam && hasService && hasPrice;
    } catch (e) {
      debugPrint('CSV validation error: $e');
      return false;
    }
  }
}
