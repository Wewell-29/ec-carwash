# EC Carwash - Unified Data Model Documentation

## Overview

This document describes the unified data model system that establishes proper relationships between all collections in the EC Carwash Firebase database.

## Core Principles

1. **Single Source of Truth** - No duplicate data structures
2. **Relational Integrity** - Proper foreign keys and bidirectional references
3. **Standardized Field Names** - Consistent naming across collections
4. **Backward Compatibility** - Legacy field support during migration

---

## Collection Structure

### 1. Customers Collection

**Purpose**: Central customer registry with relationship tracking

**File**: `lib/data_models/customer_data_unified.dart`

**Fields**:
```dart
{
  id: String (document ID)
  name: String
  plateNumber: String (PRIMARY IDENTIFIER - uppercase)
  email: String
  contactNumber: String (STANDARDIZED - was phoneNumber)
  vehicleType: String? (Cars, SUV, Van, etc.)

  // Relationships
  bookingIds: List<String> (FKs to Bookings)
  transactionIds: List<String> (FKs to Transactions)

  // Business Metrics
  totalVisits: int
  totalSpent: double

  // Timestamps
  createdAt: Timestamp
  lastVisit: Timestamp

  // Metadata
  source: String (customer-app, pos, walk-in)
  notes: String?
}
```

**Indexes Needed**:
- `plateNumber` (unique)
- `email`
- `lastVisit` (descending)
- `totalSpent` (descending)

---

### 2. Bookings Collection

**Purpose**: Service appointments from all sources

**File**: `lib/data_models/booking_data_unified.dart`

**Fields**:
```dart
{
  id: String (document ID)

  // Customer Information
  userId: String (Firebase Auth UID)
  userEmail: String
  userName: String
  customerId: String? (FK to Customers - ADDED)

  // Vehicle Information
  plateNumber: String (uppercase)
  contactNumber: String
  vehicleType: String?

  // Scheduling - SINGLE SOURCE OF TRUTH
  scheduledDateTime: Timestamp (THE ONLY datetime field to use!)

  // Services
  services: List<BookingService> {
    serviceCode: String
    serviceName: String
    vehicleType: String
    price: double
    quantity: int
  }

  // Status
  status: String (pending, approved, in-progress, completed, cancelled)
  paymentStatus: String (unpaid, paid, refunded)

  // Relationships
  source: String (customer-app, pos, walk-in, admin)
  transactionId: String? (FK to Transactions - when completed)

  // Team
  assignedTeam: String? (Team A, Team B, etc.)
  teamCommission: double

  // Timestamps
  createdAt: Timestamp
  updatedAt: Timestamp?
  completedAt: Timestamp?

  // Metadata
  notes: String?
}
```

**Key Changes**:
- ✅ `scheduledDateTime` is THE ONLY datetime field (removed `selectedDateTime`, `date`, `time`)
- ✅ Added `customerId` foreign key
- ✅ Added `transactionId` for completed bookings
- ✅ Legacy field support in `fromJson()` for migration

**Indexes Needed**:
- `scheduledDateTime`
- `customerId`
- `userEmail`
- `status`
- `transactionId`

---

### 3. Transactions Collection

**Purpose**: All payment transactions (POS, completed bookings)

**File**: `lib/data_models/unified_transaction_data.dart`

**Fields**:
```dart
{
  id: String (document ID)

  // Customer Information
  customerName: String
  customerId: String? (FK to Customers)
  vehiclePlateNumber: String (uppercase)
  contactNumber: String?
  vehicleType: String?

  // Services
  services: List<TransactionService> {
    serviceCode: String
    serviceName: String
    vehicleType: String
    price: double
    quantity: int
  }

  // Financial
  subtotal: double
  discount: double
  total: double
  cash: double
  change: double
  paymentMethod: String (cash, gcash, card)
  paymentStatus: String (paid, pending, refunded)

  // Team
  assignedTeam: String?
  teamCommission: double

  // Timestamps
  transactionDate: Timestamp (date only - for daily reports)
  transactionAt: Timestamp (exact time - for receipts)
  createdAt: Timestamp

  // Relationships
  source: String (pos, booking, walk-in)
  bookingId: String? (FK to Bookings - if from booking)

  // Status
  status: String (completed, cancelled, refunded)
  notes: String?
}
```

**Key Changes**:
- ✅ Added `customerId` foreign key
- ✅ Added `bookingId` for transactions from bookings
- ✅ Unified `TransactionService` structure (same as `BookingService`)

**Indexes Needed**:
- `transactionDate`, `transactionAt` (composite for reports)
- `customerId`
- `bookingId`
- `source`
- `status`

