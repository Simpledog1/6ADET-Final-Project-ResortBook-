import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/status_badge.dart';

class ReservationDetailsScreen extends StatelessWidget {
  final Reservation reservation;

  const ReservationDetailsScreen({super.key, required this.reservation});

  String get _initials {
    final parts = reservation.guestName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  void _showComingSoon(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action reservations is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nights = DateFormatUtil.nights(
      reservation.checkInDate,
      reservation.checkOutDate,
    );

    return Scaffold(
      appBar: const AppHeader(title: 'Reservation Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              shadow: AppCard.largeShadow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Guest header: initials avatar, name, status
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _initials,
                            style: AppText.headerTitle.copyWith(
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reservation.guestName,
                                style: AppText.cardTitle.copyWith(
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 6),
                              StatusBadge(
                                status: reservation.status,
                                fontSize: 11,
                                horizontalPadding: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.divider,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.phone,
                          label: 'Contact Number',
                          value: reservation.phone.isEmpty
                              ? '—'
                              : reservation.phone,
                          showTopBorder: false,
                        ),
                        _InfoRow(
                          icon: Icons.email,
                          label: 'Email',
                          value: reservation.email.isEmpty
                              ? '—'
                              : reservation.email,
                        ),
                        _InfoRow(
                          icon: Icons.event_available,
                          label: 'Check-in Date',
                          value: DateFormatUtil.long(reservation.checkInDate),
                        ),
                        _InfoRow(
                          icon: Icons.event_busy,
                          label: 'Check-out Date',
                          value: DateFormatUtil.long(reservation.checkOutDate),
                        ),
                        _InfoRow(
                          icon: Icons.sell,
                          label: 'Reservation Status',
                          valueWidget: StatusBadge(
                            status: reservation.status,
                            fontSize: 11,
                            horizontalPadding: 12,
                          ),
                        ),
                        _InfoRow(
                          icon: Icons.badge,
                          label: 'Reservation ID',
                          value: '#${reservation.id}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Duration summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.primaryTintBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(
                      Icons.nightlight_round,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DURATION', style: AppText.overline),
                        const SizedBox(height: 2),
                        Text(
                          '$nights Night${nights == 1 ? '' : 's'} · '
                          '${DateFormatUtil.monthDay(reservation.checkInDate)} – '
                          '${DateFormatUtil.monthDay(reservation.checkOutDate)}',
                          style: AppText.valueStrong.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Pinned action buttons (Edit / Delete are placeholders for now)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _showComingSoon(context, 'Editing'),
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: const Text('Edit Reservation'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showComingSoon(context, 'Deleting'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cancelled,
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(
                      color: AppColors.cancelled,
                      width: 2,
                    ),
                  ),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete Reservation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One detail row: light-blue icon tile, uppercase label, value.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool showTopBorder;

  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.showTopBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showTopBorder
            ? const Border(top: BorderSide(color: AppColors.divider))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppText.overline),
                SizedBox(height: valueWidget != null ? 4 : 2),
                valueWidget ??
                    Text(value ?? '', style: AppText.valueStrong),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
