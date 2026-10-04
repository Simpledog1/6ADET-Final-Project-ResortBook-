import 'package:flutter/material.dart';
import '../logic/reservation_workflow.dart';
import '../models/reservation.dart';
import '../services/config_service.dart';
import '../services/reservation_gateway.dart';
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
import '../widgets/reservation_cards.dart';
import '../widgets/responsive.dart';
import '../widgets/status_badge.dart';
import 'add_reservation_screen.dart';

/// Reservation Details.
///
/// * Phone / tablet: the existing single-column card with pinned action
///   buttons.
/// * Desktop (sidebar shell): two columns — guest & reservation details and
///   duration on the left (~60%), timeline, pricing and notes on the right.
///
/// Actions depend on the status (see [ReservationWorkflow]):
/// * Reserved — Edit, Check In (from the check-in date), Cancel Reservation
/// * Checked In — Mark Completed, Edit (guest details and notes only)
/// * Completed — nothing
/// * Cancelled — Restore Reservation
///
/// After an action the reservation is reloaded from PocketBase. When the
/// page closes it returns `true` if anything changed, so the page that
/// opened it can refresh.
class ReservationDetailsScreen extends StatefulWidget {
  final Reservation reservation;

  /// PocketBase access; tests pass a fake.
  final ReservationGateway gateway;

  /// Current time; tests pass a fixed clock. Defaults to [DateTime.now].
  final DateTime Function()? clock;

  const ReservationDetailsScreen({
    super.key,
    required this.reservation,
    this.gateway = const ReservationGateway(),
    this.clock,
  });

  @override
  State<ReservationDetailsScreen> createState() =>
      _ReservationDetailsScreenState();
}

/// One button in the Details action area (same list on phone and desktop).
class _DetailAction {
  final Key key;
  final String label;

  /// Shorter label for the side-by-side phone buttons.
  final String shortLabel;
  final IconData icon;

  /// Null when the action is shown but disabled.
  final VoidCallback? onPressed;

  /// Filled button (main action) instead of outlined.
  final bool primary;

  /// Red outlined button (Cancel Reservation).
  final bool destructive;

  /// Why the action is disabled (tooltip / note).
  final String? disabledReason;

  const _DetailAction({
    required this.key,
    required this.label,
    String? shortLabel,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
    this.disabledReason,
  }) : shortLabel = shortLabel ?? label;
}

class _ReservationDetailsScreenState extends State<ReservationDetailsScreen> {
  /// The reservation as last loaded from PocketBase.
  late Reservation reservation;

  /// True while an action is running (buttons are disabled).
  bool _busy = false;

