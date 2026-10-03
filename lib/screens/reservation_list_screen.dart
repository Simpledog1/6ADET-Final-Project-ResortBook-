import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/reservation_cards.dart';
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
    return Scaffold(
      appBar: const AppHeader(title: 'Reservation List'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              12,
              AppSpacing.md,
              0,
            ),
            child: _SearchBox(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Reservation>>(
              future: PocketBaseService.getReservations(
                searchQuery: _searchQuery,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: EmptyStateCard(
                        icon: Icons.cloud_off_outlined,
                        message: 'Error loading data: ${snapshot.error}',
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: EmptyStateCard(
                        icon: Icons.search_off,
                        message: 'No reservations found.',
                      ),
                    ),
                  );
                }

                final reservations = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  // Extra item at the end for the "N reservations total" footer
                  itemCount: reservations.length + 1,
                  itemBuilder: (context, index) {
                    if (index == reservations.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          '${reservations.length} reservation${reservations.length == 1 ? '' : 's'} total',
                          textAlign: TextAlign.center,
                          style: AppText.caption.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    final res = reservations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ReservationListCard(
                        reservation: res,
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
}

/// 48px rounded search field from the Figma design.
class _SearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c),
        );

    return Container(
      height: AppSpacing.searchHeight,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: TextField(
        style: AppText.body,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search Reservation',
          hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textMuted,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 13.5),
          isDense: true,
          border: border(AppColors.border),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.primary),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
