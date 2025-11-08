import 'package:ec_carwash/data_models/customer_data_unified.dart';
import 'package:ec_carwash/data_models/booking_data_unified.dart';
import 'package:ec_carwash/data_models/unified_transaction_data.dart';

/// Centralized manager for maintaining relationships between entities
/// This ensures data integrity across Customers, Bookings, and Transactions
class RelationshipManager {
  /// Create a complete booking flow with proper relationships
  /// Returns: (bookingId, customerId)
  static Future<(String, String)> createBookingWithCustomer({
    required String userName,
    required String userEmail,
    required String userId,
    required String plateNumber,
    required String contactNumber,
    String? vehicleType,
    required DateTime scheduledDateTime,
    required List<BookingService> services,
    String source = 'customer-app',
    String? assignedTeam,
    String? notes,
  }) async {
    // Step 1: Create or get customer
    final customerId = await CustomerManager.createOrUpdateCustomer(
      name: userName,
      plateNumber: plateNumber,
      email: userEmail,
      contactNumber: contactNumber,
      vehicleType: vehicleType,
      source: source,
    );

    // Step 2: Create booking with customer reference
    final booking = Booking(
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      customerId: customerId,
      plateNumber: plateNumber,
      contactNumber: contactNumber,
      vehicleType: vehicleType,
      scheduledDateTime: scheduledDateTime,
      services: services,
      createdAt: DateTime.now(),
      status: 'pending',
      paymentStatus: 'unpaid',
      source: source,
      assignedTeam: assignedTeam,
      notes: notes,
    );

    final bookingId = await BookingManager.createBooking(booking);

    // Step 3: Link booking to customer
    await CustomerManager.addBookingToCustomer(customerId, bookingId);

    return (bookingId, customerId);
  }

  /// Complete a booking and create transaction with full relationships
  /// Returns: transactionId
  static Future<String> completeBookingWithTransaction({
    required Booking booking,
    required double cash,
    required double change,
    String paymentMethod = 'cash',
    double teamCommission = 0.0,
    String? notes,
  }) async {
    if (booking.id == null) {
      throw Exception('Booking must have an ID to complete');
    }

    // Check if transaction already exists for this booking
    final existingTransaction = await TransactionManager.getTransactionByBookingId(booking.id!);
    if (existingTransaction != null) {
      // Transaction already exists, return existing ID
      return existingTransaction.id!;
    }

    // Step 1: Create transaction from booking
    final transactionId = await TransactionManager.createFromBooking(
      bookingId: booking.id!,
      customerName: booking.userName,
      customerId: booking.customerId,
      vehiclePlateNumber: booking.plateNumber,
      contactNumber: booking.contactNumber,
      vehicleType: booking.vehicleType,
      services: booking.services
          .map((bs) => TransactionService(
                serviceCode: bs.serviceCode,
                serviceName: bs.serviceName,
                vehicleType: bs.vehicleType,
                price: bs.price,
                quantity: bs.quantity,
              ))
          .toList(),
      total: booking.totalAmount,
      scheduledDateTime: booking.scheduledDateTime,
      assignedTeam: booking.assignedTeam,
      teamCommission: teamCommission,
    );

    // Step 2: Update booking with transaction reference
    await BookingManager.completeBooking(
      bookingId: booking.id!,
      transactionId: transactionId,
      teamCommission: teamCommission,
    );

    // Step 3: Update customer metrics if customerId exists
    if (booking.customerId != null) {
      await CustomerManager.addTransactionToCustomer(
        customerId: booking.customerId!,
        transactionId: transactionId,
        amount: booking.totalAmount,
      );
    }

    return transactionId;
  }

