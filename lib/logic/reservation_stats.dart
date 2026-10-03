import '../models/reservation.dart';

/// Status groups used by the filter chips and counts.
enum ReservationStatusFilter { all, reserved, checkedIn, completed, cancelled }

/// Columns the reservation table can be sorted by.
enum ReservationSortField { guest, checkIn, checkOut }

/// Client-side calculations over reservations that are already loaded
/// (dashboard stats, list filtering, sorting and pagination).
///
/// Pure Dart (no Flutter, no network) so it can be unit tested. Cancelled
/// reservations never count as staying, arriving or occupying a unit.
class ReservationStats {
  ReservationStats._();

  static const int defaultPageSize = 20;

  // ── Status ─────────────────────────────────────────────────────────────

  /// Status group of a raw status text ("Checked In", "checked_in",
  /// "Canceled"…). Empty or unknown text counts as Reserved, matching how
  /// the status badge displays it.
  static ReservationStatusFilter statusGroup(String status) {
    final s = status.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (s.contains('cancel')) return ReservationStatusFilter.cancelled;
    if (s == 'checkedin') return ReservationStatusFilter.checkedIn;
    if (s == 'completed' || s == 'checkedout') {
      return ReservationStatusFilter.completed;
    }
    return ReservationStatusFilter.reserved;
  }

  static bool matchesStatus(
    Reservation reservation,
    ReservationStatusFilter filter,
  ) =>
      filter == ReservationStatusFilter.all ||
      statusGroup(reservation.status) == filter;

  /// Number of reservations per filter chip (including "All").
  static Map<ReservationStatusFilter, int> statusCounts(
    Iterable<Reservation> reservations,
  ) {
    final counts = {for (final f in ReservationStatusFilter.values) f: 0};
    for (final r in reservations) {
      counts[ReservationStatusFilter.all] =
          counts[ReservationStatusFilter.all]! + 1;
      final group = statusGroup(r.status);
      counts[group] = counts[group]! + 1;
    }
    return counts;
  }

  // ── Search ─────────────────────────────────────────────────────────────

  /// Case-insensitive guest-name search (same field the server search uses).
  static List<Reservation> search(
    Iterable<Reservation> reservations,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return reservations.toList();
    return reservations
        .where((r) => r.guestName.toLowerCase().contains(q))
        .toList();
  }

  // ── Dashboard numbers ──────────────────────────────────────────────────

  /// Non-cancelled reservations whose check-in falls in [now]'s month.
  static int reservationsThisMonth(
    Iterable<Reservation> reservations,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return reservations
        .where(
          (r) =>
              !r.isCancelled &&
              !r.startAt.isBefore(start) &&
              r.startAt.isBefore(end),
        )
        .length;
  }

  /// Non-cancelled reservations in progress at [now]
  /// (`startAt <= now < endAt`).
  static List<Reservation> stayingNow(
    Iterable<Reservation> reservations,
    DateTime now,
  ) {
    return reservations
        .where(
          (r) =>
              !r.isCancelled && !r.startAt.isAfter(now) && r.endAt.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.endAt.compareTo(b.endAt));
  }

  /// Non-cancelled reservations starting after [now] and before
  /// [now] + [days], soonest first.
  static List<Reservation> arrivingWithin(
    Iterable<Reservation> reservations,
    DateTime now, {
    int days = 7,
  }) {
    final limit = now.add(Duration(days: days));
    return reservations
        .where(
          (r) =>
              !r.isCancelled &&
              r.startAt.isAfter(now) &&
              r.startAt.isBefore(limit),
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  /// Number of different units with a reservation in progress at [now].
  static int unitsOccupiedNow(
    Iterable<Reservation> reservations,
    DateTime now,
  ) {
    return stayingNow(
      reservations,
      now,
    ).map((r) => r.unitId).where((id) => id.isNotEmpty).toSet().length;
  }

  /// Non-cancelled reservations that haven't ended yet, soonest first
  /// (the dashboard's "Upcoming Reservations").
  static List<Reservation> upcoming(
    Iterable<Reservation> reservations,
    DateTime now, {
    int limit = 3,
  }) {
    final list =
        reservations
            .where((r) => !r.isCancelled && r.endAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return list.take(limit).toList();
  }

  /// Most recently created reservations (by the PocketBase `created`
  /// timestamp). Reservations without one are left out.
  static List<Reservation> recentlyAdded(
    Iterable<Reservation> reservations, {
    int limit = 5,
  }) {
    final list = reservations.where((r) => r.createdAt != null).toList()
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return list.take(limit).toList();
  }

  // ── Sorting ────────────────────────────────────────────────────────────

  /// Returns a sorted copy. Ties are broken by check-in, then id, so the
  /// order is stable between rebuilds.
  static List<Reservation> sorted(
    Iterable<Reservation> reservations,
    ReservationSortField field, {
    bool ascending = true,
  }) {
    int compare(Reservation a, Reservation b) {
      final primary = switch (field) {
        ReservationSortField.guest =>
          a.guestName.trim().toLowerCase().compareTo(
            b.guestName.trim().toLowerCase(),
          ),
        ReservationSortField.checkIn => a.startAt.compareTo(b.startAt),
        ReservationSortField.checkOut => a.endAt.compareTo(b.endAt),
      };
      if (primary != 0) return ascending ? primary : -primary;
      final byStart = a.startAt.compareTo(b.startAt);
      if (byStart != 0) return byStart;
      return a.id.compareTo(b.id);
    }

    return reservations.toList()..sort(compare);
  }

  // ── Pagination ─────────────────────────────────────────────────────────

  /// Number of pages (at least 1, so an empty list still has page 1).
  static int pageCount(int itemCount, {int pageSize = defaultPageSize}) {
    if (itemCount <= 0 || pageSize <= 0) return 1;
    return (itemCount + pageSize - 1) ~/ pageSize;
  }

  /// [page] (zero-based) limited to the valid range.
  static int clampPage(
    int page,
    int itemCount, {
    int pageSize = defaultPageSize,
  }) {
    final last = pageCount(itemCount, pageSize: pageSize) - 1;
    if (page < 0) return 0;
    if (page > last) return last;
    return page;
  }

  /// Items on [page] (zero-based; out-of-range pages are clamped).
  static List<T> pageOf<T>(
    List<T> items,
    int page, {
    int pageSize = defaultPageSize,
  }) {
    if (items.isEmpty || pageSize <= 0) return <T>[];
    final p = clampPage(page, items.length, pageSize: pageSize);
    final start = p * pageSize;
    final end = start + pageSize > items.length
        ? items.length
        : start + pageSize;
    return items.sublist(start, end);
  }

  /// "Showing 21–40 of 45" text for a table footer.
  static String rangeLabel(
    int page,
    int itemCount, {
    int pageSize = defaultPageSize,
    String noun = 'reservations',
  }) {
    if (itemCount == 0) return 'No $noun';
    final p = clampPage(page, itemCount, pageSize: pageSize);
    final first = p * pageSize + 1;
    final last = (p + 1) * pageSize > itemCount
        ? itemCount
        : (p + 1) * pageSize;
    return 'Showing $first–$last of $itemCount $noun';
  }
}
