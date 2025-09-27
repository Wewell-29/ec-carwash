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
  List<Booking> _cancelledBookings = [];
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
      List<Booking> allBookings = [];
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
        _cancelledBookings = allBookings.where((b) => b.status == 'cancelled').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _pendingBookings = [];
        _approvedBookings = [];
        _completedBookings = [];
        _cancelledBookings = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookings: $e')),
        );
      }
    }
  }

  Future<void> _showTeamSelectionForApproval(Booking booking) async {
    String? selectedTeam;

    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without selection
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.groups, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Text("Assign Team & Approve"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Customer: ${booking.userName}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text("Plate: ${booking.plateNumber}"),
                  Text("Total: ₱${booking.totalAmount.toStringAsFixed(2)}"),
                  const SizedBox(height: 20),
                  const Text(
                    "Which team will handle this booking?",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedTeam = "Team A";
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedTeam == "Team A"
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade100,
                              border: Border.all(
                                color: selectedTeam == "Team A"
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade300,
                                width: selectedTeam == "Team A" ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.group,
                                  size: 40,
                                  color: selectedTeam == "Team A"
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Team A",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: selectedTeam == "Team A"
                                        ? Colors.blue.shade600
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedTeam = "Team B";
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedTeam == "Team B"
                                  ? Colors.green.shade100
                                  : Colors.grey.shade100,
                              border: Border.all(
                                color: selectedTeam == "Team B"
                                    ? Colors.green.shade600
                                    : Colors.grey.shade300,
                                width: selectedTeam == "Team B" ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.group,
                                  size: 40,
                                  color: selectedTeam == "Team B"
                                      ? Colors.green.shade600
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Team B",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: selectedTeam == "Team B"
                                        ? Colors.green.shade600
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: selectedTeam != null
                      ? () async {
                          Navigator.pop(context);
                          await _updateBookingStatusWithTeam(
                            booking.id!,
                            'approved',
                            selectedTeam!,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("Approve & Assign"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateBookingStatusWithTeam(String bookingId, String status, String team) async {
    try {
      // Find the booking from all lists
      Booking? booking;
      booking = _pendingBookings.where((b) => b.id == bookingId).firstOrNull;
      booking ??= _approvedBookings.where((b) => b.id == bookingId).firstOrNull;
      booking ??= _completedBookings.where((b) => b.id == bookingId).firstOrNull;
      booking ??= _cancelledBookings.where((b) => b.id == bookingId).firstOrNull;
      if (booking == null) return;

      // Update booking status with team assignment
      await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(bookingId)
          .update({
        'status': status,
        'assignedTeam': team,
        'teamCommission': booking.totalAmount * 0.35, // 35% commission
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadBookings(); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking $status and assigned to $team'),
            backgroundColor: Colors.green,
          ),
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

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      // Find the booking from all lists
      Booking? booking;
      booking = _pendingBookings.where((b) => b.id == bookingId).firstOrNull;
      booking ??= _approvedBookings.where((b) => b.id == bookingId).firstOrNull;
      booking ??= _completedBookings.where((b) => b.id == bookingId).firstOrNull;
      booking ??= _cancelledBookings.where((b) => b.id == bookingId).firstOrNull;

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
          // Header with filters only
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Today', 'today'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadBookings,
                ),
              ],
            ),
          ),
          // Kanban Board with 4 columns
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
                      const SizedBox(width: 6),
                      // Approved Column
                      Expanded(
                        child: _buildKanbanColumn(
                          'Approved',
                          _approvedBookings,
                          Colors.blue,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Completed Column
                      Expanded(
                        child: _buildKanbanColumn(
                          'Completed',
                          _completedBookings,
                          Colors.green,
                          Icons.done_all,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Cancelled Column
                      Expanded(
                        child: _buildKanbanColumn(
                          'Cancelled',
                          _cancelledBookings,
                          Colors.red,
                          Icons.cancel,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
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
            child: (bookings.isEmpty)
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
                      if (index >= bookings.length) return const SizedBox.shrink();
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Customer name
            Text(
              booking.userName.isNotEmpty ? booking.userName : 'Unknown Customer',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Date and Time - Highlighted
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(booking.selectedDateTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    booking.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Plate number
            Text(
              booking.plateNumber,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: booking.id != null ? () => _showTeamSelectionForApproval(booking) : null,
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
                  onPressed: booking.id != null ? () => _updateBookingStatus(booking.id!, 'cancelled') : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: booking.id != null ? () => _showRescheduleDialog(booking) : null,
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
    } else if (booking.status == 'approved') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: booking.id != null ? () => _updateBookingStatus(booking.id!, 'completed') : null,
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
              onPressed: booking.id != null ? () => _showRescheduleDialog(booking) : null,
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
    } else if (booking.status == 'completed') {
      // Completed - no actions needed
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
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
    } else {
      // Cancelled - no actions needed
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Booking Cancelled',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.red.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }
}