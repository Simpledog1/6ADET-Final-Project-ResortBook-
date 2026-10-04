import 'package:flutter/material.dart';
import '../logic/reservation_stats.dart';
import '../logic/reservation_workflow.dart';
import '../models/reservation.dart';
import '../services/config_service.dart';
import '../services/reservation_gateway.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/admin_table.dart';
import '../widgets/app_header.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/desktop_page.dart';
import '../widgets/filter_controls.dart';
import '../widgets/guest_avatar.dart';
import '../widgets/reservation_cards.dart';
import '../widgets/responsive.dart';
import '../widgets/state_cards.dart';
import '../widgets/status_badge.dart';
import 'add_reservation_screen.dart';
import 'reservation_details_screen.dart';

/// Reservation List.
///
/// * Phone / tablet: the existing search box + reservation cards.
/// * Desktop (sidebar shell): Figma table with status chips, sortable
///   Guest / Check-in / Check-out columns and 20 rows per page.
///
/// Both layouts use the same data: the guest-name search is sent to
/// PocketBase, and the desktop filters, sorts and pages the result locally.
class ReservationListScreen extends StatefulWidget {
  /// PocketBase access; tests pass a fake.
  final ReservationGateway gateway;

  const ReservationListScreen({
    super.key,
    this.gateway = const ReservationGateway(),
  });

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  String _searchQuery = '';
  late Future<List<Reservation>> _future;

  // Desktop table state
  ReservationStatusFilter _statusFilter = ReservationStatusFilter.all;
  ReservationSortField _sortField = ReservationSortField.checkIn;
  bool _sortAscending = false; // newest stay first, like the server order
  int _page = 0;

  static const _filterLabels = {
    ReservationStatusFilter.all: 'All',
    ReservationStatusFilter.reserved: ReservationStatus.reserved,
    ReservationStatusFilter.checkedIn: ReservationStatus.checkedIn,
    ReservationStatusFilter.completed: ReservationStatus.completed,
    ReservationStatusFilter.cancelled: ReservationStatus.cancelled,
  };

  // Table column index of each sortable field.
  static const _sortColumns = {
    ReservationSortField.guest: 0,
    ReservationSortField.checkIn: 3,
    ReservationSortField.checkOut: 4,
  };

  @override
  void initState() {
    super.initState();
    _future = widget.gateway.getReservations();
  }

  void _search(String value) {
    setState(() {
      _searchQuery = value;
      _page = 0;
      _future = widget.gateway.getReservations(searchQuery: value);
    });
  }

  void _reload() {
    setState(() {
      _future = widget.gateway.getReservations(searchQuery: _searchQuery);
    });
  }

