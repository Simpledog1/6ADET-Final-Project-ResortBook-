import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/desktop_page.dart';
import '../widgets/guest_avatar.dart';
import '../widgets/info_tile.dart';
import '../widgets/panel_card.dart';
import '../widgets/responsive.dart';
import '../widgets/status_badge.dart';

/// Reservation Details.
///
/// * Phone / tablet: the existing single-column card with pinned
///   Edit / Delete buttons.
/// * Desktop (sidebar shell): two columns — guest & reservation details and
///   duration on the left (~60%), timeline, pricing and notes on the right.
///
/// Edit and Delete are placeholders on both layouts (Stage 6).
class ReservationDetailsScreen extends StatelessWidget {
  final Reservation reservation;

  const ReservationDetailsScreen({super.key, required this.reservation});

  String get _initials => GuestAvatar.initialsOf(reservation.guestName);

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

  String get _guestCountText => reservation.guestCount > 0
      ? '${reservation.guestCount} '
            'Guest${reservation.guestCount == 1 ? '' : 's'}'
      : '—';

  @override
  Widget build(BuildContext context) {
    if (DesktopShellScope.isInside(context)) return _buildDesktop(context);
    return _buildMobile(context);
  }

  // ── Phone / tablet (unchanged layout, centred on tablets) ─────────────

