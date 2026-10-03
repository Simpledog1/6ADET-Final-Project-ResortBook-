import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
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

  /// Date with time, or date only for legacy bookings stored without times.
  String _dateTime(DateTime d) => reservation.isLegacy
      ? DateFormatUtil.long(d)
      : '${DateFormatUtil.long(d)} · ${DateFormatUtil.time(d)}';

  /// "2 Nights · Overnight" / "Day Tour · same day" / legacy nights.
  String get _durationText {
    final r = reservation;
    final nights = DateFormatUtil.nights(r.startAt, r.endAt);
    final range = r.isLegacy
        ? '${DateFormatUtil.monthDay(r.startAt)} – '
            '${DateFormatUtil.monthDay(r.endAt)}'
        : DateFormatUtil.stayRange(r.startAt, r.endAt);
    final length = nights == 0
        ? 'Same day'
        : '$nights Night${nights == 1 ? '' : 's'}';
    return '${r.stayTypeDisplayName} · $length\n$range';
  }

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final unitName = r.unitDisplayName.isEmpty ? '—' : r.unitDisplayName;
    final unitType = r.unitTypeDisplayName.isEmpty ? '—' : r.unitTypeDisplayName;

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
                                r.guestName,
                                style: AppText.cardTitle.copyWith(
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 6),
                              StatusBadge(
                                status: r.status,
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
                          value: r.phone.isEmpty ? '—' : r.phone,
                          showTopBorder: false,
                        ),
                        _InfoRow(
                          icon: Icons.email,
                          label: 'Email',
                          value: r.email.isEmpty ? '—' : r.email,
                        ),
                        _InfoRow(
                          icon: Icons.groups,
                          label: 'Number of Guests',
                          value: r.guestCount > 0
                              ? '${r.guestCount} '
                                  'Guest${r.guestCount == 1 ? '' : 's'}'
                              : '—',
                        ),
                        _InfoRow(
                          icon: Icons.meeting_room,
                          label: 'Unit',
                          value: unitName,
                          subValue: unitType,
                        ),
                        _InfoRow(
                          icon: Icons.schedule,
                          label: 'Stay Type',
                          value: r.stayTypeDisplayName,
                          subValue: r.isLegacy
                              ? 'Older reservation (no stay type saved)'
                              : null,
                        ),
                        _InfoRow(
                          icon: Icons.event_available,
                          label: 'Check-in',
                          value: _dateTime(r.startAt),
                        ),
                        _InfoRow(
                          icon: Icons.event_busy,
                          label: 'Check-out',
                          value: _dateTime(r.endAt),
                        ),
                        _InfoRow(
                          icon: Icons.sell,
                          label: 'Reservation Status',
                          valueWidget: StatusBadge(
                            status: r.status,
                            fontSize: 11,
                            horizontalPadding: 12,
                          ),
                        ),
                        if (r.notes.isNotEmpty)
                          _InfoRow(
                            icon: Icons.sticky_note_2,
                            label: 'Notes',
                            value: r.notes,
                          ),
                        _InfoRow(
                          icon: Icons.badge,
                          label: 'Reservation ID',
                          value: '#${r.id}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Duration summary
            _TintCard(
              icon: Icons.nightlight_round,
              label: 'Duration',
              value: _durationText,
            ),
            const SizedBox(height: AppSpacing.md),

            // Pricing (snapshot saved with the reservation)
            _PricingCard(reservation: r),
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
  final String? subValue;
  final Widget? valueWidget;
  final bool showTopBorder;

  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.subValue,
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
                if (subValue != null && subValue!.isNotEmpty)
                  Text(subValue!, style: AppText.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Light-blue summary card (Figma "Duration" card).
class _TintCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TintCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppText.overline),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppText.valueStrong.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rate, pricing basis, quantity and total saved with the reservation (₱).
class _PricingCard extends StatelessWidget {
  final Reservation reservation;

  const _PricingCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final hasPrice = r.totalAmount > 0 || r.rate > 0;
    final perNight = r.rateBasis == 'per_night';
    final basisLabel = r.rateBasis.isEmpty
        ? '—'
        : (perNight ? 'Per night' : 'Per stay');
    final quantityLabel = r.quantity <= 0
        ? '—'
        : perNight
            ? '${r.quantity} night${r.quantity == 1 ? '' : 's'}'
            : '${r.quantity} stay${r.quantity == 1 ? '' : 's'}';

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PRICING', style: AppText.overline),
          const SizedBox(height: 8),
          if (!hasPrice)
            const Text(
              'No price was recorded for this reservation.',
              style: AppText.bodySecondary,
            )
          else ...[
            _priceRow('Rate', CurrencyFormat.peso(r.rate)),
            _priceRow('Pricing basis', basisLabel),
            _priceRow('Quantity', quantityLabel),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, thickness: 1, color: AppColors.divider),
            ),
            Row(
              children: [
                const Text('Total', style: AppText.valueStrong),
                const Spacer(),
                Text(
                  CurrencyFormat.peso(r.totalAmount),
                  style: AppText.cardTitle.copyWith(
                    fontSize: 20,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: AppText.bodySecondary),
          const Spacer(),
          Text(value, style: AppText.value),
        ],
      ),
    );
  }
}