  /// Create a walk-in transaction at POS with full relationships
  /// Returns: (transactionId, bookingId, customerId)
  static Future<(String, String, String)> createWalkInTransaction({
    required String customerName,
    required String plateNumber,
    required String contactNumber,
    String? email,
    String? vehicleType,
    required List<TransactionService> services,
    required double total,
    required double cash,
    required double change,
    String paymentMethod = 'cash',
    String? assignedTeam,
    double teamCommission = 0.0,
    String? notes,
  }) async {
    final now = DateTime.now();

    // Step 1: Create or get customer
    final customerId = await CustomerManager.createOrUpdateCustomer(
      name: customerName,
      plateNumber: plateNumber,
      email: email ?? 'walkin@eccarwash.com',
      contactNumber: contactNumber,
      vehicleType: vehicleType,
      source: 'pos',
    );

    // Step 2: Create transaction
    final transaction = Transaction(
      customerName: customerName,
      customerId: customerId,
      vehiclePlateNumber: plateNumber,
      contactNumber: contactNumber,
      vehicleType: vehicleType,
      services: services,
      subtotal: total,
      discount: 0.0,
      total: total,
      cash: cash,
      change: change,
      paymentMethod: paymentMethod,
      paymentStatus: 'paid',
      assignedTeam: assignedTeam,
      teamCommission: teamCommission,
      transactionDate: DateTime(now.year, now.month, now.day),
      transactionAt: now,
      createdAt: now,
      source: 'pos',
      status: 'completed',
      notes: notes,
    );

    final transactionId = await TransactionManager.createTransaction(transaction);

    // Step 3: Create a booking record for tracking (already completed)
    final booking = Booking(
      userId: 'walk-in',
      userEmail: email ?? 'walkin@eccarwash.com',
      userName: customerName,
      customerId: customerId,
      plateNumber: plateNumber,
      contactNumber: contactNumber,
      vehicleType: vehicleType,
      scheduledDateTime: now,
      services: services
          .map((ts) => BookingService(
                serviceCode: ts.serviceCode,
                serviceName: ts.serviceName,
                vehicleType: ts.vehicleType,
                price: ts.price,
                quantity: ts.quantity,
              ))
          .toList(),
      createdAt: now,
      status: 'completed',
      paymentStatus: 'paid',
      source: 'pos',
      transactionId: transactionId,
      assignedTeam: assignedTeam,
      teamCommission: teamCommission,
      completedAt: now,
      notes: notes,
    );

    final bookingId = await BookingManager.createBooking(booking);

    // Step 4: Update transaction with booking reference
    await TransactionManager.createTransaction(
      transaction.copyWith(bookingId: bookingId),
    );

    // Step 5: Update customer with both references
    await CustomerManager.addBookingToCustomer(customerId, bookingId);
    await CustomerManager.addTransactionToCustomer(
      customerId: customerId,
      transactionId: transactionId,
      amount: total,
    );

    return (transactionId, bookingId, customerId);
  }

  /// Link existing customer to their legacy bookings by plate number
  static Future<void> linkCustomerToLegacyBookings(String customerId) async {
    try {
      final customer = await CustomerManager.getCustomerById(customerId);
      if (customer == null) {
        throw Exception('Customer not found');
      }

      // Link all bookings with this plate number
      await BookingManager.linkCustomerToBookings(
        customerId: customerId,
        plateNumber: customer.plateNumber,
      );
    } catch (e) {
      throw Exception('Failed to link customer to legacy bookings: $e');
    }
  }

  /// Get complete customer history
  static Future<CustomerHistory> getCustomerHistory(String customerId) async {
    final customer = await CustomerManager.getCustomerById(customerId);
    if (customer == null) {
      throw Exception('Customer not found');
    }

    final bookings = await BookingManager.getBookingsByCustomer(customerId);
    final transactions = await TransactionManager.getTransactionsByCustomer(customerId);

    return CustomerHistory(
      customer: customer,
      bookings: bookings,
      transactions: transactions,
    );
  }

  /// Cancel a booking and update all relationships
  static Future<void> cancelBooking(String bookingId, String reason) async {
    // Update booking status
    await BookingManager.updateBookingStatus(bookingId, 'cancelled');

    // Note: We don't remove from customer.bookingIds because we want to keep history
    // The status field indicates it's cancelled
  }

  /// Refund a transaction and update all relationships
  static Future<void> refundTransaction(String transactionId, String reason) async {
    // Update transaction status
    await TransactionManager.updateTransactionStatus(transactionId, 'refunded');

    // Get transaction to update customer metrics
    final transaction = await TransactionManager.getTransactions();
    final refundedTx = transaction.firstWhere((t) => t.id == transactionId);

    if (refundedTx.customerId != null) {
      // Subtract from customer's total spent
      final customer = await CustomerManager.getCustomerById(refundedTx.customerId!);
      if (customer != null) {
        final updatedCustomer = customer.copyWith(
          totalSpent: customer.totalSpent - refundedTx.total,
        );
        await CustomerManager.saveCustomer(updatedCustomer);
      }
    }
  }