---

### 4. Services Collection

**Purpose**: Available car wash services (SINGLE SOURCE OF TRUTH)

**File**: `lib/data_models/services_data.dart` (already good)

**Fields**:
```dart
{
  id: String (document ID)
  code: String (EC1, EC2, PROMO1, etc.)
  name: String
  category: String (Basic Wash, Premium Wash, etc.)
  description: String
  prices: Map<String, double> {
    'Cars': 170.0,
    'SUV': 180.0,
    // etc.
  }
  isActive: bool
  createdAt: Timestamp
  updatedAt: Timestamp
}
```

**Migration Required**:
- ❌ Remove `lib/data_models/products_data.dart` (static duplicate)
- ✅ Update customer booking screen to read from Firestore

---

## Relational Diagram

```
┌─────────────┐
│  Customers  │
│   (Central) │
└──────┬──────┘
       │
       │ 1:N
       ├──────────────┐
       │              │
       ▼              ▼
┌──────────┐   ┌──────────────┐
│ Bookings │   │ Transactions │
└────┬─────┘   └──────┬───────┘
     │                │
     │ N:1            │ N:1
     │                │
     └────────┬───────┘
              │
              │ (mutual references)
              │
              ▼
     booking.transactionId ←→ transaction.bookingId
```

### Relationship Flow:

1. **Customer → Bookings**: One customer has many bookings
   - `customer.bookingIds[]` contains all booking IDs
   - `booking.customerId` references the customer

2. **Customer → Transactions**: One customer has many transactions
   - `customer.transactionIds[]` contains all transaction IDs
   - `transaction.customerId` references the customer

3. **Booking ↔ Transaction**: Bidirectional when booking is completed
   - `booking.transactionId` points to the payment transaction
   - `transaction.bookingId` points back to the original booking

---

## Data Flow Scenarios

### Scenario 1: Customer Books via App

```
1. Customer opens app and selects services
2. System checks if customer exists by plate number
   - If new: Create Customer record → get customerId
   - If existing: Get customerId
3. Create Booking with:
   - customerId (FK)
   - scheduledDateTime
   - services[]
   - status: "pending"
   - source: "customer-app"
4. Update Customer:
   - Add booking ID to bookingIds[]
   - Update lastVisit
```

### Scenario 2: Admin Approves Booking

```
1. Admin views pending bookings
2. Clicks "Approve" on booking
3. System updates:
   - booking.status = "approved"
   - booking.updatedAt = now
```

### Scenario 3: Service Completed (from Booking)

```
1. Staff marks booking as complete in Scheduling screen
2. System creates Transaction:
   - transactionId = new document
   - bookingId = booking.id (FK)
   - customerId = booking.customerId (FK)
   - services = booking.services
   - source = "booking"
3. System updates Booking:
   - booking.status = "completed"
   - booking.paymentStatus = "paid"
   - booking.transactionId = transactionId (FK)
   - booking.completedAt = now
4. System updates Customer:
   - Add transactionId to transactionIds[]
   - Increment totalVisits
   - Add to totalSpent
   - Update lastVisit
```

### Scenario 4: Walk-in at POS

```
1. Staff searches customer by plate number
   - If found: Load customer → customerId
   - If new: Create customer → get customerId
2. Staff adds services to cart
3. Staff processes payment
4. System creates Transaction:
   - transactionId = new document
   - customerId = customer.id (FK)
   - services[]
   - source = "pos"
   - bookingId = null (no prior booking)
5. System creates Booking (for tracking):
   - bookingId = new document
   - customerId = customer.id (FK)
   - transactionId = transaction.id (FK)
   - scheduledDateTime = now
   - status = "completed"
   - paymentStatus = "paid"
   - source = "pos"
6. System updates Customer:
   - Add bookingId to bookingIds[]
   - Add transactionId to transactionIds[]
   - Increment totalVisits
   - Add to totalSpent
   - Update lastVisit
```

---

## Migration Plan

### Phase 1: Create Unified Models ✅ DONE
- Created `customer_data_unified.dart`
- Created `booking_data_unified.dart`
- Created `unified_transaction_data.dart`

### Phase 2: Update Existing Screens

#### 2.1 Update Customer Booking Screen
**File**: `lib/screens/Customer/book_service_screen.dart`

