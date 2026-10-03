import '../models/reservation.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import '../utils/date_format.dart';
import 'booking_logic.dart';

/// The four reservation statuses the app writes to PocketBase.
///
/// `status` is a text field, so older records may use other spellings
/// ("checked_in", "Canceled"…). [ReservationStatus.normalize] maps those to
/// one of these values.
class ReservationStatus {
  ReservationStatus._();

  static const String reserved = 'Reserved';
  static const String checkedIn = 'Checked In';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  static const List<String> all = [reserved, checkedIn, completed, cancelled];

  /// One of the four statuses for any stored text. Empty or unknown text
  /// counts as Reserved (that is also how the status badge shows it).
  static String normalize(String status) {
    final s = status.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (s.contains('cancel')) return cancelled;
    if (s == 'checkedin') return checkedIn;
    if (s == 'completed' || s == 'checkedout') return completed;
    return reserved;
  }
}

/// How much of a reservation can be changed in the Edit Reservation form.
enum EditAccess {
  /// Reserved: every field.
  everything,

  /// Checked In: guest details (name, phone, email, guest count) and notes.
  guestDetailsOnly,

  /// Completed / Cancelled: nothing.
  none,
}

/// The fields of the Edit Reservation form.
enum ReservationField {
  guestName,
  phone,
  email,
  guestCount,
  notes,
  unit,
  stayType,
  dates,
}

/// The values in the Edit Reservation form when the user presses Save.
///
/// Text values should already be trimmed. [startAt] / [endAt] are the
/// reservation's original times unless the user changed the stay type or
/// the dates (then they are the newly computed window).
class ReservationDraft {
  final String guestName;
  final String phone;
  final String email;
  final int guestCount;
  final String notes;
  final String unitId;
  final String stayTypeId;
  final DateTime startAt;
  final DateTime endAt;

  const ReservationDraft({
    required this.guestName,
    required this.phone,
    required this.email,
    required this.guestCount,
    required this.notes,
    required this.unitId,
    required this.stayTypeId,
    required this.startAt,
    required this.endAt,
  });

  /// A draft with the reservation's current values (nothing changed yet).
  factory ReservationDraft.fromReservation(Reservation r) {
    return ReservationDraft(
      guestName: r.guestName,
      phone: r.phone,
      email: r.email,
      guestCount: r.guestCount,
      notes: r.notes,
      unitId: r.unitId,
      stayTypeId: r.stayTypeId,
      startAt: r.startAt,
      endAt: r.endAt,
    );
  }

