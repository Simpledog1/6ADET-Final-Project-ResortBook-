import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/config_rules.dart';
import '../../models/stay_type.dart';
import '../../services/config_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_inputs.dart';
import 'manage_common.dart';

/// Readable times for a stay type, e.g. "2:00 PM → 12:00 PM next day".
String stayTimesLabel(String checkIn, String checkOut, bool endsNextDay) {
  return '${DateFormatUtil.timeOfDay(checkIn)} → '
      '${DateFormatUtil.timeOfDay(checkOut)}'
      '${endsNextDay ? ' next day' : ''}';
}

/// Create / edit form for a stay type. Pops `true` after a successful save.
class StayTypeForm extends StatefulWidget {
  /// Null when creating a new stay type.
  final StayType? existing;

  /// Names of the OTHER stay types (for the duplicate-name check).
  final List<String> otherNames;

  /// True when [existing] is the only active stay type.
  final bool isLastActive;

  /// Reservations that already used [existing].
  final int reservationCount;

  const StayTypeForm({
    super.key,
    this.existing,
    required this.otherNames,
    this.isLastActive = false,
    this.reservationCount = 0,
  });

  @override
  State<StayTypeForm> createState() => _StayTypeFormState();
}

class _StayTypeFormState extends State<StayTypeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _sortOrder;
  late String _checkInTime; // "HH:mm" or '' when not chosen yet
  late String _checkOutTime;
  late bool _endsNextDay;
  late bool _allowMultipleNights;
  late PricingBasis _pricingBasis;
  late bool _isActive;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final st = widget.existing;
    _name = TextEditingController(text: st?.name ?? '');
    _description = TextEditingController(text: st?.description ?? '');
    _sortOrder = TextEditingController(
      text: st != null && st.sortOrder != 0 ? '${st.sortOrder}' : '',
    );
    _checkInTime = st?.checkInTime ?? '';
    _checkOutTime = st?.checkOutTime ?? '';
    _endsNextDay = st?.endsNextDay ?? false;
    _allowMultipleNights = st?.allowMultipleNights ?? false;
    _pricingBasis = st?.pricingBasis ?? PricingBasis.perStay;
    _isActive = st?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final current = isCheckIn ? _checkInTime : _checkOutTime;
    var initial = isCheckIn
        ? const TimeOfDay(hour: 14, minute: 0)
        : const TimeOfDay(hour: 12, minute: 0);
    if (ConfigRules.isValidTime(current)) {
      final minutes = ConfigRules.minutesOf(current);
      initial = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    }

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isCheckIn) {
        _checkInTime = value;
      } else {
        _checkOutTime = value;
      }
      _error = null;
    });
  }

  String? get _timesProblem => ConfigRules.validateStayTimes(
    checkInTime: _checkInTime,
    checkOutTime: _checkOutTime,
    endsNextDay: _endsNextDay,
    allowMultipleNights: _allowMultipleNights,
    pricingBasis: _pricingBasis,
  );

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    final timesProblem = _timesProblem;
    if (!formOk || timesProblem != null) {
      setState(() => _error = timesProblem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final stayType = StayType(
      id: widget.existing?.id ?? '',
      name: ConfigRules.normalizeName(_name.text),
      description: _description.text.trim(),
      checkInTime: _checkInTime,
      checkOutTime: _checkOutTime,
      endsNextDay: _endsNextDay,
      allowMultipleNights: _allowMultipleNights,
      pricingBasis: _pricingBasis,
      isActive: _isActive,
      sortOrder: ConfigRules.parseSortOrder(_sortOrder.text),
    );

    try {
      if (widget.existing == null) {
        await ConfigService.createStayType(stayType);
      } else {
        await ConfigService.updateStayType(stayType);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ConfigService.friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timesChosen =
        ConfigRules.isValidTime(_checkInTime) &&
        ConfigRules.isValidTime(_checkOutTime);
    final deactivatingLast =
        widget.existing != null && widget.isLastActive && !_isActive;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.existing != null && widget.reservationCount > 0) ...[
            const FormMessage(
              'Changes apply to new reservations only. Existing reservations '
              'keep their saved times, stay type name and price.',
              isError: false,
            ),
            const SizedBox(height: 12),
          ],
          FieldLabel(
            text: 'Name',
            child: TextFormField(
              controller: _name,
              style: AppText.body,
              textCapitalization: TextCapitalization.words,
              decoration: AppInputs.decoration(
                hint: 'e.g. Overnight, Day Tour, Half Day',
                icon: Icons.schedule,
              ),
              validator: (v) => ConfigRules.validateName(
                v,
                existingNames: widget.otherNames,
                itemLabel: 'stay type',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel(
            text: 'Description (optional)',
            child: TextFormField(
              controller: _description,
              style: AppText.body,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: AppInputs.decoration(hint: 'Shown to staff only'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FieldLabel(
                  text: 'Check-in time',
                  child: PickerField(
                    value: ConfigRules.isValidTime(_checkInTime)
                        ? DateFormatUtil.timeOfDay(_checkInTime)
                        : null,
                    placeholder: 'Select',
                    trailingIcon: Icons.access_time,
                    onTap: () => _pickTime(true),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FieldLabel(
                  text: 'Check-out time',
                  child: PickerField(
                    value: ConfigRules.isValidTime(_checkOutTime)
                        ? DateFormatUtil.timeOfDay(_checkOutTime)
                        : null,
                    placeholder: 'Select',
                    trailingIcon: Icons.access_time,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ManageSwitchRow(
            label: 'Ends next day',
            description: 'Check-out happens on the day after check-in.',
            value: _endsNextDay,
            onChanged: _saving
                ? null
                : (v) => setState(() {
                    _endsNextDay = v;
                    if (!v) _allowMultipleNights = false;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 8),
          ManageSwitchRow(
            label: 'Allow multiple nights',
            description: _endsNextDay
                ? 'Guests choose a check-out date (e.g. Overnight).'
                : 'Available when "Ends next day" is on.',
            value: _allowMultipleNights,
            onChanged: (_saving || !_endsNextDay)
                ? null
                : (v) => setState(() {
                    _allowMultipleNights = v;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 12),
          FieldLabel(
            text: 'Pricing basis',
            child: Row(
              children: [
                Expanded(
                  child: _BasisOption(
                    label: 'Per stay',
                    caption: 'Rate charged once',
                    selected: _pricingBasis == PricingBasis.perStay,
                    onTap: () => setState(() {
                      _pricingBasis = PricingBasis.perStay;
                      _error = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BasisOption(
                    label: 'Per night',
                    caption: 'Rate × nights',
                    selected: _pricingBasis == PricingBasis.perNight,
                    onTap: () => setState(() {
                      _pricingBasis = PricingBasis.perNight;
                      _error = null;
                    }),
                  ),
                ),
              ],
            ),
          ),
          if (timesChosen) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.primaryTintBorder),
              ),
              child: Text(
                '${stayTimesLabel(_checkInTime, _checkOutTime, _endsNextDay)}'
                ' · ${_pricingBasis == PricingBasis.perNight ? 'priced per night' : 'priced per stay'}'
                '${_allowMultipleNights ? ' · multiple nights' : ''}',
                style: AppText.valueStrong.copyWith(color: AppColors.primary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FieldLabel(
            text: 'Sort order',
            child: TextFormField(
              controller: _sortOrder,
              style: AppText.body,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: AppInputs.decoration(hint: '0', icon: Icons.sort),
              validator: ConfigRules.validateSortOrder,
            ),
          ),
          const SizedBox(height: 12),
          ManageSwitchRow(
            label: 'Active',
            description:
                'Inactive stay types aren’t offered for new reservations.',
            value: _isActive,
            onChanged: _saving ? null : (v) => setState(() => _isActive = v),
          ),
          if (deactivatingLast) ...[
            const SizedBox(height: 8),
            const FormMessage(
              'This is the last active stay type. New reservations cannot be '
              'created until another stay type is active.',
              isError: false,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            FormMessage(_error!),
          ],
          const SizedBox(height: 20),
          FormButtons(saving: _saving, onSave: _save),
        ],
      ),
    );
  }
}

/// One of the two pricing basis choices.
class _BasisOption extends StatelessWidget {
  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  const _BasisOption({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppText.valueStrong.copyWith(
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                caption,
                style: AppText.caption.copyWith(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
