import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/booking_data.dart';
import 'package:intl/intl.dart';

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, approved, today

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      List<Booking> bookings;
      switch (_selectedFilter) {
        case 'pending':
          bookings = await BookingManager.getBookingsByStatus('pending');
          break;
        case 'approved':
          bookings = await BookingManager.getBookingsByStatus('approved');
          break;
        case 'today':
          bookings = await BookingManager.getTodayBookings();
          break;
        default:
          bookings = await BookingManager.getAllBookings();
      }
      setState(() {
        _bookings = bookings;
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
      await BookingManager.updateBookingStatus(bookingId, status);
      await _loadBookings(); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking status updated to $status')),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Filter buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', 'approved'),
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
          // Bookings list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bookings.isEmpty
                    ? const Center(
                        child: Text(
                          'No bookings found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          return _buildBookingCard(booking);
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

  Widget _buildBookingCard(Booking booking) {
    final statusColor = _getStatusColor(booking.status);
    final statusIcon = _getStatusIcon(booking.status);
    final isUpcoming = booking.selectedDateTime.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  booking.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  'Booking #${booking.id?.substring(0, 8) ?? 'N/A'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Customer info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.userName.isNotEmpty ? booking.userName : 'Unknown Customer',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plate: ${booking.plateNumber}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      Text(
                        'Contact: ${booking.contactNumber}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(booking.selectedDateTime),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      booking.time,
                      style: TextStyle(
                        color: isUpcoming ? Colors.green : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Services
            const Text(
              'Services:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...booking.services.map((service) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('• ${service.serviceName} (${service.vehicleType})'),
                      ),
                      Text(
                        '₱${service.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            // Total amount
            Row(
              children: [
                const Spacer(),
                Text(
                  'Total: ₱${booking.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                if (booking.status == 'pending') ...[
                  ElevatedButton.icon(
                    onPressed: () => _updateBookingStatus(booking.id!, 'approved'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _updateBookingStatus(booking.id!, 'cancelled'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                if (booking.status == 'approved' && isUpcoming) ...[
                  ElevatedButton.icon(
                    onPressed: () => _updateBookingStatus(booking.id!, 'completed'),
                    icon: const Icon(Icons.done, size: 16),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                const Spacer(),
                if (booking.status != 'completed' && booking.status != 'cancelled')
                  TextButton.icon(
                    onPressed: () => _showRescheduleDialog(booking),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text('Reschedule'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}