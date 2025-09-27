import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/booking_data.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  List<Booking> _pendingBookings = [];
  List<Booking> _approvedBookings = [];
  List<Booking> _completedBookings = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, today

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      List<Booking> allBookings;
      if (_selectedFilter == 'today') {
        allBookings = await BookingManager.getTodayBookings();
      } else {
        allBookings = await BookingManager.getAllBookings();
      }

      // Separate bookings by status for Kanban columns
      setState(() {
        _pendingBookings = allBookings.where((b) => b.status == 'pending').toList();
        _approvedBookings = allBookings.where((b) => b.status == 'approved').toList();
        _completedBookings = allBookings.where((b) => b.status == 'completed').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookings: $e')),
        );
      }
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      // Find the booking from all lists
      Booking? booking;
      booking = _pendingBookings.where((b) => b.id == bookingId).firstOrNull;
      booking ??= _approvedBookings.where((b) => b.id == bookingId).firstOrNull;
      booking ??= _completedBookings.where((b) => b.id == bookingId).firstOrNull;

      if (booking == null) return;

      // Update booking status
      await BookingManager.updateBookingStatus(bookingId, status);

      // If marking as completed, create a transaction record
      if (status == 'completed') {
        await _createTransactionFromBooking(booking);
      }

      await _loadBookings(); // Refresh the list
      if (mounted) {
        String message = 'Booking status updated to $status';
        if (status == 'completed') {
          message += ' and transaction record created';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating booking: $e')),
        );
      }
    }
  }

  Future<void> _createTransactionFromBooking(Booking booking) async {
    try {
      final now = DateTime.now();

      // Build customer data matching POS format
      final customerMap = {
        "id": booking.userId,
        "plateNumber": booking.plateNumber.toUpperCase(),
        "name": booking.userName,
        "email": booking.userEmail,
        "contactNumber": booking.contactNumber,
        "vehicleType": booking.services.isNotEmpty ? booking.services.first.vehicleType : null,
      };

      // Build items matching POS format
      final items = booking.services.map((service) {
        return {
          "serviceCode": service.serviceCode,
          "vehicleType": service.vehicleType,
          "price": service.price,
          "quantity": 1,
          "subtotal": service.price,
        };
      }).toList();

      // Calculate total
      final double totalAmount = booking.totalAmount;

      // Create transaction payload matching POS format
      final payload = {
        "customer": customerMap,
        "items": items,
        "total": totalAmount,
        "cash": totalAmount, // Assume exact payment for bookings
        "change": 0.0,
        "date": Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        "time": {
          "hour": booking.selectedDateTime.hour,
          "minute": booking.selectedDateTime.minute,
          "formatted": TimeOfDay.fromDateTime(booking.selectedDateTime).format(context),
        },
        "createdAt": FieldValue.serverTimestamp(),
        "transactionAt": Timestamp.fromDate(booking.selectedDateTime),
        "status": "paid",
        "source": "booking", // Mark as coming from booking system
        "bookingId": booking.id, // Reference to original booking
      };

      // Save to Transactions collection
      await FirebaseFirestore.instance.collection("Transactions").add(payload);
    } catch (e) {
      throw Exception('Failed to create transaction from booking: $e');
    }
  }

  Future<void> _showRescheduleDialog(Booking booking) async {
    DateTime? selectedDate = booking.selectedDateTime;
    TimeOfDay? selectedTime = TimeOfDay.fromDateTime(booking.selectedDateTime);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reschedule Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${booking.userName}'),
              Text('Plate: ${booking.plateNumber}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() => selectedDate = date);
                  }
                },
                child: Text(selectedDate != null
                    ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                    : 'Select Date'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );
                  if (time != null) {
                    setDialogState(() => selectedTime = time);
                  }
                },
                child: Text(selectedTime != null
                    ? selectedTime!.format(context)
                    : 'Select Time'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedDate != null && selectedTime != null
                  ? () async {
                      final newDateTime = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      final timeString = selectedTime!.format(context);
                      Navigator.pop(context);
                      await _rescheduleBooking(
                        booking.id!,
                        newDateTime,
                        newDateTime.toIso8601String(),
                        timeString,
                      );
                    }
                  : null,
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rescheduleBooking(String bookingId, DateTime newDateTime, String newDate, String newTime) async {
    try {
      await BookingManager.rescheduleBooking(bookingId, newDateTime, newDate, newTime);
      await _loadBookings(); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking rescheduled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rescheduling booking: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Filter buttons and summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Summary row
                Row(
                  children: [
                    _buildSummaryCard('Pending', _pendingBookings.length, Colors.orange),
                    const SizedBox(width: 12),
                    _buildSummaryCard('Approved', _approvedBookings.length, Colors.blue),
                    const SizedBox(width: 12),
                    _buildSummaryCard('Completed', _completedBookings.length, Colors.green),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadBookings,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filter buttons
                Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Today', 'today'),
                  ],
                ),
              ],
            ),
          ),
          // Kanban Board
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pending Column
                      Expanded(
                        child: _buildKanbanColumn(
                          'Pending Approval',
                          _pendingBookings,
                          Colors.orange,
                          Icons.schedule,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Approved Column
                      Expanded(
                        child: _buildKanbanColumn(
                          'Approved',
                          _approvedBookings,
                          Colors.blue,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Completed Column
                      Expanded(
                        child: _buildKanbanColumn(
                          'Completed',
                          _completedBookings,
                          Colors.green,
                          Icons.done_all,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(String title, List<Booking> bookings, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Column Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bookings.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Column Content
          Expanded(
            child: bookings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No bookings',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final booking = bookings[index];
                      return _buildKanbanCard(booking);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        _loadBookings();
      },
      selectedColor: Colors.yellow.shade700,
      checkmarkColor: Colors.black,
    );
  }

  Widget _buildKanbanCard(Booking booking) {
    final isUpcoming = booking.selectedDateTime.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Customer name and time
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.userName.isNotEmpty ? booking.userName : 'Unknown Customer',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  booking.time,
                  style: TextStyle(
                    color: isUpcoming ? Colors.green.shade700 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Plate and contact
            Text(
              booking.plateNumber,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy').format(booking.selectedDateTime),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            // Services (compact)
            Text(
              '${booking.services.length} service(s)',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            // Total amount
            Text(
              '₱${booking.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            // Action buttons (compact)
            _buildKanbanCardActions(booking),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanCardActions(Booking booking) {
    if (booking.status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateBookingStatus(booking.id!, 'approved'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Approve'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _updateBookingStatus(booking.id!, 'cancelled'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Reject'),
            ),
          ),
        ],
      );
    } else if (booking.status == 'approved') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _updateBookingStatus(booking.id!, 'completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Mark Complete'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _showRescheduleDialog(booking),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 2),
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Reschedule'),
            ),
          ),
        ],
      );
    } else {
      // Completed - no actions needed
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Service Completed',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }
}