  /// Copy with some values replaced (used by the form and the tests).
  ReservationDraft copyWith({
    String? guestName,
    String? phone,
    String? email,
    int? guestCount,
    String? notes,
    String? unitId,
    String? stayTypeId,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return ReservationDraft(
      guestName: guestName ?? this.guestName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      guestCount: guestCount ?? this.guestCount,
      notes: notes ?? this.notes,
      unitId: unitId ?? this.unitId,
      stayTypeId: stayTypeId ?? this.stayTypeId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }
}

/// What an edit changes and which checks it needs before saving.
class EditPlan {
  /// Fields whose value differs from the saved reservation.
  final Set<ReservationField> changedFields;

  /// Why the edit can't be saved (status or older-reservation rules), or
  /// null when it is allowed.
  final String? error;

  const EditPlan({required this.changedFields, this.error});

  bool get hasChanges => changedFields.isNotEmpty;
  bool get isAllowed => error == null;

  bool get unitChanged => changedFields.contains(ReservationField.unit);

  /// Stay type or dates changed.
  bool get scheduleChanged =>
      changedFields.contains(ReservationField.stayType) ||
      changedFields.contains(ReservationField.dates);

  /// Unit, stay type or dates changed: the booking moves, so availability
  /// must be checked again (excluding this reservation).
  bool get needsAvailabilityCheck => unitChanged || scheduleChanged;

  /// Same changes as [needsAvailabilityCheck]: the price is recalculated
  /// with the current rate and every snapshot is replaced. Otherwise the
  /// saved start/end, rate and total are kept exactly.
  bool get needsRepricing => unitChanged || scheduleChanged;

  /// Guest count or unit changed: check the guest count against the unit's
  /// capacity. Contact-only edits are never blocked by capacity.
  bool get needsCapacityCheck =>
      unitChanged || changedFields.contains(ReservationField.guestCount);
}

/// Reservation management rules (status changes and editing).
///
/// Pure Dart (no Flutter, no network) so they can be unit tested. Overlap
/// and pricing rules come from [BookingLogic], which is reused unchanged.
class ReservationWorkflow {
  ReservationWorkflow._();

  // ── Check-in timing ────────────────────────────────────────────────────

  /// True when [now] is on or after the reservation's local check-in date
  /// (the time of day doesn't matter).
  static bool isOnOrAfterCheckInDate(Reservation reservation, DateTime now) {
    final checkInDay = DateFormatUtil.dateOnly(reservation.startAt);
    final today = DateFormatUtil.dateOnly(now);
    return !today.isBefore(checkInDay);
  }

  // ── Status changes ─────────────────────────────────────────────────────

  /// Why [reservation] can't move to [newStatus], or null when it can.
  ///
  /// Allowed: Reserved → Checked In (on or after the check-in date),
  /// Reserved → Cancelled, Checked In → Completed. Cancelled → Reserved is
  /// only possible through [restoreError] (it checks availability).
  static String? statusChangeError(
    Reservation reservation,
    String newStatus,
    DateTime now,
  ) {
    final from = ReservationStatus.normalize(reservation.status);

    if (!ReservationStatus.all.contains(newStatus)) {
      return '"$newStatus" is not a reservation status.';
    }
    if (from == newStatus) return 'This reservation is already $from.';

    if (from == ReservationStatus.reserved &&
        newStatus == ReservationStatus.checkedIn) {
      if (!isOnOrAfterCheckInDate(reservation, now)) {
        return 'Check-in opens on '
            '${DateFormatUtil.long(reservation.startAt)}.';
      }
      return null;
    }
    if (from == ReservationStatus.reserved &&
        newStatus == ReservationStatus.cancelled) {
      return null;
    }
    if (from == ReservationStatus.checkedIn &&
        newStatus == ReservationStatus.completed) {
      return null;
    }
    if (from == ReservationStatus.cancelled &&
        newStatus == ReservationStatus.reserved) {
      return 'Use Restore to reopen a cancelled reservation.';
    }
    return 'A $from reservation cannot be changed to $newStatus.';
  }

  static bool canChangeStatus(
    Reservation reservation,
    String newStatus,
    DateTime now,
  ) => statusChangeError(reservation, newStatus, now) == null;

  static bool canCheckIn(Reservation reservation, DateTime now) =>
      canChangeStatus(reservation, ReservationStatus.checkedIn, now);

  static bool canComplete(Reservation reservation, DateTime now) =>
      canChangeStatus(reservation, ReservationStatus.completed, now);

  static bool canCancel(Reservation reservation, DateTime now) =>
      canChangeStatus(reservation, ReservationStatus.cancelled, now);

  // ── Restore (Cancelled → Reserved) ─────────────────────────────────────

  /// Reservations that would overlap [reservation] if it were restored
  /// (same unit, not cancelled, itself excluded).
  static List<Reservation> restoreConflicts(
    Reservation reservation,
    Iterable<Reservation> existing,
  ) {
    final window = StayWindow(
      start: reservation.startAt,
      end: reservation.endAt,
      nights: BookingLogic.nightsBetween(
        reservation.startAt,
        reservation.endAt,
      ),
    );
    return BookingLogic.findConflicts(
      unitId: reservation.unitId,
      window: window,
      existing: existing,
      excludeReservationId: reservation.id,
    );
  }

  /// Why [reservation] can't be restored, or null when it can.
  /// [existing] should contain the other reservations of the same unit.
  static String? restoreError(
    Reservation reservation,
    Iterable<Reservation> existing,
  ) {
    if (!reservation.isCancelled) {
      return 'Only cancelled reservations can be restored.';
    }
    final conflicts = restoreConflicts(reservation, existing);
    if (conflicts.isNotEmpty) {
      final c = conflicts.first;
      final unit = reservation.unitDisplayName.isEmpty
          ? 'This unit'
          : reservation.unitDisplayName;
      return '$unit is already booked from '
          '${DateFormatUtil.shortWithTime(c.startAt)} to '
          '${DateFormatUtil.shortWithTime(c.endAt)}'
          '${c.guestName.isEmpty ? '' : ' (${c.guestName})'}.';
    }
    return null;
  }

  // ── Edit permissions ───────────────────────────────────────────────────

  static EditAccess editAccess(Reservation reservation) {
    switch (ReservationStatus.normalize(reservation.status)) {
      case ReservationStatus.reserved:
        return EditAccess.everything;
      case ReservationStatus.checkedIn:
        return EditAccess.guestDetailsOnly;
      default:
        return EditAccess.none;
    }
  }

  static bool canEdit(Reservation reservation) =>
      editAccess(reservation) != EditAccess.none;

  /// Fields the Edit Reservation form may change. Status is never one of
  /// them (it has its own actions).
  static Set<ReservationField> editableFields(Reservation reservation) {
    final access = editAccess(reservation);
    if (access == EditAccess.everything) {
      return ReservationField.values.toSet();
    }
    if (access == EditAccess.guestDetailsOnly) {
      return {
        ReservationField.guestName,
        ReservationField.phone,
        ReservationField.email,
        ReservationField.guestCount,
        ReservationField.notes,
      };
    }
    return {};
  }

  /// Message shown when the Edit button is disabled, or null when editing
  /// is allowed.
  static String? editBlockedReason(Reservation reservation) {
    switch (ReservationStatus.normalize(reservation.status)) {
      case ReservationStatus.completed:
        return 'Completed reservations can no longer be edited.';
      case ReservationStatus.cancelled:
        return 'Cancelled reservations cannot be edited. '
            'Restore it first.';
      default:
        return null;
    }
  }

  // ── Classifying an edit ────────────────────────────────────────────────

  /// Fields that differ between [original] and [draft].
  static Set<ReservationField> changedFields(
    Reservation original,
    ReservationDraft draft,
  ) {
    final changed = <ReservationField>{};
    if (draft.guestName != original.guestName) {
      changed.add(ReservationField.guestName);
    }
    if (draft.phone != original.phone) changed.add(ReservationField.phone);
    if (draft.email != original.email) changed.add(ReservationField.email);
    if (draft.guestCount != original.guestCount) {
      changed.add(ReservationField.guestCount);
    }
    if (draft.notes != original.notes) changed.add(ReservationField.notes);
    if (draft.unitId != original.unitId) changed.add(ReservationField.unit);
    if (draft.stayTypeId != original.stayTypeId) {
      changed.add(ReservationField.stayType);
    }
    if (!draft.startAt.isAtSameMomentAs(original.startAt) ||
        !draft.endAt.isAtSameMomentAs(original.endAt)) {
      changed.add(ReservationField.dates);
    }
    return changed;
  }

  /// Classifies an edit: what changed, which checks are needed, and
  /// whether the status / older-reservation rules allow it.
  static EditPlan planEdit(Reservation original, ReservationDraft draft) {
    final changed = changedFields(original, draft);
    final allowed = editableFields(original);

    String? error;
    if (editAccess(original) == EditAccess.none) {
      error = editBlockedReason(original);
    } else if (!allowed.containsAll(changed)) {
      error =
          'A checked-in reservation can only change guest details '
          'and notes.';
    } else {
      final movesBooking =
          changed.contains(ReservationField.unit) ||
          changed.contains(ReservationField.stayType) ||
          changed.contains(ReservationField.dates);
      // Older reservations have no stay type; a new schedule and price
      // can only be calculated after one is chosen.
      if (movesBooking && draft.stayTypeId.isEmpty) {
        error =
            'Choose a stay type before changing the unit or dates of '
            'this older reservation.';
      }
    }

    return EditPlan(changedFields: changed, error: error);
  }

  /// Capacity error for an edit, or null. Only checked when the guest
  /// count or the unit changed (see [EditPlan.needsCapacityCheck]).
  static String? capacityError(EditPlan plan, int guestCount, Unit? unit) {
    if (!plan.needsCapacityCheck) return null;
    return BookingLogic.validateGuestCount(guestCount, unit);
  }

  // ── Unit / stay type options ───────────────────────────────────────────

  /// Units offered when editing: active units plus the reservation's
  /// current unit even if it was deactivated since.
  static List<Unit> unitOptions(
    Iterable<Unit> units, {
    String currentUnitId = '',
  }) {
    return units
        .where((u) => u.isActive || (u.id.isNotEmpty && u.id == currentUnitId))
        .toList();
  }

  /// Stay types offered when editing: active ones plus the reservation's
  /// current stay type even if it was deactivated since.
  static List<StayType> stayTypeOptions(
    Iterable<StayType> stayTypes, {
    String currentStayTypeId = '',
  }) {
    return stayTypes
        .where(
          (s) => s.isActive || (s.id.isNotEmpty && s.id == currentStayTypeId),
        )
        .toList();
  }

  /// Error when the chosen unit or stay type is inactive and isn't the one
  /// the reservation already uses (new selections must be active).
  static String? selectionError({
    required Reservation original,
    Unit? unit,
    StayType? stayType,
  }) {
    if (unit != null && !unit.isActive && unit.id != original.unitId) {
      return '${unit.name} is inactive. Choose an active unit.';
    }
    if (stayType != null &&
        !stayType.isActive &&
        stayType.id != original.stayTypeId) {
      return '${stayType.name} is inactive. Choose an active stay type.';
    }
    return null;
  }

  // ── Update data ────────────────────────────────────────────────────────

  /// PocketBase update body for an allowed edit.
  ///
  /// * Only changed guest fields are sent.
  /// * When the booking moved ([EditPlan.needsRepricing]) the unit, stay
  ///   type, start/end (UTC) and every snapshot are sent; [unit],
  ///   [stayType] and [quote] are then required.
  /// * Otherwise start/end and the pricing snapshots are left out, so the
  ///   saved values stay exactly as they are.
  /// * `status` is never part of an edit.
  static Map<String, dynamic> buildUpdateBody({
    required EditPlan plan,
    required ReservationDraft draft,
    Unit? unit,
    StayType? stayType,
    PriceQuote? quote,
  }) {
    if (!plan.isAllowed) {
      throw ArgumentError('This edit is not allowed: ${plan.error}');
    }

    final body = <String, dynamic>{};
    final changed = plan.changedFields;
    if (changed.contains(ReservationField.guestName)) {
      body['guestName'] = draft.guestName;
    }
    if (changed.contains(ReservationField.phone)) body['phone'] = draft.phone;
    if (changed.contains(ReservationField.email)) body['email'] = draft.email;
    if (changed.contains(ReservationField.guestCount)) {
      body['guestCount'] = draft.guestCount;
    }
    if (changed.contains(ReservationField.notes)) body['notes'] = draft.notes;

    if (plan.needsRepricing) {
      if (unit == null || stayType == null || quote == null) {
        throw ArgumentError(
          'unit, stayType and quote are required when the booking moves.',
        );
      }
      body.addAll({
        'unit': unit.id,
        'stayType': stayType.id,
        'startAt': draft.startAt.toUtc().toIso8601String(),
        'endAt': draft.endAt.toUtc().toIso8601String(),
        'unitName': unit.name,
        'unitTypeName': unit.typeName,
        'stayTypeName': stayType.name,
        'rate': quote.rate,
        'rateBasis': quote.basis.value,
        'quantity': quote.quantity,
        'totalAmount': quote.total,
      });
    }
    return body;
  }
}
