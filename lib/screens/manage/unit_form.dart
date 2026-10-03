import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/config_rules.dart';
import '../../models/unit.dart';
import '../../models/unit_type.dart';
import '../../services/config_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_inputs.dart';
import 'manage_common.dart';

/// Create / edit form for a unit. Pops `true` after a successful save.
///
/// `cleaningStatus` is legacy data and is intentionally not shown; when
/// editing, the existing value is passed through unchanged.
class UnitForm extends StatefulWidget {
  /// Null when creating a new unit.
  final Unit? existing;

  /// All unit types (active and inactive).
  final List<UnitType> unitTypes;

  /// Largest guest count among this unit's upcoming reservations (0 if none).
  final int maxUpcomingGuests;

  const UnitForm({
    super.key,
    this.existing,
    required this.unitTypes,
    this.maxUpcomingGuests = 0,
  });

  @override
  State<UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends State<UnitForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _capacity;
  late final TextEditingController _sortOrder;
  String? _unitTypeId;
  late bool _isActive;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _name = TextEditingController(text: u?.name ?? '');
    _capacity = TextEditingController(
      text: u != null && u.capacity > 0 ? '${u.capacity}' : '',
    );
    _sortOrder = TextEditingController(
      text: u != null && u.sortOrder != 0 ? '${u.sortOrder}' : '',
    );
    _unitTypeId = (u != null && u.unitTypeId.isNotEmpty) ? u.unitTypeId : null;
    _isActive = u?.isActive ?? true;
    _capacity.addListener(_refresh);
  }

  @override
  void dispose() {
    _capacity.removeListener(_refresh);
    _name.dispose();
    _capacity.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Active types, plus the unit's current type even if it is inactive.
  List<UnitType> get _selectableTypes => widget.unitTypes
      .where((t) => t.isActive || t.id == widget.existing?.unitTypeId)
      .toList();

  void _onTypeChanged(String? typeId) {
    setState(() => _unitTypeId = typeId);
    // Pre-fill capacity from the type's default (the user can override it).
    // The capacity listener rebuilds the form after the text changes.
    for (final t in widget.unitTypes) {
      if (t.id == typeId && t.defaultCapacity > 0) {
        _capacity.text = '${t.defaultCapacity}';
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_unitTypeId == null || _unitTypeId!.isEmpty) {
      setState(() => _error = 'Unit type is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Unit names aren't unique in the database, so re-check against the
      // latest list right before saving.
      final latest = await ConfigService.getUnits();
      final otherNames = latest
          .where((u) => u.id != widget.existing?.id)
          .map((u) => u.name);
      final nameError = ConfigRules.validateName(
        _name.text,
        existingNames: otherNames,
        itemLabel: 'unit',
      );
      if (nameError != null) {
        setState(() {
          _saving = false;
          _error = nameError;
        });
        return;
      }

      final unit = Unit(
        id: widget.existing?.id ?? '',
        name: ConfigRules.normalizeName(_name.text),
        unitTypeId: _unitTypeId ?? '',
        capacity: int.parse(_capacity.text.trim()),
        isActive: _isActive,
        sortOrder: ConfigRules.parseSortOrder(_sortOrder.text),
        cleaningStatus: widget.existing?.cleaningStatus ?? '',
      );

      if (widget.existing == null) {
        await ConfigService.createUnit(unit);
      } else {
        await ConfigService.updateUnit(unit);
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
    final capacity = int.tryParse(_capacity.text.trim()) ?? 0;
    final capacityWarning =
        widget.maxUpcomingGuests > 0 &&
        capacity > 0 &&
        capacity < widget.maxUpcomingGuests;
    final typeChanged =
        widget.existing != null &&
        widget.existing!.unitTypeId.isNotEmpty &&
        _unitTypeId != widget.existing!.unitTypeId;
    final types = _selectableTypes;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(
            text: 'Name',
            child: TextFormField(
              controller: _name,
              style: AppText.body,
              textCapitalization: TextCapitalization.words,
              decoration: AppInputs.decoration(
                hint: 'e.g. Cottage 1',
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
            child: types.isEmpty
                ? const FormMessage(
                    'There are no active unit types. Add one in Unit Types first.',
                  )
                : DropdownButtonFormField<String>(
                    initialValue: types.any((t) => t.id == _unitTypeId)
                        ? _unitTypeId
                        : null,
                    isExpanded: true,
                    decoration: AppInputs.decoration(
                      hint: 'Select a unit type',
                      icon: Icons.category,
                    ),
                    style: AppText.body,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    dropdownColor: AppColors.surface,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                    items: [
                      for (final t in types)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.isActive ? t.name : '${t.name} (inactive)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving ? null : _onTypeChanged,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Unit type is required.'
                        : null,
                  ),
          ),
          if (typeChanged) ...[
            const SizedBox(height: 8),
            const FormMessage(
              'Changing the unit type changes pricing for new reservations '
              'only. Existing reservations keep their saved type and price.',
              isError: false,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FieldLabel(
                  text: 'Capacity',
                  child: TextFormField(
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FieldLabel(
                  text: 'Sort order',
                  child: TextFormField(
                    controller: _sortOrder,
                    style: AppText.body,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: AppInputs.decoration(
                      hint: '0',
                      icon: Icons.sort,
                    ),
                    validator: ConfigRules.validateSortOrder,
                  ),
                ),
              ),
            ],
          ),
          if (capacityWarning) ...[
            const SizedBox(height: 8),
            FormMessage(
              'An upcoming reservation has ${widget.maxUpcomingGuests} guests. '
              'Lowering the capacity doesn’t change existing reservations.',
              isError: false,
            ),
          ],
          const SizedBox(height: 12),
          ManageSwitchRow(
            label: 'Active',
            description: 'Inactive units aren’t offered for new reservations.',
            value: _isActive,
            onChanged: _saving ? null : (v) => setState(() => _isActive = v),
          ),
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
