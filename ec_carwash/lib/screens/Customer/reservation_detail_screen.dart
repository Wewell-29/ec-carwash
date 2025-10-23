import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReservationDetailScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> initialData;

  const ReservationDetailScreen({
    super.key,
    required this.bookingId,
    required this.initialData,
  });

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  DateTime? get _initialDateTime {
    final raw = widget.initialData['scheduledDateTime'] ??
        widget.initialData['selectedDateTime'] ?? widget.initialData['date'];
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    final parsed = DateTime.tryParse(raw.toString());
    return parsed;
  }

  DateTime? get _combinedDateTime {
    final base = _initialDateTime ?? DateTime.now();
    final d = _selectedDate ?? base;
    final t = _selectedTime ?? TimeOfDay.fromDateTime(base);
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _pickDate() async {
    final base = _initialDateTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: _selectedDate ?? base,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final base = _initialDateTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.fromDateTime(base),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    final dt = _combinedDateTime;
    if (dt == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(widget.bookingId)
          .update({
        'scheduledDateTime': Timestamp.fromDate(dt),
        'selectedDateTime': Timestamp.fromDate(dt), // legacy compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation rescheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = (widget.initialData['services'] as List<dynamic>?) ?? [];
    final plate = (widget.initialData['plateNumber'] ?? 'N/A').toString();
    final vehicleType = (widget.initialData['vehicleType'] ?? 'N/A').toString();
    final status = (widget.initialData['status'] ?? '').toString();
    final dt = _combinedDateTime ?? DateTime.now();
    final df = DateFormat('MMM dd, yyyy');
    final tf = DateFormat('hh:mm a');

    final isPending = status.toLowerCase() == 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservation Details'),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const Text('Plate Number'),
                  subtitle: Text(plate),
                  leading: const Icon(Icons.directions_car),
                ),
                ListTile(
                  title: const Text('Vehicle Type'),
                  subtitle: Text(vehicleType),
                  leading: const Icon(Icons.label),
                ),
                ListTile(
                  title: const Text('Status'),
                  subtitle: Text(status.isEmpty ? 'pending' : status),
                  leading: const Icon(Icons.info_outline),
                ),
                const Divider(),
                const Text(
                  'Services',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (services.isEmpty)
                  const Text('No services')
                else
                  ...services.map((s) {
                    final m = (s as Map<String, dynamic>);
                    final name = (m['serviceName'] ?? m['name'] ?? '').toString();
                    final vtype = (m['vehicleType'] ?? '').toString();
                    final price = (m['price'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      subtitle: Text(vtype.isNotEmpty ? vtype : ''),
                      trailing: Text(price),
                    );
                  }),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text('${df.format(dt)} at ${tf.format(dt)}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isPending ? _pickDate : null,
                              icon: const Icon(Icons.event, size: 18),
                              label: Text(df.format(dt)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isPending ? _pickTime : null,
                              icon: const Icon(Icons.access_time, size: 18),
                              label: Text(tf.format(dt)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isPending ? _save : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.yellow[700],
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
            if (_saving)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

