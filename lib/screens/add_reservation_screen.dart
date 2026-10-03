// Location: lib/screens/add_reservation_screen.dart
import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import '../models/room.dart';
import '../models/reservation.dart';
import '../theme/app_spacing.dart';

class AddReservationScreen extends StatefulWidget {
  const AddReservationScreen({super.key});

  @override
  State<AddReservationScreen> createState() => _AddReservationScreenState();
}

class _AddReservationScreenState extends State<AddReservationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  Room? _selectedRoom;

  List<Room> _rooms = [];
  bool _isLoadingRooms = true;
  bool _isSubmitting = false;
  String? _conflictError;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    try {
      final records = await PocketBaseService.pb
          .collection('rooms')
          .getFullList();
      setState(() {
        _rooms = records.map((r) => Room.fromRecord(r)).toList();
        _isLoadingRooms = false;
      });
    } catch (e) {
      setState(() => _isLoadingRooms = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading rooms: $e')));
    }
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          // Auto-adjust checkout date if it's before the new check-in date
          if (_checkOutDate != null && _checkOutDate!.isBefore(picked)) {
            _checkOutDate = picked.add(const Duration(days: 1));
          }
        } else {
          _checkOutDate = picked;
        }
        _conflictError = null; // Clear any previous conflict error
      });
    }
  }

  Future<void> _submitReservation() async {
    if (!_formKey.currentState!.validate() ||
        _checkInDate == null ||
        _checkOutDate == null ||
        _selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out all fields and select dates.'),
        ),
      );
      return;
    }

    if (_checkOutDate!.isBefore(_checkInDate!) ||
        _checkOutDate!.isAtSameMomentAs(_checkInDate!)) {
      setState(
        () => _conflictError = "Check-out date must be after check-in date.",
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    try {
      // 1. Fetch existing reservations for the selected room
      final existingRecords = await PocketBaseService.pb
          .collection('reservations')
          .getFullList(filter: "assignedRoomId = '${_selectedRoom!.id}'");

      bool hasConflict = false;

      // 2. Client-side Validation Logic
      // (New Check-In < Existing Check-Out) AND (New Check-Out > Existing Check-In)
      for (var record in existingRecords) {
        final existingRes = Reservation.fromRecord(record);

        if (_checkInDate!.isBefore(existingRes.checkOutDate) &&
            _checkOutDate!.isAfter(existingRes.checkInDate)) {
          hasConflict = true;
          break;
        }
      }

      // 3. Block write and show ConflictAlertBanner if overlap exists
      if (hasConflict) {
        setState(() {
          _conflictError =
              "Conflict! The selected dates overlap with an existing booking for this room.";
          _isSubmitting = false;
        });
        return;
      }

      // 4. No conflict -> Execute Database Write
      final body = {
        'guestName': _nameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'checkInDate': _checkInDate!.toIso8601String(),
        'checkOutDate': _checkOutDate!.toIso8601String(),
        'assignedRoomId': _selectedRoom!.id,
        'status': 'Reserved',
      };

      await PocketBaseService.pb.collection('reservations').create(body: body);

      // Reset form on success
      _formKey.currentState!.reset();
      setState(() {
        _checkInDate = null;
        _checkOutDate = null;
        _selectedRoom = null;
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation successfully created!')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving reservation: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Reservation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Conflict Alert Banner
            if (_conflictError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade400),
                ),
                child: Text(
                  _conflictError!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Guest Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            _isLoadingRooms
                ? const CircularProgressIndicator()
                : DropdownButtonFormField<Room>(
                    decoration: const InputDecoration(
                      labelText: 'Assign Room',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedRoom,
                    items: _rooms.map((room) {
                      return DropdownMenuItem(
                        value: room,
                        child: Text('Room ${room.roomNumber} - ${room.type}'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRoom = val),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context, true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _checkInDate == null
                          ? 'Check-In'
                          : '${_checkInDate!.toLocal()}'.split(' ')[0],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context, false),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _checkOutDate == null
                          ? 'Check-Out'
                          : '${_checkOutDate!.toLocal()}'.split(' ')[0],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg * 2),

            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitReservation,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Reservation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