  /// True once something was saved, so the opener knows to refresh.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    reservation = widget.reservation;
  }

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  ReservationGateway get _gateway => widget.gateway;

  String get _initials => GuestAvatar.initialsOf(reservation.guestName);

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Reloads the reservation from PocketBase after an action.
  Future<void> _refresh() async {
    try {
      final fresh = await _gateway.getReservation(reservation.id);
      if (!mounted) return;
      setState(() => reservation = fresh);
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Could not reload the reservation. '
          '${ConfigService.friendlyError(e)}',
        );
      }
    }
  }

  /// Saves a status change, then reloads the reservation.
  Future<void> _changeStatus(String status, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await _gateway.updateStatus(reservation.id, status);
      _changed = true;
      await _refresh();
      if (mounted) _showMessage(doneMessage);
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Could not update the reservation. '
          '${ConfigService.friendlyError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Guest, unit, stay type and dates shown in the confirmation dialogs.
  Widget _summaryForDialog() {
    final r = reservation;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.value)),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(Icons.person, r.guestName.isEmpty ? '—' : r.guestName),
          line(Icons.meeting_room_outlined, r.unitLine),
          line(Icons.schedule, r.stayTypeDisplayName),
          line(Icons.event, r.rangeLine),
        ],
      ),
    );
  }

  Future<void> _cancelReservation() async {
    if (!ReservationWorkflow.canCancel(reservation, _now())) return;
    final unit = reservation.unitDisplayName.isEmpty
        ? 'The unit'
        : reservation.unitDisplayName;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel this reservation?',
      message:
          '$unit becomes available again for these dates. The reservation '
          'stays in your records and can be restored later.',
      confirmLabel: 'Cancel Reservation',
      cancelLabel: 'Keep Reservation',
      destructive: true,
      details: _summaryForDialog(),
    );
    if (!confirmed || !mounted) return;
    await _changeStatus(ReservationStatus.cancelled, 'Reservation cancelled.');
  }

  Future<void> _checkIn() async {
    if (!ReservationWorkflow.canCheckIn(reservation, _now())) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Check in this guest?',
      message: 'The reservation will be marked as Checked In.',
      confirmLabel: 'Check In',
      details: _summaryForDialog(),
    );
    if (!confirmed || !mounted) return;
    await _changeStatus(ReservationStatus.checkedIn, 'Guest checked in.');
  }

  Future<void> _complete() async {
    if (!ReservationWorkflow.canComplete(reservation, _now())) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Mark this stay as completed?',
      message:
          'The reservation will be marked as Completed and can no longer '
          'be edited.',
      confirmLabel: 'Mark Completed',
      details: _summaryForDialog(),
    );
    if (!confirmed || !mounted) return;
    await _changeStatus(ReservationStatus.completed, 'Stay marked completed.');
  }

  /// Cancelled → Reserved, only if the original time window is still free.
  Future<void> _restore() async {
    final r = reservation;
    if (!r.isCancelled) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Restore this reservation?',
      message:
          'It becomes Reserved again if the unit is still free for these '
          'dates.',
      confirmLabel: 'Restore',
      details: _summaryForDialog(),
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    String? problem;
    try {
      // Same check as booking: non-cancelled overlaps on this unit,
      // excluding this reservation, re-checked locally.
      final candidates = await _gateway.findOverlapping(
        unitId: r.unitId,
        start: r.startAt,
        end: r.endAt,
        excludeReservationId: r.id,
      );
      problem = ReservationWorkflow.restoreError(r, candidates);
    } catch (e) {
      problem =
          'Could not check availability. ${ConfigService.friendlyError(e)}';
    }
    if (!mounted) return;

    if (problem != null) {
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            "Can't restore this reservation",
            style: AppText.cardTitle.copyWith(fontSize: 18),
          ),
          content: Text(problem!, style: AppText.bodySecondary),
          actions: [
            FilledButton(
              style: CompactButtons.filled(),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _busy = false);
    await _changeStatus(ReservationStatus.reserved, 'Reservation restored.');
  }

  Future<void> _edit() async {
    if (!ReservationWorkflow.canEdit(reservation)) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AddReservationScreen(reservation: reservation, gateway: _gateway),
      ),
    );
    if (saved == true && mounted) {
      _changed = true;
      await _refresh();
    }
  }

  /// The actions for the current status, in display order.
  List<_DetailAction> _actions() {
    final r = reservation;
    final now = _now();
    final status = ReservationStatus.normalize(r.status);
    VoidCallback? when(bool allowed, VoidCallback action) =>
        (allowed && !_busy) ? action : null;

    final edit = _DetailAction(
      key: const ValueKey('action-edit'),
      label: 'Edit Reservation',
      shortLabel: 'Edit',
      icon: Icons.edit_note,
      onPressed: when(ReservationWorkflow.canEdit(r), _edit),
      primary:
          status == ReservationStatus.reserved ||
          status == ReservationStatus.completed,
      disabledReason: ReservationWorkflow.editBlockedReason(r),
    );

    switch (status) {
      case ReservationStatus.reserved:
        final canCheckIn = ReservationWorkflow.canCheckIn(r, now);
        return [
          edit,
          _DetailAction(
            key: const ValueKey('action-checkin'),
            label: 'Check In',
            icon: Icons.login,
            onPressed: when(canCheckIn, _checkIn),
            disabledReason: canCheckIn
                ? null
                : ReservationWorkflow.statusChangeError(
                    r,
                    ReservationStatus.checkedIn,
                    now,
                  ),
          ),
          _DetailAction(
            key: const ValueKey('action-cancel'),
            label: 'Cancel Reservation',
            icon: Icons.event_busy,
            onPressed: when(true, _cancelReservation),
            destructive: true,
          ),
        ];
      case ReservationStatus.checkedIn:
        return [
          _DetailAction(
            key: const ValueKey('action-complete'),
            label: 'Mark Completed',
            shortLabel: 'Complete',
            icon: Icons.task_alt,
            onPressed: when(true, _complete),
            primary: true,
          ),
          edit,
        ];
      case ReservationStatus.cancelled:
        return [
          _DetailAction(
            key: const ValueKey('action-restore'),
            label: 'Restore Reservation',
            shortLabel: 'Restore',
            icon: Icons.restore,
            onPressed: when(true, _restore),
            primary: true,
          ),
          edit,
        ];
      default: // Completed: nothing to do
        return [edit];
    }
  }

  /// First reason why an action is disabled (shown under the buttons).
  String? get _actionNote {
    for (final action in _actions()) {
      if (action.onPressed == null && action.disabledReason != null) {
        return action.disabledReason;
      }
    }
    return null;
  }

  /// A full-width button (phone) or compact button (desktop).
  /// [short] uses the shorter label (side-by-side phone buttons).
  Widget _actionButton(
    _DetailAction action, {
    required bool compact,
    bool short = false,
  }) {
    final label = Text(
      short ? action.shortLabel : action.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final Widget button;
    if (action.primary) {
      button = FilledButton.icon(
        key: action.key,
        style: compact ? CompactButtons.filled() : null,
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 20),
        label: label,
      );
    } else if (action.destructive) {
      button = OutlinedButton.icon(
        key: action.key,
        style: compact
            ? CompactButtons.outlined(color: AppColors.cancelled)
            : OutlinedButton.styleFrom(
                foregroundColor: AppColors.cancelled,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.cancelled, width: 2),
              ),
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: label,
      );
    } else {
      button = OutlinedButton.icon(
        key: action.key,
        style: compact
            ? CompactButtons.outlined()
            : OutlinedButton.styleFrom(backgroundColor: AppColors.surface),
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: label,
      );
    }

    if (action.onPressed == null && action.disabledReason != null) {
      return Tooltip(message: action.disabledReason!, child: button);
    }
    return button;
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

  /// Phone / tablet action area: the main actions side by side, the
  /// destructive Cancel Reservation full width underneath, then the note
  /// explaining a disabled action.
  List<Widget> _phoneActionArea() {
    final actions = _actions();
    final main = actions.where((a) => !a.destructive).toList();
    final destructive = actions.where((a) => a.destructive).toList();
    final note = _actionNote;

    final rows = <Widget>[
      if (main.length == 1)
        _actionButton(main.first, compact: false)
      else if (main.length > 1)
        Row(
          children: [
            for (var i = 0; i < main.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _actionButton(main[i], compact: false, short: true),
              ),
            ],
          ],
        ),
      for (final action in destructive) _actionButton(action, compact: false),
    ];

    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        rows[i],
      ],
      if (note != null) ...[
        const SizedBox(height: 8),
        Text(note, textAlign: TextAlign.center, style: AppText.caption),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final page = DesktopShellScope.isInside(context)
        ? _buildDesktop(context)
        : _buildMobile(context);

    // After a change, leaving the page returns `true` to the opener.
    return PopScope<bool>(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: page,
    );
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

      // Pinned action buttons (depend on the status)
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
                  children: _phoneActionArea(),
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
        for (final action in _actions()) _actionButton(action, compact: true),
      ],
      children: [
        if (_actionNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_actionNote!, style: AppText.caption)),
              ],
            ),
          ),
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
                    child: _Timeline(reservation: r, now: _now()),
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