  /// Opens Details; reloads when it reports a change (edit, cancel,
  /// check-in, complete or restore).
  Future<void> _openDetails(Reservation res) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            ReservationDetailsScreen(reservation: res, gateway: widget.gateway),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddReservationScreen(gateway: widget.gateway),
      ),
    );
    if (mounted) _reload();
  }

  void _onSort(int columnIndex) {
    final field = _sortColumns.entries
        .firstWhere((e) => e.value == columnIndex)
        .key;
    setState(() {
      if (field == _sortField) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopShellScope.isInside(context)) return _buildDesktop(context);
    return _buildMobile(context);
  }

  // ── Phone / tablet (unchanged layout, centred on tablets) ─────────────

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Reservation List'),
      body: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                12,
                AppSpacing.md,
                0,
              ),
              child: _SearchBox(onChanged: _search),
            ),
            Expanded(
              // Pull down to reload (also works on the error / empty state).
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => _reload(),
                child: FutureBuilder<List<Reservation>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          LoadErrorCard(
                            message:
                                'Could not load reservations.\n'
                                '${ConfigService.friendlyError(snapshot.error!)}',
                            onRetry: _reload,
                          ),
                        ],
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: const [
                          EmptyStateCard(
                            icon: Icons.search_off,
                            message: 'No reservations found.',
                          ),
                        ],
                      );
                    }

                    final reservations = snapshot.data!;

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      // Extra item at the end for the "N reservations total"
                      // footer
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
                            onTap: () => _openDetails(res),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return DesktopPage(
      title: 'Reservations',
      subtitle: 'Search, sort and open every booking at your resort.',
      breadcrumbs: [
        BreadcrumbItem(
          'Dashboard',
          onTap: () =>
              DesktopShellScope.navigate(context, ShellSection.dashboard),
        ),
        const BreadcrumbItem('Reservations'),
      ],
      onRefresh: () async => _reload(),
      actions: [
        SizedBox(
          width: 280,
          child: SearchField(hint: 'Search guest name', onChanged: _search),
        ),
        FilledButton.icon(
          style: CompactButtons.filled(),
          onPressed: _openAdd,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add Reservation'),
        ),
      ],
      children: [
        FutureBuilder<List<Reservation>>(
          future: _future,
          builder: (context, snapshot) {
            // While a new search loads, keep showing the previous result.
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg * 2),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return LoadErrorCard(
                message:
                    'Could not load reservations.\n'
                    '${ConfigService.friendlyError(snapshot.error!)}',
                onRetry: _reload,
              );
            }
            return _buildDesktopTable(snapshot.data ?? const []);
          },
        ),
      ],
    );
  }

  Widget _buildDesktopTable(List<Reservation> all) {
    final counts = ReservationStats.statusCounts(all);
    final filtered = all
        .where((r) => ReservationStats.matchesStatus(r, _statusFilter))
        .toList();
    final sorted = ReservationStats.sorted(
      filtered,
      _sortField,
      ascending: _sortAscending,
    );
    final pageCount = ReservationStats.pageCount(sorted.length);
    final page = ReservationStats.clampPage(_page, sorted.length);
    final rows = ReservationStats.pageOf(sorted, page);

    final chips = FilterChipBar<ReservationStatusFilter>(
      values: ReservationStatusFilter.values,
      labels: [
        for (final f in ReservationStatusFilter.values) _filterLabels[f]!,
      ],
      counts: [for (final f in ReservationStatusFilter.values) counts[f]!],
      selected: _statusFilter,
      onSelected: (f) => setState(() {
        _statusFilter = f;
        _page = 0;
      }),
    );

    final Widget content;
    if (all.isEmpty) {
      content = ActionEmptyCard(
        icon: _searchQuery.isEmpty ? Icons.event_note : Icons.search_off,
        message: _searchQuery.isEmpty
            ? 'No reservations yet.'
            : 'No reservations match "$_searchQuery".',
        actionLabel: _searchQuery.isEmpty ? 'Add Reservation' : null,
        onAction: _searchQuery.isEmpty ? _openAdd : null,
      );
    } else if (sorted.isEmpty) {
      content = ActionEmptyCard(
        icon: Icons.filter_alt_off_outlined,
        message:
            'No ${_filterLabels[_statusFilter]!.toLowerCase()} reservations.',
      );
    } else {
      content = AdminTable(
        columns: const [
          AdminColumn('Guest', flex: 5, sortable: true),
          AdminColumn('Unit', flex: 4),
          AdminColumn('Stay Type', flex: 3),
          AdminColumn('Check-in', flex: 3, sortable: true),
          AdminColumn('Check-out', flex: 3, sortable: true),
          AdminColumn('Guests', flex: 2, align: TextAlign.center),
          AdminColumn('Total', flex: 3, align: TextAlign.right),
          AdminColumn('Status', flex: 3, align: TextAlign.center),
          AdminColumn('', flex: 2, align: TextAlign.right),
        ],
        sortColumnIndex: _sortColumns[_sortField],
        sortAscending: _sortAscending,
        onSort: _onSort,
        rows: [for (final r in rows) _tableRow(r)],
        footer: ReservationStats.rangeLabel(page, sorted.length),
        pagination: AdminPagination(
          page: page,
          pageCount: pageCount,
          onPageChanged: (p) => setState(() => _page = p),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chips,
        const SizedBox(height: AppSpacing.md),
        content,
      ],
    );
  }

  AdminRow _tableRow(Reservation r) {
    final unitName = r.unitDisplayName.isEmpty ? '—' : r.unitDisplayName;
    final unitType = r.unitTypeDisplayName;

    return AdminRow(
      onTap: () => _openDetails(r),
      cells: [
        // Guest
        Row(
          children: [
            GuestAvatar(name: r.guestName, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: _CellText(
                r.guestName.isEmpty ? '—' : r.guestName,
                strong: true,
              ),
            ),
          ],
        ),
        // Unit
        _TwoLineCell(top: unitName, bottom: unitType),
        // Stay type
        _CellText(r.stayTypeDisplayName),
        // Check-in / check-out (dates only for older bookings)
        _TwoLineCell(
          top: DateFormatUtil.short(r.startAt),
          bottom: r.isLegacy ? '' : DateFormatUtil.time(r.startAt),
          scaleDown: true,
        ),
        _TwoLineCell(
          top: DateFormatUtil.short(r.endAt),
          bottom: r.isLegacy ? '' : DateFormatUtil.time(r.endAt),
          scaleDown: true,
        ),
        // Guests
        _CellText(r.guestCount > 0 ? '${r.guestCount}' : '—'),
        // Total
        _CellText(
          r.totalAmount > 0 ? CurrencyFormat.peso(r.totalAmount) : '—',
          strong: true,
        ),
        // Status
        FittedBox(
          fit: BoxFit.scaleDown,
          child: StatusBadge(status: r.status, tinted: true, fontSize: 11),
        ),
        // Actions
        Tooltip(
          message: 'View details',
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: AppColors.primary,
              textStyle: AppText.value.copyWith(fontSize: 13),
            ),
            onPressed: () => _openDetails(r),
            child: const Text('View'),
          ),
        ),
      ],
    );
  }
}

/// Single-line table text that never wraps.
class _CellText extends StatelessWidget {
  final String text;
  final bool strong;

  const _CellText(this.text, {this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: (strong ? AppText.valueStrong : AppText.value).copyWith(
        fontSize: 13,
      ),
    );
  }
}

/// Main value with a muted second line (unit type, time).
class _TwoLineCell extends StatelessWidget {
  final String top;
  final String bottom;

  /// Shrinks the text instead of cutting it off (dates in narrow columns).
  final bool scaleDown;

  const _TwoLineCell({
    required this.top,
    required this.bottom,
    this.scaleDown = false,
  });

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CellText(top),
        if (bottom.isNotEmpty)
          Text(
            bottom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: AppText.caption,
          ),
      ],
    );
    if (!scaleDown) return column;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: column,
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
