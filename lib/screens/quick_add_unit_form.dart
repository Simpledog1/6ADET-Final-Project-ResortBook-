import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/booking_logic.dart';
import '../logic/config_rules.dart';
import '../models/rate.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import '../models/unit_type.dart';
import '../services/config_service.dart';
import '../services/reservation_gateway.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_inputs.dart';
import 'manage/manage_common.dart';

/// What "Add new unit" saved: the unit (with its type) and, when a price
/// was entered, the rate for the selected stay type.
class QuickAddUnitResult {
  final Unit unit;
  final Rate? rate;

  const QuickAddUnitResult({required this.unit, this.rate});
}

/// Small form opened from the Unit field of Add / Edit Reservation.
///
/// The owner types the unit's name, its type and its capacity. The type is
/// typed too: an existing type is reused (tap a suggestion or type its
/// name), any other name creates a new unit type. Everything is saved to
/// PocketBase exactly like Manage Resort would, so the unit also shows up
/// there. Pops a [QuickAddUnitResult] after a successful save.
class QuickAddUnitForm extends StatefulWidget {
  final ReservationGateway gateway;

  /// All unit types (active and inactive), for suggestions and matching.
  final List<UnitType> unitTypes;

  /// The stay type chosen in the reservation, so a missing rate can be
  /// entered here. Null when none is chosen yet.
  final StayType? stayType;

  /// Current rates (to know whether the chosen type already has one).
  final List<Rate> rates;

  const QuickAddUnitForm({
    super.key,
    required this.gateway,
    required this.unitTypes,
    required this.rates,
    this.stayType,
  });

  @override
  State<QuickAddUnitForm> createState() => _QuickAddUnitFormState();
}

