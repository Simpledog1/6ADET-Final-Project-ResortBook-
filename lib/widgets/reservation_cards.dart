import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import 'app_card.dart';
import 'status_badge.dart';

/// Shared display helpers for reservation cards.
extension ReservationDisplay on Reservation {
  /// "Cottage 3 · Family Cottage" (falls back to "No unit assigned").
  String get unitLine {
    final name = unitDisplayName;
    final type = unitTypeDisplayName;
    if (name.isEmpty) return 'No unit assigned';
    return type.isEmpty ? name : '$name · $type';
  }

  /// "Overnight · 2 guests" (guest count omitted for legacy records).
  String get stayLine {
    final guests = guestCount > 0
        ? ' · $guestCount guest${guestCount == 1 ? '' : 's'}'
        : '';
    return '$stayTypeDisplayName$guests';
  }

  /// Legacy bookings were stored as whole dates, so their times are hidden.
  String get rangeLine =>
      DateFormatUtil.stayRange(startAt, endAt, datesOnly: isLegacy);

  bool get hasTotal => totalAmount > 0;
}

/// Dashboard "Upcoming Reservations" card:
/// guest + status, unit, stay type + guests, check-in / check-out
/// columns (date and time) and the total.
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
    final r = reservation;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NameRow(reservation: r),
          const SizedBox(height: 12),
          _IconText(icon: Icons.meeting_room_outlined, text: r.unitLine),
          const SizedBox(height: 6),
          _IconText(icon: Icons.schedule, text: r.stayLine),
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
                  child: _LabeledDateTime(
                    label: 'Check-in',
                    date: r.startAt,
                    showTime: !r.isLegacy,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _LabeledDateTime(
                    label: 'Check-out',
                    date: r.endAt,
                    showTime: !r.isLegacy,
                  ),
                ),
              ],
            ),
          ),
          if (r.hasTotal) ...[
            const SizedBox(height: 10),
            _TotalRow(amount: r.totalAmount),
          ],
        ],
      ),
    );
  }
}

/// Reservation List card: guest + status, unit, date/time range,
/// stay type + guests, total and chevron.
class ReservationListCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onTap;

  const ReservationListCard({super.key, required this.reservation, this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NameRow(reservation: r),
          const SizedBox(height: 10),
          _IconText(
            icon: Icons.meeting_room_outlined,
            iconSize: 14,
            text: r.unitLine,
          ),
          const SizedBox(height: 6),
          _IconText(
            icon: Icons.calendar_today_outlined,
            iconSize: 13,
            text: r.rangeLine,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _IconText(
                  icon: Icons.schedule,
                  iconSize: 14,
                  text: r.stayLine,
                ),
              ),
              if (r.hasTotal) ...[
                Text(
                  CurrencyFormat.peso(r.totalAmount),
                  style: AppText.valueStrong.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: 4),
              ],
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

/// Calendar "Reservations on `<day>`" card: tinted status, unit,
/// stay type + guests, divider, start → end with times.
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
    final r = reservation;
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
          _NameRow(reservation: r, tinted: true),
          const SizedBox(height: 12),
          _IconText(
            icon: Icons.meeting_room_outlined,
            iconSize: 14,
            text: r.unitLine,
          ),
          const SizedBox(height: 6),
          _IconText(icon: Icons.schedule, iconSize: 14, text: r.stayLine),
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
              Expanded(child: Text(r.rangeLine, style: AppText.value)),
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

class _LabeledDateTime extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool showTime;

  const _LabeledDateTime({
    required this.label,
    required this.date,
    this.showTime = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 2),
        Text(DateFormatUtil.short(date), style: AppText.value),
        if (showTime)
          Text(DateFormatUtil.time(date), style: AppText.bodySecondary),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final double amount;

  const _TotalRow({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Total', style: AppText.caption),
        const Spacer(),
        Text(
          CurrencyFormat.peso(amount),
          style: AppText.valueStrong.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}