/// Which timeline steps are done.
///
/// The status wins: Checked In means check-in is done (whatever the
/// scheduled time), Completed means both are done, Cancelled means neither.
/// Reserved bookings fall back to the scheduled times, as before.
@visibleForTesting
({bool checkIn, bool checkOut}) timelineProgress(
  Reservation reservation,
  DateTime now,
) {
  switch (ReservationStatus.normalize(reservation.status)) {
    case ReservationStatus.completed:
      return (checkIn: true, checkOut: true);
    case ReservationStatus.checkedIn:
      return (checkIn: true, checkOut: false);
    case ReservationStatus.cancelled:
      return (checkIn: false, checkOut: false);
    default:
      return (
        checkIn: !reservation.startAt.isAfter(now),
        checkOut: !reservation.endAt.isAfter(now),
      );
  }
}

/// Booking Created → Check-in → Check-out, with finished steps filled in.
class _Timeline extends StatelessWidget {
  final Reservation reservation;
  final DateTime now;

  const _Timeline({required this.reservation, required this.now});

  String _when(DateTime d) => reservation.isLegacy
      ? DateFormatUtil.long(d)
      : DateFormatUtil.shortWithTime(d);

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final created = r.createdAt;
    final progress = timelineProgress(r, now);

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
        done: progress.checkIn,
        muted: r.isCancelled,
      ),
      _TimelineItem(
        icon: Icons.logout,
        title: 'Check-out',
        subtitle: _when(r.endAt),
        done: progress.checkOut,
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
