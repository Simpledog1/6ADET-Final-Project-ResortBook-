import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import '../models/reservation.dart';
import 'reservation_details_screen.dart';

class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({super.key});

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search guest name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: FutureBuilder<List<Reservation>>(
              future: PocketBaseService.getReservations(
                searchQuery: _searchQuery,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading data: ${snapshot.error}'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No reservations found.'));
                }

                final reservations = snapshot.data!;

                return ListView.builder(
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final res = reservations[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: const Icon(Icons.person),
                        ),
                        title: Text(
                          res.guestName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        // Fixed: Using checkInDate and checkOutDate to match your model
                        subtitle: Text(
                          '${_formatDate(res.checkInDate)} — ${_formatDate(res.checkOutDate)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Phase 6 Integration
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReservationDetailsScreen(reservation: res),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateData) {
    if (dateData == null || dateData.toString().isEmpty) return 'TBD';
    try {
      DateTime date = dateData is DateTime
          ? dateData
          : DateTime.parse(dateData.toString());
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateData.toString().split(' ').first;
    }
  }
}
