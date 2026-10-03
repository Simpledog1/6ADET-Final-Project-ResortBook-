import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import 'app_card.dart';
import 'status_badge.dart';

/// Dashboard "Upcoming Reservations" card:
/// name + status, phone, then Check-in / Check-out columns.
class UpcomingReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onTap;

  const UpcomingReservationCard({
    super.key,
    required this.reservation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NameRow(reservation: reservation),
          const SizedBox(height: 12),
          _IconText(
            icon: Icons.phone_outlined,
            text: reservation.phone.isEmpty ? '—' : reservation.phone,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabeledDate(
                    label: 'Check-in',
                    date: reservation.checkInDate,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _LabeledDate(
                    label: 'Check-out',
                    date: reservation.checkOutDate,
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

/// Reservation List card: name + status, date range, chevron.
class ReservationListCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onTap;

  const ReservationListCard({super.key, required this.reservation, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NameRow(reservation: reservation),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _IconText(
                  icon: Icons.calendar_today_outlined,
                  iconSize: 13,
                  text:
                      '${DateFormatUtil.short(reservation.checkInDate)} → ${DateFormatUtil.short(reservation.checkOutDate)}',
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Calendar "Reservations on <day>" card: tinted status, phone, divider,
/// check-in → check-out.
class CalendarReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onTap;

  const CalendarReservationCard({
    super.key,
    required this.reservation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: AppSpacing.radiusSm,
      shadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NameRow(reservation: reservation, tinted: true),
          const SizedBox(height: 12),
          _IconText(
            icon: Icons.phone,
            iconSize: 14,
            text: reservation.phone.isEmpty ? '—' : reservation.phone,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormatUtil.short(reservation.checkInDate),
                style: AppText.value,
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  DateFormatUtil.short(reservation.checkOutDate),
                  style: AppText.value,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple empty / error message card used on lists.
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyStateCard({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  final Reservation reservation;
  final bool tinted;

  const _NameRow({required this.reservation, this.tinted = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            reservation.guestName,
            style: AppText.cardTitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        StatusBadge(
          status: reservation.status,
          tinted: tinted,
          horizontalPadding: tinted ? 12 : 10,
        ),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final double iconSize;

  const _IconText({required this.icon, required this.text, this.iconSize = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: iconSize, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: AppText.bodySecondary,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LabeledDate extends StatelessWidget {
  final String label;
  final DateTime date;

  const _LabeledDate({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 2),
        Text(DateFormatUtil.short(date), style: AppText.value),
      ],
    );
  }
}