Changes needed:
```dart
// BEFORE: Using products_data.dart
import 'package:ec_carwash/data_models/products_data.dart';

// AFTER: Use Firestore services
import 'package:ec_carwash/data_models/services_data.dart';
import 'package:ec_carwash/data_models/booking_data_unified.dart';
import 'package:ec_carwash/data_models/customer_data_unified.dart';

// Load services from Firestore instead of static map
List<Service> _services = [];
await ServicesManager.getServices();

// When creating booking, get/create customerId first
final customerId = await CustomerManager.createOrUpdateCustomer(...);

// Use unified Booking model
final booking = Booking(
  customerId: customerId,
  scheduledDateTime: selectedDateTime, // SINGLE field
  ...
);
await BookingManager.createBooking(booking);
```

#### 2.2 Update POS Screen
**File**: `lib/screens/Admin/pos_screen.dart`

Changes needed:
```dart
import 'package:ec_carwash/data_models/unified_transaction_data.dart';
import 'package:ec_carwash/data_models/booking_data_unified.dart';
import 'package:ec_carwash/data_models/customer_data_unified.dart';

// When customer is selected/created
final customerId = await CustomerManager.createOrUpdateCustomer(...);

// When processing payment
final transactionId = await TransactionManager.createTransaction(
  Transaction(
    customerId: customerId,
    ...
  )
);

// Create booking record
final bookingId = await BookingManager.createBooking(
  Booking(
    customerId: customerId,
    transactionId: transactionId,
    scheduledDateTime: DateTime.now(),
    status: 'completed',
    paymentStatus: 'paid',
    source: 'pos',
    ...
  )
);

// Update customer relationships
await CustomerManager.addTransactionToCustomer(
  customerId: customerId,
  transactionId: transactionId,
  amount: total,
);
await CustomerManager.addBookingToCustomer(customerId, bookingId);
```

#### 2.3 Update Scheduling Screen
**File**: `lib/screens/Admin/scheduling_screen.dart`

Changes needed:
```dart
import 'package:ec_carwash/data_models/unified_transaction_data.dart';
import 'package:ec_carwash/data_models/booking_data_unified.dart';

// When marking booking as complete
final transactionId = await TransactionManager.createFromBooking(
  bookingId: booking.id!,
  customerName: booking.userName,
  customerId: booking.customerId,
  ...
);

// Update booking with transaction reference
await BookingManager.completeBooking(
  bookingId: booking.id!,
  transactionId: transactionId,
  teamCommission: commission,
);

// Update customer metrics if customerId exists
if (booking.customerId != null) {
  await CustomerManager.addTransactionToCustomer(
    customerId: booking.customerId!,
    transactionId: transactionId,
    amount: booking.totalAmount,
  );
}
```

#### 2.4 Update Admin Dashboard
**File**: `lib/screens/Admin/admin_staff_home.dart`

Changes needed:
```dart
// Use only scheduledDateTime field
final bookings = await BookingManager.getTodayBookings();
for (final booking in bookings) {
  // booking.scheduledDateTime is always available
  final time = DateFormat('hh:mm a').format(booking.scheduledDateTime);
}
```

#### 2.5 Update Customer Home
**File**: `lib/screens/Customer/customer_home.dart`

Changes needed:
```dart
import 'package:ec_carwash/data_models/booking_data_unified.dart';

// Use only scheduledDateTime
final bookings = await BookingManager.getBookingsByEmail(user.email);
```

### Phase 3: Database Migration Script

Create a one-time migration to update existing data:

```dart
// lib/scripts/migrate_data.dart

Future<void> migrateExistingData() async {
  // 1. Migrate Bookings: Add customerId and standardize datetime
  final bookingsSnapshot = await FirebaseFirestore.instance
      .collection('Bookings')
      .get();

  for (final doc in bookingsSnapshot.docs) {
    final data = doc.data();
    final plateNumber = data['plateNumber'];

    // Find or create customer
    final customer = await CustomerManager.getCustomerByPlateNumber(plateNumber);
    String? customerId = customer?.id;

    if (customerId == null) {
      // Create customer from booking data
      customerId = await CustomerManager.createOrUpdateCustomer(
        name: data['userName'] ?? 'Unknown',
        plateNumber: plateNumber,
        email: data['userEmail'] ?? '',
        contactNumber: data['contactNumber'] ?? '',
        vehicleType: data['vehicleType'],
        source: 'migration',
      );
    }

    // Standardize datetime field
    DateTime scheduledDateTime;
    if (data['selectedDateTime'] != null) {
      scheduledDateTime = (data['selectedDateTime'] as Timestamp).toDate();
    } else if (data['scheduledDate'] != null) {
      scheduledDateTime = (data['scheduledDate'] as Timestamp).toDate();
    } else {
      scheduledDateTime = DateTime.now();
    }

    // Update booking
    await doc.reference.update({
      'customerId': customerId,
      'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Add booking to customer
    await CustomerManager.addBookingToCustomer(customerId, doc.id);
  }

  // 2. Migrate Transactions: Add customerId and bookingId
  final transactionsSnapshot = await FirebaseFirestore.instance
      .collection('Transactions')
      .get();

  for (final doc in transactionsSnapshot.docs) {
    final data = doc.data();
    final plateNumber = data['vehiclePlateNumber'];

    // Find customer
    final customer = await CustomerManager.getCustomerByPlateNumber(plateNumber);
    if (customer != null) {
      await doc.reference.update({
        'customerId': customer.id,
      });

      // Add transaction to customer
      await CustomerManager.addTransactionToCustomer(
        customerId: customer.id!,
        transactionId: doc.id,
        amount: (data['total'] ?? 0).toDouble(),
      );
    }
  }

  // 3. Migrate Customers: Standardize contactNumber field
  final customersSnapshot = await FirebaseFirestore.instance
      .collection('Customers')
      .get();

  for (final doc in customersSnapshot.docs) {
    final data = doc.data();
    if (data['contactNumber'] == null && data['phoneNumber'] != null) {
      await doc.reference.update({
        'contactNumber': data['phoneNumber'],
      });
    }
  }
}
```

