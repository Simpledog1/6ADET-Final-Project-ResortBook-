// Location: lib/screens/add_reservation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/booking_logic.dart';
import '../logic/reservation_workflow.dart';
import '../models/rate.dart';
import '../models/reservation.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import '../models/unit_type.dart';
import '../services/config_service.dart';
import '../services/reservation_gateway.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/adaptive_form.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_inputs.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/desktop_page.dart';
import '../widgets/responsive.dart';
import 'quick_add_unit_form.dart';

/// Add Reservation, and Edit Reservation when [reservation] is given.
///
/// Both modes use the same form, validation and booking rules. In edit
/// mode the reservation is reloaded from PocketBase first; the page then
/// returns `true` after a successful save.
class AddReservationScreen extends StatefulWidget {
  /// The reservation to edit, or null to add a new one.
  final Reservation? reservation;

  /// PocketBase access; tests pass a fake.
  final ReservationGateway gateway;

  const AddReservationScreen({
    super.key,
    this.reservation,
    this.gateway = const ReservationGateway(),
  });

  @override
  State<AddReservationScreen> createState() => _AddReservationScreenState();
}

class _AddReservationScreenState extends State<AddReservationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _guestCountController = TextEditingController();
  final _notesController = TextEditingController();

  // Configuration loaded from PocketBase
  List<StayType> _stayTypes = [];
  List<Unit> _units = [];
  List<Rate> _rates = [];
  bool _isLoadingConfig = true;
  String? _loadError;

  // Selections
  StayType? _stayType;
  Unit? _unit;
  DateTime? _checkInDate; // date only
  DateTime? _checkOutDate; // date only, multi-night stay types

  /// Start time picked by staff, or null to use the stay type's default
  /// check-in time. The end time always follows the stay type's duration.
  TimeOfDay? _startTime;

  bool _submitted = false; // show inline errors after the first save attempt
  bool _isSubmitting = false;
  String? _conflictError;
  int _resetCount = 0; // forces the unit dropdown to rebuild after a save

  // ── Edit mode ──
  /// The reservation being edited, as freshly loaded from PocketBase.
  Reservation? _original;

  /// The form was filled from [_original] (only done once).
  bool _prefilled = false;

  /// The user picked another stay type or date. Until then the saved
  /// start/end times are kept exactly.
  bool _scheduleTouched = false;

  bool get _isEdit => widget.reservation != null;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _guestCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    setState(() {
      _isLoadingConfig = true;
      _loadError = null;
    });
    final gateway = widget.gateway;
    try {
      // Adding offers active items only. Editing also loads inactive ones,
      // so the reservation's own (possibly deactivated) unit and stay type
      // stay selectable; other inactive ones are filtered out below.
      final results = await Future.wait([
        gateway.getStayTypes(activeOnly: !_isEdit),
        gateway.getUnits(activeOnly: !_isEdit),
        gateway.getRates(),
      ]);
      final Reservation? fresh = _isEdit
          ? await gateway.getReservation(widget.reservation!.id)
          : null;
      if (!mounted) return;
      setState(() {
        var stayTypes = results[0] as List<StayType>;
        var units = results[1] as List<Unit>;
        if (fresh != null) {
          stayTypes = ReservationWorkflow.stayTypeOptions(
            stayTypes,
            currentStayTypeId: fresh.stayTypeId,
          );
          units = ReservationWorkflow.unitOptions(
            units,
            currentUnitId: fresh.unitId,
          );
          _original = fresh;
        }
        _stayTypes = stayTypes;
        _units = units;
        _rates = results[2] as List<Rate>;

        if (fresh != null && !_prefilled) {
          _prefillFrom(fresh);
        } else {
          // Re-select by id so the selections match the freshly loaded
          // objects. (A new reservation starts with the first stay type;
          // an older reservation being edited may have none.)
          _stayType =
              _stayTypes.where((s) => s.id == _stayType?.id).firstOrNull ??
              (_isEdit ? null : _stayTypes.firstOrNull);
          _unit = _units.where((u) => u.id == _unit?.id).firstOrNull;
        }

        // The status may have changed since Details was opened.
        if (fresh != null && !ReservationWorkflow.canEdit(fresh)) {
          _loadError =
              ReservationWorkflow.editBlockedReason(fresh) ??
              'This reservation can no longer be edited.';
        }
        _resetCount++;
        _isLoadingConfig = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingConfig = false;
        _loadError =
            'Could not load units and stay types. '
            '${ConfigService.friendlyError(e)}';
      });
    }
  }

  /// Fills the form with the reservation being edited.
  void _prefillFrom(Reservation r) {
    _nameController.text = r.guestName;
    _phoneController.text = r.phone;
    _emailController.text = r.email;
    _guestCountController.text = r.guestCount > 0 ? '${r.guestCount}' : '';
    _notesController.text = r.notes;
    _stayType = _stayTypes.where((s) => s.id == r.stayTypeId).firstOrNull;
    _unit = _units.where((u) => u.id == r.unitId).firstOrNull;
    _checkInDate = DateFormatUtil.dateOnly(r.startAt);
    _checkOutDate = DateFormatUtil.dateOnly(r.endAt);
    // Keep the booking's own start time if the dates are changed later.
    _startTime = TimeOfDay.fromDateTime(r.startAt.toLocal());
    _scheduleTouched = false;
    _prefilled = true;
  }

  // ── Derived values ─────────────────────────────────────────────────────

  /// True when the selected stay type needs a separate check-out date.
  bool get _needsCheckOutDate =>
      _stayType != null &&
      _stayType!.endsNextDay &&
      _stayType!.allowMultipleNights;

  /// The start time shown in the form: the picked one, or the selected
  /// stay type's default check-in time.
  TimeOfDay? get _effectiveStartTime {
    if (_startTime != null) return _startTime;
    final stayType = _stayType;
    if (stayType == null) return null;
    final c = stayType.checkIn;
    return TimeOfDay(hour: c.hour, minute: c.minute);
  }

  int get _nights => _needsCheckOutDate
      ? (_checkInDate != null && _checkOutDate != null
            ? BookingLogic.nightsBetween(_checkInDate!, _checkOutDate!)
            : 0)
      : 1;

  StayWindow? get _window {
    // Editing without touching the stay type / dates: keep the saved times
    // exactly (the stay type's times may have changed since booking).
    final original = _original;
    if (_isEdit && original != null && !_scheduleTouched) {
      return StayWindow(
        start: original.startAt,
        end: original.endAt,
        nights: BookingLogic.nightsBetween(original.startAt, original.endAt),
      );
    }
    if (_stayType == null || _checkInDate == null) return null;
    if (_needsCheckOutDate && _checkOutDate == null) return null;
    final start = _startTime;
    return BookingLogic.computeWindow(
      stayType: _stayType!,
      date: _checkInDate!,
      nights: _nights,
      startTime: start == null
          ? null
          : (hour: start.hour, minute: start.minute),
    );
  }

  Rate? get _rate {
    if (_unit == null || _stayType == null) return null;
    return BookingLogic.findRate(
      rates: _rates,
      unitTypeId: _unit!.unitTypeId,
      stayTypeId: _stayType!.id,
    );
  }

  PriceQuote? get _quote {
    final rate = _rate;
    final window = _window;
    if (rate == null || window == null || _stayType == null) return null;
    return BookingLogic.quote(rate: rate, stayType: _stayType!, window: window);
  }

  /// Unit + stay type are chosen but no rate is configured for them.
  bool get _isRateMissing =>
      _unit != null && _stayType != null && _rate == null;

  /// The values currently in the form, for [ReservationWorkflow.planEdit].
  ReservationDraft? get _draft {
    final original = _original;
    if (original == null) return null;
    final window = _window;
    return ReservationDraft(
      guestName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      // An empty field counts as 0 (invalid) unless the old record had no
      // guest count either (older reservations).
      guestCount: int.tryParse(_guestCountController.text) ?? 0,
      notes: _notesController.text.trim(),
      unitId: _unit?.id ?? original.unitId,
      stayTypeId: _stayType?.id ?? original.stayTypeId,
      startAt: window?.start ?? original.startAt,
      endAt: window?.end ?? original.endAt,
    );
  }

  /// What the edit changes (null when adding).
  EditPlan? get _editPlan {
    final original = _original;
    final draft = _draft;
    if (original == null || draft == null) return null;
    return ReservationWorkflow.planEdit(original, draft);
  }

  /// The unit, stay type or dates changed: availability and price are
  /// checked again. Always true when adding.
  bool get _needsRepricing => !_isEdit || (_editPlan?.needsRepricing ?? false);

  /// Missing rate only blocks saving when a price has to be calculated.
  bool get _rateBlocksSave => _isRateMissing && _needsRepricing;

  /// Checked In: unit, stay type and dates are read-only.
  bool get _scheduleLocked {
    final original = _original;
    return _isEdit &&
        original != null &&
        ReservationWorkflow.editAccess(original) == EditAccess.guestDetailsOnly;
  }

  String get _missingRateMessage {
    if (_unit != null && _unit!.unitTypeId.isEmpty) {
      return '${_unit!.name} has no unit type, so no rate can be found. '
          'Assign a unit type to this unit first.';
    }
    return 'No rate is set for ${_unit?.typeName ?? 'this unit type'} · '
        '${_stayType?.name ?? 'this stay type'}. '
        'Add a rate before saving this reservation.';
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _selectStayType(StayType stayType) {
    setState(() {
      if (_stayType?.id != stayType.id) {
        _scheduleTouched = true;
        // A new stay type starts at its own default check-in time.
        _startTime = null;
      }
      _stayType = stayType;
      _conflictError = null;
      // Keep the check-out date valid for multi-night stays.
      if (_needsCheckOutDate &&
          _checkInDate != null &&
          (_checkOutDate == null || !_checkOutDate!.isAfter(_checkInDate!))) {
        _checkOutDate = _checkInDate!.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final today = DateFormatUtil.dateOnly(DateTime.now());
    // When editing a booking that started in the past, its own date stays
    // selectable.
    final original = _original;
    final earliest =
        (_isEdit && original != null && original.startAt.isBefore(today))
        ? DateFormatUtil.dateOnly(original.startAt)
        : today;
    final DateTime first;
    final DateTime initial;
    if (isCheckIn) {
      first = earliest;
      initial = (_checkInDate != null && !_checkInDate!.isBefore(first))
          ? _checkInDate!
          : first;
    } else {
      first = (_checkInDate ?? earliest).add(const Duration(days: 1));
      initial = (_checkOutDate != null && _checkOutDate!.isAfter(first))
          ? _checkOutDate!
          : first;
    }

    // Check-in dates go up to a year ahead. Check-out may go beyond that
    // (a stay can start on the last allowed day), and the range must always
    // include the first and the currently selected date.
    var last = today.add(const Duration(days: 365));
    if (!isCheckIn) {
      final checkOutLimit = first.add(const Duration(days: 30));
      if (checkOutLimit.isAfter(last)) last = checkOutLimit;
    }
    if (last.isBefore(initial)) last = initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;

    setState(() {
      _scheduleTouched = true;
      if (isCheckIn) {
        _checkInDate = picked;
        // Auto-adjust checkout date if it's not after the new check-in date
        if (_needsCheckOutDate &&
            (_checkOutDate == null || !_checkOutDate!.isAfter(picked))) {
          _checkOutDate = picked.add(const Duration(days: 1));
        }
      } else {
        _checkOutDate = picked;
      }
      _conflictError = null; // Clear any previous conflict error
    });
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final initial = _effectiveStartTime ?? const TimeOfDay(hour: 14, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      _scheduleTouched = true;
      _startTime = picked;
      _conflictError = null;
    });
  }

  /// "Add new unit" in the Unit dropdown: the owner types a unit name,
  /// its type and capacity (and optionally the price for the chosen stay
  /// type). The new unit is saved to PocketBase and selected.
  Future<void> _openAddUnit() async {
    // Put the dropdown back on the current selection while the form is open.
    setState(() => _resetCount++);

    final List<UnitType> unitTypes;
    try {
      unitTypes = await widget.gateway.getUnitTypes();
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        'Could not load unit types. ${ConfigService.friendlyError(e)}',
      );
      return;
    }
    if (!mounted) return;

    final result = await showAdaptiveForm<QuickAddUnitResult>(
      context,
      title: 'Add New Unit',
      builder: (_) => QuickAddUnitForm(
        gateway: widget.gateway,
        unitTypes: unitTypes,
        rates: _rates,
        stayType: _stayType,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _units = [..._units, result.unit];
      final rate = result.rate;
      if (rate != null) {
        _rates = [
          ..._rates.where(
            (r) =>
                !(r.unitTypeId == rate.unitTypeId &&
                    r.stayTypeId == rate.stayTypeId),
          ),
          rate,
        ];
      }
      _unit = result.unit;
      _conflictError = null;
      _resetCount++;
    });
    _showMessage('${result.unit.name} added.');
  }

  /// First problem that prevents saving (besides form field errors).
  String? _blockingProblem() {
    if (_stayType == null) return 'Select a stay type.';
    if (_unit == null) return 'Select a unit.';
    if (_checkInDate == null) return 'Select a check-in date.';
    if (_needsCheckOutDate && _checkOutDate == null) {
      return 'Select a check-out date.';
    }
    if (_window == null) {
      return _needsCheckOutDate
          ? 'Check-out date must be after check-in date.'
          : '${_stayType!.name} has invalid check-in/check-out times.';
    }
    if (_isRateMissing) return _missingRateMessage;
    return null;
  }

  Future<void> _submitReservation() async {
    setState(() => _submitted = true);
    final formValid = _formKey.currentState!.validate();
    final problem = _blockingProblem();

    if (!formValid || problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(problem ?? 'Please fix the highlighted fields.'),
        ),
      );
      return;
    }

    final unit = _unit!;
    final stayType = _stayType!;
    final window = _window!;
    final quote = _quote!;

    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    try {
      // 1. Ask PocketBase for non-cancelled bookings of this unit that
      //    overlap the new window, then re-check them locally with the
      //    same rule: newStart < existingEnd && newEnd > existingStart.
      final candidates = await widget.gateway.findOverlapping(
        unitId: unit.id,
        start: window.start,
        end: window.end,
      );
      final conflicts = BookingLogic.findConflicts(
        unitId: unit.id,
        window: window,
        existing: candidates,
      );

      // 2. Block the write and show the conflict banner if anything overlaps
      if (conflicts.isNotEmpty) {
        final c = conflicts.first;
        if (!mounted) return;
        setState(() {
          _conflictError =
              '${unit.name} is already booked from '
              '${DateFormatUtil.shortWithTime(c.startAt)} to '
              '${DateFormatUtil.shortWithTime(c.endAt)}'
              '${c.guestName.isEmpty ? '' : ' (${c.guestName})'}.';
          _isSubmitting = false;
        });
        return;
      }

      // 3. No conflict -> save (UTC dates + name/price snapshots)
      await widget.gateway.createReservation(
        guestName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        guestCount: int.parse(_guestCountController.text),
        unit: unit,
        stayType: stayType,
        startAt: window.start,
        endAt: window.end,
        status: ReservationStatus.reserved,
        notes: _notesController.text.trim(),
        rate: quote.rate,
        rateBasis: quote.basis,
        quantity: quote.quantity,
        totalAmount: quote.total,
      );

      if (!mounted) return;

      // Reset the form on success (keep the selected stay type)
      for (final c in [
        _nameController,
        _phoneController,
        _emailController,
        _guestCountController,
        _notesController,
      ]) {
        c.clear();
      }
      setState(() {
        _unit = null;
        _checkInDate = null;
        _checkOutDate = null;
        _startTime = null;
        _submitted = false;
        _isSubmitting = false;
        _resetCount++;
      });
      // Text fields were cleared above; the unit dropdown is rebuilt through
      // its _resetCount key.

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reservation saved · ${CurrencyFormat.peso(quote.total)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save the reservation. '
            '${ConfigService.friendlyError(e)}',
          ),
        ),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Edit mode: saves only what changed (see [ReservationWorkflow]).
  ///
  /// * Guest details / notes: saved as they are.
  /// * Guest count: capacity is checked; the price stays the same.
  /// * Unit, stay type or dates: availability is checked again (ignoring
  ///   this reservation), the price is recalculated with the current rate
  ///   and every snapshot is replaced.
  Future<void> _saveChanges() async {
    final original = _original;
    if (original == null) return;

    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) {
      _showMessage('Please fix the highlighted fields.');
      return;
    }

    // Stay type or dates were changed but no valid time range results.
    if (_scheduleTouched && _window == null) {
      _showMessage(
        _stayType == null
            ? 'Choose a stay type before changing the dates of this older '
                  'reservation.'
            : (_blockingProblem() ?? 'Check the stay type and dates.'),
      );
      return;
    }

    final draft = _draft!;
    final plan = ReservationWorkflow.planEdit(original, draft);
    if (!plan.isAllowed) {
      _showMessage(plan.error!);
      return;
    }
    if (!plan.hasChanges) {
      _showMessage('Nothing to save: no changes were made.');
      return;
    }

    final selectionProblem = ReservationWorkflow.selectionError(
      original: original,
      unit: _unit,
      stayType: _stayType,
    );
    if (selectionProblem != null) {
      _showMessage(selectionProblem);
      return;
    }

    final capacityProblem = ReservationWorkflow.capacityError(
      plan,
      draft.guestCount,
      _unit,
    );
    if (capacityProblem != null) {
      _showMessage(capacityProblem);
      return;
    }

    final unit = _unit;
    final stayType = _stayType;
    final window = _window;
    PriceQuote? quote;
    if (plan.needsRepricing) {
      final String? problem;
      if (unit == null) {
        problem = 'Select a unit.';
      } else if (stayType == null) {
        problem = 'Select a stay type.';
      } else if (_rate == null) {
        problem = _missingRateMessage; // block: no partial update
      } else if (_quote == null || window == null) {
        problem = 'Check the stay type and dates.';
      } else {
        problem = null;
      }
      if (problem != null) {
        _showMessage(problem);
        return;
      }
      quote = _quote;
    }

    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    try {
      if (plan.needsAvailabilityCheck) {
        // Same two-step check as a new booking, ignoring this reservation.
        final candidates = await widget.gateway.findOverlapping(
          unitId: unit!.id,
          start: window!.start,
          end: window.end,
          excludeReservationId: original.id,
        );
        final conflicts = BookingLogic.findConflicts(
          unitId: unit.id,
          window: window,
          existing: candidates,
          excludeReservationId: original.id,
        );
        if (conflicts.isNotEmpty) {
          final c = conflicts.first;
          if (!mounted) return;
          setState(() {
            _conflictError =
                '${unit.name} is already booked from '
                '${DateFormatUtil.shortWithTime(c.startAt)} to '
                '${DateFormatUtil.shortWithTime(c.endAt)}'
                '${c.guestName.isEmpty ? '' : ' (${c.guestName})'}.';
            _isSubmitting = false;
          });
          return;
        }
      }

      final body = ReservationWorkflow.buildUpdateBody(
        plan: plan,
        draft: draft,
        unit: unit,
        stayType: stayType,
        quote: quote,
      );
      await widget.gateway.updateReservation(original.id, body);
      if (!mounted) return;

      _showMessage(
        quote == null
            ? 'Reservation updated.'
            : 'Reservation updated · ${CurrencyFormat.peso(quote.total)}',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage(
        'Could not save the changes. ${ConfigService.friendlyError(e)}',
      );
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────
  //
  // The phone and desktop layouts arrange the same field widgets below;
  // all state, validation and saving stay in this class.

  bool get _canSave =>
      !_isSubmitting &&
      _conflictError == null &&
      !_rateBlocksSave &&
      _loadError == null;

  /// Read-only look for the unit / stay type / date fields of a checked-in
  /// reservation.
  Widget _lockable(Widget child, String keyName) {
    if (!_scheduleLocked) return child;
    return IgnorePointer(
      key: ValueKey(keyName),
      child: Opacity(opacity: 0.55, child: child),
    );
  }

  /// Notes shown under "Stay Details" in edit mode, or null.
  Widget? _stayDetailsNote() {
    final original = _original;
    if (!_isEdit || original == null) return null;
    String? text;
    Key? key;
    if (_scheduleLocked) {
      text =
          "Unit, stay type and dates can't be changed while the guest is "
          'checked in.';
      key = const ValueKey('schedule-locked-note');
    } else if (original.isLegacy && _stayType == null) {
      text =
          'Older reservation: no stay type was saved (shown as Overnight). '
          'Choose one only if you change the unit or dates.';
    }
    if (text == null) return null;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _scheduleLocked ? Icons.lock_outline : Icons.info_outline,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppText.caption)),
        ],
      ),
    );
  }

  /// Price area: missing-rate warning, the new quote (with "Price will be
  /// recalculated" when editing), the saved price, or nothing yet.
  Widget? _priceSection({bool accent = false}) {
    if (_rateBlocksSave) return _rateBanner(accent: accent);
    final quote = _quote;
    final original = _original;
    if (!_isEdit) return quote == null ? null : _PriceSummary(quote: quote);
    if (original == null) return null;

    if (_needsRepricing) {
      if (quote == null) return null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PriceSummary(quote: quote),
          const SizedBox(height: 8),
          _PriceChangeNote(
            oldTotal: original.totalAmount,
            newTotal: quote.total,
          ),
        ],
      );
    }
    return _SavedPriceNote(total: original.totalAmount);
  }

  /// Cancel: back to the previous page, or — when Add Reservation was opened
  /// straight from the desktop sidebar — to the Dashboard.
  void _cancel() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      DesktopShellScope.navigate(context, ShellSection.dashboard);
    }
  }

  Widget _nameField() {
    return FieldLabel(
      text: 'Guest Name',
      child: TextFormField(
        controller: _nameController,
        style: AppText.body,
        textCapitalization: TextCapitalization.words,
        decoration: AppInputs.decoration(
          hint: 'Enter guest name',
          icon: Icons.person,
        ),
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Guest name is required.' : null,
      ),
    );
  }

  Widget _phoneField() {
    return FieldLabel(
      text: 'Contact Number',
      child: TextFormField(
        controller: _phoneController,
        style: AppText.body,
        keyboardType: TextInputType.phone,
        decoration: AppInputs.decoration(
          hint: '+63 9XX XXX XXXX',
          icon: Icons.phone,
        ),
      ),
    );
  }

  Widget _emailField() {
    return FieldLabel(
      text: 'Email',
      child: TextFormField(
        controller: _emailController,
        style: AppText.body,
        keyboardType: TextInputType.emailAddress,
        decoration: AppInputs.decoration(
          hint: 'guest@email.com',
          icon: Icons.email,
        ),
      ),
    );
  }

  /// Adds [delta] to the typed guest count (minimum 1). Typing still works;
  /// the same validator checks the result against the unit's capacity.
  void _stepGuestCount(int delta) {
    final current = int.tryParse(_guestCountController.text) ?? 0;
    var next = current + delta;
    if (next < 1) next = 1;
    _guestCountController.text = '$next';
    setState(() {}); // refresh the stepper buttons
  }

  /// Number of Guests. [stepper] adds − / + buttons (desktop).
  Widget _guestCountField({bool stepper = false}) {
    final current = int.tryParse(_guestCountController.text) ?? 0;
    final capacity = _unit?.capacity ?? 0;
    var decoration = AppInputs.decoration(
      hint: _unit != null && _unit!.capacity > 0
          ? 'Up to ${_unit!.capacity}'
          : 'e.g. 2',
      icon: stepper ? null : Icons.groups,
    );
    if (stepper) {
      decoration = decoration.copyWith(
        prefixIcon: IconButton(
          tooltip: 'Fewer guests',
          icon: const Icon(Icons.remove, size: 18),
          color: AppColors.textSecondary,
          onPressed: current > 1 ? () => _stepGuestCount(-1) : null,
        ),
        suffixIcon: IconButton(
          tooltip: 'More guests',
          icon: const Icon(Icons.add, size: 18),
          color: AppColors.primary,
          onPressed: capacity > 0 && current >= capacity
              ? null
              : () => _stepGuestCount(1),
        ),
      );
    }

    return FieldLabel(
      text: 'Number of Guests',
      child: TextFormField(
        controller: _guestCountController,
        style: AppText.body,
        textAlign: stepper ? TextAlign.center : TextAlign.start,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: decoration,
        // Rebuild so the stepper buttons enable / disable while typing.
        onChanged: stepper ? (_) => setState(() {}) : null,
        validator: (v) {
          // Editing: only checked when the guest count or unit changed, so
          // an old booking isn't blocked by a capacity lowered later.
          final plan = _editPlan;
          if (plan != null && !plan.needsCapacityCheck) return null;
          return BookingLogic.validateGuestCount(int.tryParse(v ?? ''), _unit);
        },
      ),
    );
  }

  Widget _stayTypeField() {
    return FieldLabel(
      text: 'Stay Type',
      child: _stayTypes.isEmpty
          ? const _EmptyHint(
              icon: Icons.schedule,
              text: 'No active stay types found.',
            )
          : _lockable(
              _StayTypeSelector(
                stayTypes: _stayTypes,
                selected: _stayType,
                onSelected: _selectStayType,
              ),
              'locked-stay-type',
            ),
    );
  }

  /// Last item of the Unit dropdown; opens [_openAddUnit] instead of being
  /// selected.
  static const Unit _addUnitOption = Unit(id: '__add_unit__', name: '');

  Widget _unitField() {
    return FieldLabel(
      text: 'Unit',
      child: _lockable(
        DropdownButtonFormField<Unit>(
          key: ValueKey('unit-$_resetCount'),
          decoration: AppInputs.decoration(
            hint: _units.isEmpty ? 'No units yet. Add one' : 'Select a unit',
            icon: Icons.meeting_room,
          ),
          style: AppText.body,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textSecondary,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          dropdownColor: AppColors.surface,
          initialValue: _unit,
          items: [
            ..._units.map((unit) {
              final capacity = unit.capacity > 0
                  ? ' · up to ${unit.capacity}'
                  : '';
              final inactive = unit.isActive ? '' : ' (inactive)';
              return DropdownMenuItem(
                value: unit,
                child: Text(
                  '${unit.displayLabel}$capacity$inactive',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            if (!_scheduleLocked)
              DropdownMenuItem(
                value: _addUnitOption,
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add new unit…',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: _scheduleLocked
              ? null
              : (val) {
                  if (val?.id == _addUnitOption.id) {
                    _openAddUnit();
                    return;
                  }
                  setState(() {
                    _unit = val;
                    _conflictError = null; // re-check on save
                  });
                },
          validator: (v) =>
              v == null || v.id == _addUnitOption.id ? 'Select a unit.' : null,
        ),
        'locked-unit',
      ),
    );
  }

  Widget _checkInField() {
    return FieldLabel(
      text: 'Check-in Date',
      child: _lockable(
        PickerField(
          value: _checkInDate == null
              ? null
              : DateFormatUtil.long(_checkInDate!),
          placeholder: 'Select check-in date',
          highlightError:
              _conflictError != null || (_submitted && _checkInDate == null),
          onTap: () => _selectDate(context, true),
        ),
        'locked-check-in',
      ),
    );
  }

  /// "2:00 PM" for a picked time (same style as the rest of the app).
  static String _clock(TimeOfDay t) => DateFormatUtil.timeOfDay(
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}',
  );

  Widget _startTimeField() {
    final start = _effectiveStartTime;
    final stayType = _stayType;
    final duration = stayType?.durationMinutes;
    return FieldLabel(
      text: 'Check-in Time',
      child: _lockable(
        PickerField(
          key: const ValueKey('start-time'),
          value: start == null
              ? null
              : '${_clock(start)}'
                    '${duration == null ? '' : ' · ${DateFormatUtil.duration(duration)}'}',
          placeholder: 'Select a stay type first',
          trailingIcon: Icons.access_time,
          highlightError: _conflictError != null,
          onTap: () {
            if (stayType != null) _selectStartTime(context);
          },
        ),
        'locked-start-time',
      ),
    );
  }

  Widget _checkOutField() {
    return FieldLabel(
      text: 'Check-out Date',
      child: _lockable(
        PickerField(
          value: _checkOutDate == null
              ? null
              : DateFormatUtil.long(_checkOutDate!),
          placeholder: 'Select check-out date',
          highlightError:
              _conflictError != null || (_submitted && _checkOutDate == null),
          onTap: () => _selectDate(context, false),
        ),
        'locked-check-out',
      ),
    );
  }

  Widget _notesField() {
    return TextFormField(
      controller: _notesController,
      style: AppText.body,
      minLines: 3,
      maxLines: 5,
      maxLength: 2000,
      textCapitalization: TextCapitalization.sentences,
      decoration: AppInputs.decoration(
        hint: 'Special requests, arrival details… (optional)',
      ),
    );
  }

  Widget _saveButton({ButtonStyle? style}) {
    return FilledButton.icon(
      style: style,
      onPressed: _canSave
          ? (_isEdit ? _saveChanges : _submitReservation)
          : null,
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save, size: 18),
      label: Text(_isEdit ? 'Save Changes' : 'Save Reservation'),
    );
  }

  Widget? _loadErrorBanner({bool accent = false}) {
    if (_loadError == null) return null;
    final original = _original;
    final editBlocked =
        original != null && !ReservationWorkflow.canEdit(original);
    return _NoticeBanner(
      title: editBlocked ? 'Editing not available' : 'Connection problem',
      message: _loadError!,
      actionLabel: editBlocked ? null : 'Retry',
      onAction: editBlocked ? null : _loadConfiguration,
      accent: accent,
    );
  }

  Widget? _conflictBanner({bool accent = false}) {
    if (_conflictError == null) return null;
    return _NoticeBanner(
      title: 'Date Conflict Detected',
      message: _conflictError!,
      accent: accent,
    );
  }

  Widget? _rateBanner({bool accent = false}) {
    if (!_rateBlocksSave) return null;
    return _NoticeBanner(
      title: 'No Rate Set',
      message: _missingRateMessage,
      accent: accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopShellScope.isInside(context)) return _buildDesktop(context);
    return _buildMobile(context);
  }

  // ── Phone / tablet (unchanged layout, centred on tablets) ─────────────

  Widget _buildMobile(BuildContext context) {
    final window = _window;
    final loadError = _loadErrorBanner();
    final conflict = _conflictBanner();
    final price = _priceSection();
    final stayNote = _stayDetailsNote();

    return Scaffold(
      appBar: AppHeader(
        title: _isEdit ? 'Edit Reservation' : 'Add Reservation',
      ),
      body: _isLoadingConfig
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContent(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  20,
                  AppSpacing.md,
                  AppSpacing.lg * 2,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loadError != null) ...[
                        loadError,
                        const SizedBox(height: 16),
                      ],

                      // ── Guest information ─────────────────────────────
                      const FormSectionHeader('Guest Information'),
                      const SizedBox(height: 12),
                      _nameField(),
                      const SizedBox(height: 12),
                      _phoneField(),
                      const SizedBox(height: 12),
                      _emailField(),
                      const SizedBox(height: 12),
                      _guestCountField(),

                      // ── Stay details ──────────────────────────────────
                      const FormSectionHeader('Stay Details', topPadding: 20),
                      ?stayNote,
                      const SizedBox(height: 12),
                      _stayTypeField(),
                      const SizedBox(height: 12),
                      _unitField(),

                      // ── Reservation dates ─────────────────────────────
                      const FormSectionHeader(
                        'Reservation Dates',
                        topPadding: 20,
                      ),
                      const SizedBox(height: 12),
                      _checkInField(),
                      const SizedBox(height: 12),
                      _startTimeField(),
                      if (_needsCheckOutDate) ...[
                        const SizedBox(height: 12),
                        _checkOutField(),
                      ],
                      if (window != null && _stayType != null) ...[
                        const SizedBox(height: 12),
                        _ScheduleSummary(window: window, stayType: _stayType!),
                      ],

                      // Conflict Alert Banner
                      if (conflict != null) ...[
                        const SizedBox(height: 12),
                        conflict,
                      ],

                      // ── Price ─────────────────────────────────────────
                      if (price != null) ...[const SizedBox(height: 12), price],

                      // ── Notes ─────────────────────────────────────────
                      const FormSectionHeader('Notes', topPadding: 20),
                      const SizedBox(height: 12),
                      _notesField(),

                      // ── Actions ───────────────────────────────────────
                      const SizedBox(height: 12),
                      _saveButton(),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── Desktop: one centred card (~880px) ─────────────────────────────────

  static const double _desktopWidth = 880;

  /// Two fields side by side (top-aligned so error text doesn't shift).
  Widget _pair(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final guest = widget.reservation?.guestName ?? '';
    return DesktopPage(
      title: _isEdit ? 'Edit Reservation' : 'Add Reservation',
      subtitle: _isEdit
          ? (guest.isEmpty
                ? 'Update this booking.'
                : 'Update the booking for $guest.')
          : 'Book a unit for a guest. The stay type sets the default '
                'start time and how long the stay lasts.',
      maxWidth: _desktopWidth,
      breadcrumbs: [
        BreadcrumbItem(
          'Reservations',
          onTap: () =>
              DesktopShellScope.navigate(context, ShellSection.reservations),
        ),
        if (_isEdit)
          BreadcrumbItem(
            'Reservation Details',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        BreadcrumbItem(_isEdit ? 'Edit Reservation' : 'Add Reservation'),
      ],
      children: [
        if (_isLoadingConfig)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg * 2),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          AppCard(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: _buildDesktopForm(context),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopForm(BuildContext context) {
    final window = _window;
    final loadError = _loadErrorBanner(accent: true);
    final conflict = _conflictBanner(accent: true);
    final stayNote = _stayDetailsNote();

    final Widget checkOut = _needsCheckOutDate
        ? _checkOutField()
        : FieldLabel(
            text: 'Check-out',
            child: _lockable(
              _EmptyHint(
                icon: Icons.logout,
                text: window != null
                    ? DateFormatUtil.shortWithTime(window.end)
                    : 'Calculated from the duration',
              ),
              'locked-check-out',
            ),
          );

    // Price column: rate warning, quote, saved price, or nothing yet.
    final price = _priceSection(accent: true);
    final hasSchedule = window != null && _stayType != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loadError != null) ...[
          loadError,
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Guest information ──
        const FormSectionHeader('Guest Information'),
        const SizedBox(height: AppSpacing.md),
        _pair(_nameField(), _phoneField()),
        const SizedBox(height: AppSpacing.md),
        _pair(_emailField(), _guestCountField(stepper: true)),

        // ── Stay details ──
        const FormSectionHeader('Stay Details', topPadding: AppSpacing.lg),
        ?stayNote,
        const SizedBox(height: AppSpacing.md),
        _pair(_stayTypeField(), _unitField()),

        // ── Reservation dates ──
        const FormSectionHeader('Reservation Dates', topPadding: AppSpacing.lg),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _checkInField()),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _startTimeField()),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: checkOut),
          ],
        ),

        // ── Summary: schedule and price side by side ──
        if (hasSchedule || price != null) ...[
          const SizedBox(height: AppSpacing.md),
          _pair(
            hasSchedule
                ? _ScheduleSummary(window: window, stayType: _stayType!)
                : const SizedBox.shrink(),
            price ?? const SizedBox.shrink(),
          ),
        ],
        if (conflict != null) ...[
          const SizedBox(height: AppSpacing.md),
          conflict,
        ],

        // ── Notes ──
        const FormSectionHeader('Notes', topPadding: AppSpacing.lg),
        const SizedBox(height: AppSpacing.md),
        _notesField(),

        // ── Actions ──
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              style: CompactButtons.outlined(),
              onPressed: _isSubmitting ? null : _cancel,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            _saveButton(style: CompactButtons.filled()),
          ],
        ),
      ],
    );
  }
}