class _QuickAddUnitFormState extends State<QuickAddUnitForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _typeName = TextEditingController();
  final _capacity = TextEditingController();
  final _price = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _typeName.dispose();
    _capacity.dispose();
    _price.dispose();
    super.dispose();
  }

  List<UnitType> get _activeTypes =>
      widget.unitTypes.where((t) => t.isActive).toList();

  /// The existing unit type whose name matches what was typed, or null
  /// (then a new type is created).
  UnitType? _matchingType(Iterable<UnitType> types) {
    final typed = ConfigRules.normalizeName(_typeName.text).toLowerCase();
    if (typed.isEmpty) return null;
    for (final t in types) {
      if (ConfigRules.normalizeName(t.name).toLowerCase() == typed) return t;
    }
    return null;
  }

  /// A price can be entered when a stay type is chosen and the unit type
  /// (new, or existing without a rate for that stay type) has no rate.
  bool get _canEnterRate {
    final stayType = widget.stayType;
    if (stayType == null) return false;
    if (ConfigRules.normalizeName(_typeName.text).isEmpty) return false;
    final match = _matchingType(widget.unitTypes);
    if (match == null) return true;
    return BookingLogic.findRate(
          rates: widget.rates,
          unitTypeId: match.id,
          stayTypeId: stayType.id,
        ) ==
        null;
  }

  void _chooseType(UnitType type) {
    setState(() {
      _typeName.text = type.name;
      if (_capacity.text.trim().isEmpty && type.defaultCapacity > 0) {
        _capacity.text = '${type.defaultCapacity}';
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final gateway = widget.gateway;
    try {
      // Check names against the latest data right before saving.
      final latestUnits = await gateway.getUnits();
      final latestTypes = await gateway.getUnitTypes();

      final nameError = ConfigRules.validateName(
        _name.text,
        existingNames: latestUnits.map((u) => u.name),
        itemLabel: 'unit',
      );
      if (nameError != null) {
        setState(() {
          _saving = false;
          _error = nameError;
        });
        return;
      }

      var type = _matchingType(latestTypes);
      if (type != null && !type.isActive) {
        setState(() {
          _saving = false;
          _error =
              '"${type!.name}" is an inactive unit type. Turn it back on in '
              'Manage Resort → Unit Types, or type another name.';
        });
        return;
      }

      final capacity = int.parse(_capacity.text.trim());
      type ??= await gateway.createUnitType(
        UnitType(
          id: '',
          name: ConfigRules.normalizeName(_typeName.text),
          defaultCapacity: capacity,
        ),
      );

      final unit = await gateway.createUnit(
        Unit(
          id: '',
          name: ConfigRules.normalizeName(_name.text),
          unitTypeId: type.id,
          capacity: capacity,
        ),
      );

      Rate? rate;
      final stayType = widget.stayType;
      if (stayType != null && _price.text.trim().isNotEmpty) {
        rate = await gateway.saveRate(
          unitTypeId: type.id,
          stayTypeId: stayType.id,
          price: ConfigRules.parsePrice(_price.text),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        QuickAddUnitResult(
          // Make sure the unit carries its type name for the dropdown.
          unit: unit.unitType != null
              ? unit
              : Unit(
                  id: unit.id,
                  name: unit.name,
                  unitTypeId: unit.unitTypeId,
                  unitType: type,
                  capacity: unit.capacity,
                  isActive: unit.isActive,
                  sortOrder: unit.sortOrder,
                ),
          rate: rate,
        ),
      );
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
    final typed = ConfigRules.normalizeName(_typeName.text);
    final match = _matchingType(widget.unitTypes);
    final stayType = widget.stayType;
    final perNight = stayType?.pricingBasis == PricingBasis.perNight;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(
            text: 'Unit name',
            child: TextFormField(
              key: const ValueKey('quick-unit-name'),
              controller: _name,
              style: AppText.body,
              textCapitalization: TextCapitalization.words,
              decoration: AppInputs.decoration(
                hint: 'e.g. Cottage 5, Function Hall, Room 101',
                icon: Icons.meeting_room,
              ),
              validator: (v) => ConfigRules.normalizeName(v ?? '').isEmpty
                  ? 'Name is required.'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel(
            text: 'Unit type',
            child: TextFormField(
              key: const ValueKey('quick-unit-type'),
              controller: _typeName,
              style: AppText.body,
              textCapitalization: TextCapitalization.words,
              decoration: AppInputs.decoration(
                hint: 'Type a new type or pick one below',
                icon: Icons.category,
              ),
              onChanged: (_) => setState(() => _error = null),
              validator: (v) => ConfigRules.normalizeName(v ?? '').isEmpty
                  ? 'Unit type is required.'
                  : null,
            ),
          ),
          if (_activeTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _activeTypes)
                  ChoiceChip(
                    label: Text(t.name),
                    selected: match?.id == t.id,
                    onSelected: _saving ? null : (_) => _chooseType(t),
                  ),
              ],
            ),
          ],
          if (typed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              match == null
                  ? 'New unit type "$typed" will be created.'
                  : 'Uses the existing unit type "${match.name}".',
              key: const ValueKey('quick-type-note'),
              style: AppText.caption,
            ),
          ],
          const SizedBox(height: 12),
          FieldLabel(
            // Keyed so the field keeps its state (and focus) when the note
            // above or the price field below appears or disappears.
            key: const ValueKey('quick-capacity-field'),
            text: 'Capacity',
            child: TextFormField(
              key: const ValueKey('quick-unit-capacity'),
              controller: _capacity,
              style: AppText.body,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: AppInputs.decoration(
                hint: 'Guests',
                icon: Icons.groups,
              ),
              validator: ConfigRules.validateCapacity,
            ),
          ),
          if (_canEnterRate) ...[
            const SizedBox(height: 12),
            FieldLabel(
              text:
                  '${stayType!.name} price '
                  '${perNight ? 'per night' : 'per stay'} (₱, optional)',
              child: TextFormField(
                key: const ValueKey('quick-unit-price'),
                controller: _price,
                style: AppText.body,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: AppInputs.decoration(
                  hint: 'e.g. 2500',
                  icon: Icons.payments_outlined,
                ).copyWith(prefixText: '₱ '),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? null
                    : ConfigRules.validatePrice(v),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Without a price this reservation can’t be saved until a rate '
              'is added in Manage Resort → Rates.',
              style: AppText.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            FormMessage(_error!),
          ],
          const SizedBox(height: 20),
          FormButtons(saving: _saving, onSave: _save, saveLabel: 'Add Unit'),
        ],
      ),
    );
  }
}
