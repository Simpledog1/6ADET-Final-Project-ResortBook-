import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../theme/app_spacing.dart';

class ReservationDetailsScreen extends StatelessWidget {
  final Reservation reservation;

  const ReservationDetailsScreen({super.key, required this.reservation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservation Details'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(reservation.guestName),
                  subtitle: const Text('Name'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(reservation.phone),
                  subtitle: const Text('Phone'),
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(reservation.email),
                  subtitle: const Text('Email'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Booking Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    '${_formatDate(reservation.checkInDate)} to ${_formatDate(reservation.checkOutDate)}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(reservation.status),
                  subtitle: const Text('Status'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