  /// Validate data integrity for a customer
  static Future<DataIntegrityReport> validateCustomerIntegrity(String customerId) async {
    final customer = await CustomerManager.getCustomerById(customerId);
    if (customer == null) {
      throw Exception('Customer not found');
    }

    final issues = <String>[];
    final warnings = <String>[];

    // Check bookings
    final bookings = await BookingManager.getBookingsByCustomer(customerId);
    if (bookings.length != customer.bookingIds.length) {
      warnings.add(
        'Booking count mismatch: Found ${bookings.length} bookings but customer has ${customer.bookingIds.length} booking IDs',
      );
    }

    // Check for bookings missing customerId
    for (final booking in bookings) {
      if (booking.customerId != customerId) {
        issues.add('Booking ${booking.id} has incorrect customerId');
      }

      // Check if completed bookings have transactions
      if (booking.status == 'completed' && booking.transactionId == null) {
        warnings.add('Completed booking ${booking.id} is missing transactionId');
      }
    }

    // Check transactions
    final transactions = await TransactionManager.getTransactionsByCustomer(customerId);
    if (transactions.length != customer.transactionIds.length) {
      warnings.add(
        'Transaction count mismatch: Found ${transactions.length} transactions but customer has ${customer.transactionIds.length} transaction IDs',
      );
    }

    // Verify total spent
    final actualTotalSpent = transactions
        .where((t) => t.status == 'completed' && t.paymentStatus == 'paid')
        .fold<double>(0.0, (sum, t) => sum + t.total);

    if ((actualTotalSpent - customer.totalSpent).abs() > 0.01) {
      issues.add(
        'Total spent mismatch: Customer shows ${customer.totalSpent} but actual is $actualTotalSpent',
      );
    }

    return DataIntegrityReport(
      customerId: customerId,
      isValid: issues.isEmpty,
      issues: issues,
      warnings: warnings,
      bookingsCount: bookings.length,
      transactionsCount: transactions.length,
      totalSpentCalculated: actualTotalSpent,
      totalSpentStored: customer.totalSpent,
    );
  }
}

/// Customer history data container
class CustomerHistory {
  final Customer customer;
  final List<Booking> bookings;
  final List<Transaction> transactions;

  CustomerHistory({
    required this.customer,
    required this.bookings,
    required this.transactions,
  });

  double get totalSpent => transactions
      .where((t) => t.status == 'completed' && t.paymentStatus == 'paid')
      .fold<double>(0.0, (sum, t) => sum + t.total);

  int get completedVisits => bookings.where((b) => b.status == 'completed').length;

  List<Transaction> get recentTransactions {
    final sorted = List<Transaction>.from(transactions);
    sorted.sort((a, b) => b.transactionAt.compareTo(a.transactionAt));
    return sorted.take(10).toList();
  }

  List<Booking> get upcomingBookings {
    final now = DateTime.now();
    return bookings
        .where((b) =>
            b.scheduledDateTime.isAfter(now) &&
            (b.status == 'pending' || b.status == 'approved'))
        .toList()
      ..sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
  }
}

/// Data integrity report for validation
class DataIntegrityReport {
  final String customerId;
  final bool isValid;
  final List<String> issues;
  final List<String> warnings;
  final int bookingsCount;
  final int transactionsCount;
  final double totalSpentCalculated;
  final double totalSpentStored;

  DataIntegrityReport({
    required this.customerId,
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.bookingsCount,
    required this.transactionsCount,
    required this.totalSpentCalculated,
    required this.totalSpentStored,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Data Integrity Report for Customer $customerId');
    buffer.writeln('Status: ${isValid ? "VALID" : "INVALID"}');
    buffer.writeln('Bookings: $bookingsCount');
    buffer.writeln('Transactions: $transactionsCount');
    buffer.writeln('Total Spent (Stored): ₱${totalSpentStored.toStringAsFixed(2)}');
    buffer.writeln('Total Spent (Calculated): ₱${totalSpentCalculated.toStringAsFixed(2)}');

    if (issues.isNotEmpty) {
      buffer.writeln('\nIssues:');
      for (final issue in issues) {
        buffer.writeln('  - $issue');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('\nWarnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }

    return buffer.toString();
  }
}