### Phase 4: Remove Deprecated Code

After migration is complete and tested:

1. Delete `lib/data_models/products_data.dart`
2. Delete `lib/data_models/booking_data.dart` (replaced by `booking_data_unified.dart`)
3. Delete `lib/data_models/customer_data.dart` (replaced by `customer_data_unified.dart`)

---

## Benefits of Unified System

### 1. Data Integrity
- ✅ No orphaned records
- ✅ Bidirectional relationships ensure consistency
- ✅ Foreign keys prevent invalid references

### 2. Performance
- ✅ Efficient queries with proper indexes
- ✅ Reduced duplicate data
- ✅ Better caching opportunities

### 3. Analytics
- ✅ Easy customer lifetime value calculation (`customer.totalSpent`)
- ✅ Accurate visit tracking (`customer.totalVisits`)
- ✅ Complete transaction history per customer

### 4. Maintainability
- ✅ Single source of truth for services
- ✅ Standardized field names
- ✅ Clear relationships between entities
- ✅ Easier to add features

### 5. Business Intelligence
- ✅ Track customer behavior across bookings and transactions
- ✅ Identify top customers by spending
- ✅ Analyze service popularity
- ✅ Team performance tracking with proper commission links

---

## Required Firestore Indexes

Create these composite indexes in Firebase Console:

1. **Bookings Collection**:
   - `scheduledDateTime` (ascending) + `status` (ascending)
   - `customerId` (ascending) + `scheduledDateTime` (descending)
   - `userEmail` (ascending) + `scheduledDateTime` (descending)

2. **Transactions Collection**:
   - `transactionDate` (ascending) + `transactionAt` (descending)
   - `customerId` (ascending) + `transactionAt` (descending)
   - `status` (ascending) + `transactionDate` (descending)

3. **Customers Collection**:
   - `lastVisit` (descending)
   - `totalSpent` (descending)
   - `name` (ascending)

4. **Services Collection**:
   - `isActive` (ascending) + `category` (ascending)
   - `code` (ascending) + `isActive` (ascending)

---

## Testing Checklist

Before deploying to production:

- [ ] Customer booking flow creates customerId
- [ ] POS transaction creates both Transaction and Booking
- [ ] Booking completion creates Transaction with proper references
- [ ] Customer metrics update correctly (totalVisits, totalSpent)
- [ ] Dashboard shows correct data from scheduledDateTime
- [ ] All screens handle null customerId gracefully (for legacy data)
- [ ] Migration script tested on copy of production data
- [ ] All Firestore indexes created
- [ ] Backup of database taken before migration

---

## Support and Maintenance

### Common Queries

1. **Get customer's full history**:
```dart
final customer = await CustomerManager.getCustomerById(customerId);
final bookings = await BookingManager.getBookingsByCustomer(customerId);
final transactions = await TransactionManager.getTransactionsByCustomer(customerId);
```

2. **Find transaction from booking**:
```dart
final transaction = await TransactionManager.getTransactionByBookingId(bookingId);
```

3. **Get all completed bookings with payments**:
```dart
final completedBookings = await BookingManager.getBookingsByStatus('completed');
final paidBookings = completedBookings.where((b) => b.transactionId != null);
```

---

## Questions?

For issues or questions about the unified data model, refer to:
- Individual model files for field-level documentation
- This document for relationship and flow understanding
- Migration script for data transformation examples