/// Selectable stay type cards (loaded from PocketBase).
class _StayTypeSelector extends StatelessWidget {
  final List<StayType> stayTypes;
  final StayType? selected;
  final ValueChanged<StayType> onSelected;

  const _StayTypeSelector({
    required this.stayTypes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Up to 3 per row, equal width.
        final perRow = stayTypes.length < 3 ? stayTypes.length : 3;
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final st in stayTypes)
              SizedBox(
                width: width,
                child: _StayTypeOption(
                  stayType: st,
                  isSelected: selected?.id == st.id,
                  onTap: () => onSelected(st),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StayTypeOption extends StatelessWidget {
  final StayType stayType;
  final bool isSelected;
  final VoidCallback onTap;

  const _StayTypeOption({
    required this.stayType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    final fg = isSelected ? Colors.white : AppColors.textPrimary;
    final sub = isSelected
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.textSecondary;

    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                stayType.isActive
                    ? stayType.name
                    : '${stayType.name} (inactive)',
                textAlign: TextAlign.center,
                style: AppText.valueStrong.copyWith(color: fg, height: 1.3),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormatUtil.timeOfDay(stayType.checkInTime)} · '
                '${stayType.durationMinutes == null ? '—' : DateFormatUtil.duration(stayType.durationMinutes!)}',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: sub, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Light-blue summary of the computed check-in / check-out times.
class _ScheduleSummary extends StatelessWidget {
  final StayWindow window;
  final StayType stayType;

  const _ScheduleSummary({required this.window, required this.stayType});

  @override
  Widget build(BuildContext context) {
    final String length;
    if (window.nights == 0) {
      length = '${stayType.name} · same day';
    } else {
      length =
          '${stayType.name} · ${window.nights} '
          'night${window.nights == 1 ? '' : 's'}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.primaryTintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(length.toUpperCase(), style: AppText.overline),
          const SizedBox(height: 8),
          _row(Icons.login, 'Check-in', window.start),
          const SizedBox(height: 6),
          _row(Icons.logout, 'Check-out', window.end),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, DateTime value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        SizedBox(width: 72, child: Text(label, style: AppText.bodySecondary)),
        Expanded(
          child: Text(
            DateFormatUtil.shortWithTime(value),
            style: AppText.valueStrong.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

/// Rate × quantity = total (₱).
class _PriceSummary extends StatelessWidget {
  final PriceQuote quote;

  const _PriceSummary({required this.quote});

  @override
  Widget build(BuildContext context) {
    final perNight = quote.basis == PricingBasis.perNight;
    final unitLabel = perNight
        ? '${CurrencyFormat.peso(quote.rate)} / night × ${quote.quantity} '
              'night${quote.quantity == 1 ? '' : 's'}'
        : '${CurrencyFormat.peso(quote.rate)} per stay';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL', style: AppText.overline),
                const SizedBox(height: 2),
                Text(unitLabel, style: AppText.bodySecondary),
              ],
            ),
          ),
          Text(
            CurrencyFormat.peso(quote.total),
            style: AppText.cardTitle.copyWith(
              fontSize: 20,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit mode: "Price will be recalculated: ₱old → ₱new".
class _PriceChangeNote extends StatelessWidget {
  final double oldTotal;
  final double newTotal;

  const _PriceChangeNote({required this.oldTotal, required this.newTotal});

  @override
  Widget build(BuildContext context) {
    final oldText = oldTotal > 0 ? CurrencyFormat.peso(oldTotal) : 'no price';
    final newText = CurrencyFormat.peso(newTotal);
    final message = oldTotal == newTotal
        ? 'Price stays $newText after recalculation.'
        : 'Price will be recalculated: $oldText → $newText';
    return Container(
      key: const ValueKey('price-change-note'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.primaryTintBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_alt, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppText.body.copyWith(
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit mode without schedule changes: the saved price is kept.
class _SavedPriceNote extends StatelessWidget {
  final double total;

  const _SavedPriceNote({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SAVED TOTAL', style: AppText.overline),
                SizedBox(height: 2),
                Text(
                  'Kept unless the unit, stay type or dates change.',
                  style: AppText.bodySecondary,
                ),
              ],
            ),
          ),
          Text(
            total > 0 ? CurrencyFormat.peso(total) : '—',
            style: AppText.cardTitle.copyWith(
              fontSize: 20,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey placeholder shown when a list from PocketBase is empty.
class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.buttonHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Orange notice banner from the Figma design ("Date Conflict Detected").
///
/// [accent] (desktop) uses the Figma orange left border instead of the
/// full outline.
class _NoticeBanner extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool accent;

  const _NoticeBanner({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: accent
          ? const BoxDecoration(
              color: AppColors.warningTint,
              border: Border(
                left: BorderSide(color: AppColors.warning, width: 4),
              ),
            )
          : BoxDecoration(
              color: AppColors.warningTint,
              borderRadius: radius,
              border: Border.all(color: AppColors.warningBorder),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.valueStrong.copyWith(
                    fontSize: 13,
                    color: AppColors.warningText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppText.body.copyWith(
                    fontSize: 13,
                    height: 1.375,
                    color: AppColors.warningText,
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.warningText,
                    ),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!accent) return content;
    return ClipRRect(borderRadius: radius, child: content);
  }
}
