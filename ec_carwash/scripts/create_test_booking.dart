import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script to create a test mobile booking
/// Run with: dart run scripts/create_test_booking.dart
void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  // Create test booking data
  final testBooking = {
    'userId': 'test-user-123',
    'userEmail': 'testcustomer@example.com',
    'userName': 'Test Customer',
    'customerId': null, // Will be created if needed
    'plateNumber': 'ABC1234',
    'contactNumber': '09123456789',
    'vehicleType': 'Sedan',
    'scheduledDateTime': Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 1, hours: 2)),
    ),
    'services': [
      {
        'serviceCode': 'EC1',
        'serviceName': 'Express Clean',
        'vehicleType': 'Sedan',
        'price': 180.0,
        'quantity': 1,
      },
      {
        'serviceCode': 'EC2',
        'serviceName': 'Express Clean Plus',
        'vehicleType': 'Sedan',
        'price': 200.0,
        'quantity': 1,
      },
    ],
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'status': 'pending',
    'paymentStatus': 'unpaid',
    'source': 'customer-app',
    'assignedTeam': null,
    'transactionId': null,
    'teamCommission': 0.0,
    'notes': 'Test booking created via script',
  };

  // Calculate total amount
  double totalAmount = 0.0;
  for (var service in testBooking['services'] as List) {
    totalAmount += (service['price'] as double) * (service['quantity'] as int);
  }
  testBooking['totalAmount'] = totalAmount;

  try {
    // Add to Firestore
    final docRef = await firestore.collection('Bookings').add(testBooking);

    print('✅ Test booking created successfully!');
    print('📋 Booking ID: ${docRef.id}');
    print('👤 Customer: ${testBooking['userName']}');
    print('🚗 Plate: ${testBooking['plateNumber']}');
    print('📅 Scheduled: ${(testBooking['scheduledDateTime'] as Timestamp).toDate()}');
    print('💰 Total Amount: ₱${totalAmount.toStringAsFixed(2)}');
    print('📊 Status: ${testBooking['status']}');
    print('💳 Payment Status: ${testBooking['paymentStatus']}');
    print('\n🔍 You can now test the workflow:');
    print('   1. Approve the booking in Admin Scheduling');
    print('   2. Mark as Paid (should move to Approved Kanban)');
    print('   3. Mark as Completed (should create transaction)');
  } catch (e) {
    print('❌ Error creating test booking: $e');
  }
}
