// Location: lib/screens/add_reservation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/booking_logic.dart';
import '../models/rate.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import '../services/config_service.dart';
import '../services/pocketbase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_inputs.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/desktop_page.dart';
import '../widgets/responsive.dart';

class AddReservationScreen extends StatefulWidget {
  const AddReservationScreen({super.key});

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

  bool _submitted = false; // show inline errors after the first save attempt
  bool _isSubmitting = false;
  String? _conflictError;
  int _resetCount = 0; // forces the unit dropdown to rebuild after a save

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
    try {
      final results = await Future.wait([
        ConfigService.getStayTypes(activeOnly: true),
        ConfigService.getUnits(activeOnly: true),
        ConfigService.getRates(),
      ]);
      if (!mounted) return;
      setState(() {
        _stayTypes = results[0] as List<StayType>;
        _units = results[1] as List<Unit>;
        _rates = results[2] as List<Rate>;
        // Re-select by id so the selections match the freshly loaded objects.
        _stayType =
            _stayTypes.where((s) => s.id == _stayType?.id).firstOrNull ??
            _stayTypes.firstOrNull;
        _unit = _units.where((u) => u.id == _unit?.id).firstOrNull;
        _resetCount++;
        _isLoadingConfig = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingConfig = false;
        _loadError = 'Could not load units and stay types: $e';
      });
    }
  }

  // ── Derived values ─────────────────────────────────────────────────────

  /// True when the selected stay type needs a separate check-out date.
  bool get _needsCheckOutDate =>
      _stayType != null &&
      _stayType!.endsNextDay &&
      _stayType!.allowMultipleNights;

  int get _nights => _needsCheckOutDate
      ? (_checkInDate != null && _checkOutDate != null
            ? BookingLogic.nightsBetween(_checkInDate!, _checkOutDate!)
            : 0)
      : 1;

  StayWindow? get _window {
    if (_stayType == null || _checkInDate == null) return null;
    if (_needsCheckOutDate && _checkOutDate == null) return null;
    return BookingLogic.computeWindow(
      stayType: _stayType!,
      date: _checkInDate!,
      nights: _nights,
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
    final DateTime first;
    final DateTime initial;
    if (isCheckIn) {
      first = today;
      initial = _checkInDate ?? today;
    } else {
      first = (_checkInDate ?? today).add(const Duration(days: 1));
      initial = (_checkOutDate != null && _checkOutDate!.isAfter(first))
          ? _checkOutDate!
          : first;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
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
      final candidates = await PocketBaseService.findOverlappingReservations(
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
      await PocketBaseService.createReservation(
        guestName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        guestCount: int.parse(_guestCountController.text),
        unit: unit,
        stayType: stayType,
        startAt: window.start,
        endAt: window.end,
        status: 'Reserved',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving reservation: $e')));
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────
  //
  // The phone and desktop layouts arrange the same field widgets below;
  // all state, validation and saving stay in this class.

  bool get _canSave =>
      !_isSubmitting &&
      _conflictError == null &&
      !_isRateMissing &&
      _loadError == null;

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
        validator: (v) =>
            BookingLogic.validateGuestCount(int.tryParse(v ?? ''), _unit),
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
          : _StayTypeSelector(
              stayTypes: _stayTypes,
              selected: _stayType,
              onSelected: _selectStayType,
            ),
    );
  }

  Widget _unitField() {
    return FieldLabel(
      text: 'Unit',
      child: _units.isEmpty
          ? const _EmptyHint(
              icon: Icons.meeting_room,
              text: 'No active units found.',
            )
          : DropdownButtonFormField<Unit>(
              key: ValueKey('unit-$_resetCount'),
              decoration: AppInputs.decoration(
                hint: 'Select a unit',
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
              items: _units.map((unit) {
                final capacity = unit.capacity > 0
                    ? ' · up to ${unit.capacity}'
                    : '';
                return DropdownMenuItem(
                  value: unit,
                  child: Text(
                    '${unit.displayLabel}$capacity',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() {
                _unit = val;
                _conflictError = null; // re-check on save
              }),
              validator: (v) => v == null ? 'Select a unit.' : null,
            ),
    );
  }

  Widget _checkInField() {
    return FieldLabel(
      text: 'Check-in Date',
      child: PickerField(
        value: _checkInDate == null ? null : DateFormatUtil.long(_checkInDate!),
        placeholder: 'Select check-in date',
        highlightError:
            _conflictError != null || (_submitted && _checkInDate == null),
        onTap: () => _selectDate(context, true),
      ),
    );
  }

  Widget _checkOutField() {
    return FieldLabel(
      text: 'Check-out Date',
      child: PickerField(
        value: _checkOutDate == null
            ? null
            : DateFormatUtil.long(_checkOutDate!),
        placeholder: 'Select check-out date',
        highlightError:
            _conflictError != null || (_submitted && _checkOutDate == null),
        onTap: () => _selectDate(context, false),
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
      onPressed: _canSave ? _submitReservation : null,
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
      label: const Text('Save Reservation'),
    );
  }

  Widget? _loadErrorBanner({bool accent = false}) {
    if (_loadError == null) return null;
    return _NoticeBanner(
      title: 'Connection problem',
      message: _loadError!,
      actionLabel: 'Retry',
      onAction: _loadConfiguration,
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
    if (!_isRateMissing) return null;
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
    final quote = _quote;
    final loadError = _loadErrorBanner();
    final conflict = _conflictBanner();
    final rateBanner = _rateBanner();

    return Scaffold(
      appBar: const AppHeader(title: 'Add Reservation'),
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
                      if (_needsCheckOutDate) ...[
                        const SizedBox(height: 12),
                        _checkOutField(),
                      ],
                      if (window != null) ...[
                        const SizedBox(height: 12),
                        _ScheduleSummary(window: window, stayType: _stayType!),
                      ],

                      // Conflict Alert Banner
                      if (conflict != null) ...[
                        const SizedBox(height: 12),
                        conflict,
                      ],

                      // ── Price ─────────────────────────────────────────
                      if (rateBanner != null) ...[
                        const SizedBox(height: 12),
                        rateBanner,
                      ] else if (quote != null) ...[
                        const SizedBox(height: 12),
                        _PriceSummary(quote: quote),
                      ],

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
    return DesktopPage(
      title: 'Add Reservation',
      subtitle: 'Book a unit for a guest. Times come from the stay type.',
      maxWidth: _desktopWidth,
      breadcrumbs: [
        BreadcrumbItem(
          'Reservations',
          onTap: () =>
              DesktopShellScope.navigate(context, ShellSection.reservations),
        ),
        const BreadcrumbItem('Add Reservation'),
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
    final quote = _quote;
    final loadError = _loadErrorBanner(accent: true);
    final conflict = _conflictBanner(accent: true);
    final rateBanner = _rateBanner(accent: true);

    final Widget checkOut = _needsCheckOutDate
        ? _checkOutField()
        : FieldLabel(
            text: 'Check-out',
            child: _EmptyHint(
              icon: Icons.logout,
              text: window != null
                  ? DateFormatUtil.shortWithTime(window.end)
                  : 'Set by the stay type',
            ),
          );

    // Price column: rate warning, quote, or nothing yet.
    final Widget? price =
        rateBanner ?? (quote != null ? _PriceSummary(quote: quote) : null);

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
        const SizedBox(height: AppSpacing.md),
        _pair(_stayTypeField(), _unitField()),

        // ── Reservation dates ──
        const FormSectionHeader('Reservation Dates', topPadding: AppSpacing.lg),
        const SizedBox(height: AppSpacing.md),
        _pair(_checkInField(), checkOut),

        // ── Summary: schedule and price side by side ──
        if (window != null || price != null) ...[
          const SizedBox(height: AppSpacing.md),
          _pair(
            window != null
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
                stayType.name,
                textAlign: TextAlign.center,
                style: AppText.valueStrong.copyWith(color: fg, height: 1.3),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormatUtil.timeOfDay(stayType.checkInTime)} – '
                '${DateFormatUtil.timeOfDay(stayType.checkOutTime)}',
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