  Widget _buildMobile(BuildContext context) {
    final r = reservation;
    final unitName = r.unitDisplayName.isEmpty ? '—' : r.unitDisplayName;
    final unitType = r.unitTypeDisplayName.isEmpty
        ? '—'
        : r.unitTypeDisplayName;

    return Scaffold(
      appBar: const AppHeader(title: 'Reservation Details'),
      body: ResponsiveContent(
        child: SingleChildScrollView(
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
                            value: _guestCountText,
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
      ),

      // Pinned action buttons (Edit / Delete are placeholders for now)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          // heightFactor keeps the bar as short as its buttons.
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
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
        ),
      ),
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    final r = reservation;

    return DesktopPage(
      title: 'Reservation Details',
      subtitle: r.guestName.isEmpty ? null : 'Booking for ${r.guestName}',
      breadcrumbs: [
        BreadcrumbItem(
          'Reservations',
          onTap: () =>
              DesktopShellScope.navigate(context, ShellSection.reservations),
        ),
        const BreadcrumbItem('Reservation Details'),
      ],
      actions: [
        // Placeholders until the Stage 6 edit / delete workflows exist.
        OutlinedButton.icon(
          style: CompactButtons.outlined(),
          onPressed: () => _showComingSoon(context, 'Editing'),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          style: CompactButtons.outlined(color: AppColors.cancelled),
          onPressed: () => _showComingSoon(context, 'Deleting'),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
        ),
      ],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDesktopGuestCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _TintCard(
                    icon: Icons.nightlight_round,
                    label: 'Duration',
                    value: _durationText,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelCard(
                    title: 'Reservation Timeline',
                    icon: Icons.timeline,
                    child: _Timeline(reservation: r),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PanelCard(
                    title: 'Pricing',
                    icon: Icons.payments_outlined,
                    subtitle: 'Saved when the reservation was made',
                    child: _PricingContent(reservation: r),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PanelCard(
                    title: 'Notes',
                    icon: Icons.sticky_note_2_outlined,
                    child: r.notes.trim().isEmpty
                        ? Row(
                            children: [
                              const Icon(
                                Icons.notes,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No notes for this reservation.',
                                  style: AppText.bodySecondary.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : SelectableText(r.notes, style: AppText.body),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopGuestCard() {
    final r = reservation;
    final tiles = <Widget>[
      InfoTile(label: 'Contact Number', value: r.phone, icon: Icons.phone),
      InfoTile(label: 'Reservation ID', value: '#${r.id}', icon: Icons.badge),
      InfoTile(label: 'Email', value: r.email, icon: Icons.email),
      InfoTile(
        label: 'Status',
        icon: Icons.sell,
        valueWidget: Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(status: r.status, fontSize: 11),
        ),
      ),
      InfoTile(
        label: 'Guests',
        value: _guestCountText == '—' ? '' : _guestCountText,
        icon: Icons.groups,
      ),
      InfoTile(
        label: 'Stay Type',
        value: r.stayTypeDisplayName,
        icon: Icons.schedule,
        supportingText: r.isLegacy
            ? 'Older reservation (no stay type saved)'
            : null,
      ),
      InfoTile(
        label: 'Unit',
        value: r.unitDisplayName,
        icon: Icons.meeting_room,
      ),
      InfoTile(
        label: 'Unit Type',
        value: r.unitTypeDisplayName,
        icon: Icons.category_outlined,
      ),
      InfoTile(
        label: 'Check-in',
        value: _dateTime(r.startAt),
        icon: Icons.event_available,
      ),
      InfoTile(
        label: 'Check-out',
        value: _dateTime(r.endAt),
        icon: Icons.event_busy,
      ),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                GuestAvatar(name: r.guestName, size: 64),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.guestName.isEmpty ? '—' : r.guestName,
                        style: AppText.cardTitle.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(
                            status: r.status,
                            fontSize: 11,
                            horizontalPadding: 12,
                          ),
                          Text(
                            '${r.stayTypeDisplayName} · '
                            '${r.unitDisplayName.isEmpty ? '—' : r.unitDisplayName}',
                            style: AppText.bodySecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppSpacing.lg;
                final columns = constraints.maxWidth >= 420 ? 2 : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: 20,
                  children: [
                    for (final tile in tiles)
                      SizedBox(width: width, child: tile),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Booking Created → Check-in → Check-out, with past milestones filled in.
class _Timeline extends StatelessWidget {
  final Reservation reservation;

  const _Timeline({required this.reservation});

  String _when(DateTime d) => reservation.isLegacy
      ? DateFormatUtil.long(d)
      : DateFormatUtil.shortWithTime(d);

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final now = DateTime.now();
    final created = r.createdAt;

    final items = <_TimelineItem>[
      _TimelineItem(
        icon: Icons.add_task,
        title: 'Booking Created',
        subtitle: created == null
            ? 'Not recorded'
            : DateFormatUtil.shortWithTime(created),
        done: created != null,
      ),
      _TimelineItem(
        icon: Icons.login,
        title: 'Check-in',
        subtitle: _when(r.startAt),
        done: !r.isCancelled && !r.startAt.isAfter(now),
        muted: r.isCancelled,
      ),
      _TimelineItem(
        icon: Icons.logout,
        title: 'Check-out',
        subtitle: _when(r.endAt),
        done: !r.isCancelled && !r.endAt.isAfter(now),
        muted: r.isCancelled,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          _TimelineRow(item: items[i], isLast: i == items.length - 1),
        if (r.isCancelled)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'This reservation was cancelled.',
              style: AppText.caption.copyWith(color: AppColors.cancelled),
            ),
          ),
      ],
    );
  }
}

class _TimelineItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool muted;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    this.muted = false,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineItem item;
  final bool isLast;

  const _TimelineRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final Color color = item.muted
        ? AppColors.textDisabled
        : (item.done ? AppColors.checkedIn : AppColors.primary);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.done ? color : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    item.done ? Icons.check : item.icon,
                    size: 16,
                    color: item.done ? Colors.white : color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: item.done ? AppColors.checkedIn : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppText.valueStrong.copyWith(
                      color: item.muted
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: AppText.caption),
                ],
              ),
            ),
          ),
        ],
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
                valueWidget ?? Text(value ?? '', style: AppText.valueStrong),
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
                  style: AppText.valueStrong.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone pricing card: "PRICING" label + [_PricingContent].
class _PricingCard extends StatelessWidget {
  final Reservation reservation;

  const _PricingCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PRICING', style: AppText.overline),
          const SizedBox(height: 8),
          _PricingContent(reservation: reservation),
        ],
      ),
    );
  }
}

/// Rate, pricing basis, quantity and total saved with the reservation (₱).
class _PricingContent extends StatelessWidget {
  final Reservation reservation;

  const _PricingContent({required this.reservation});

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
