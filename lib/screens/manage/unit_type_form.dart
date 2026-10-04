import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/config_rules.dart';
import '../../models/unit_type.dart';
import '../../services/config_service.dart';
import '../../services/reservation_gateway.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_inputs.dart';
import 'manage_common.dart';

/// Create / edit form for a unit type. Pops `true` after a successful save.
class UnitTypeForm extends StatefulWidget {
  /// Null when creating a new unit type.
  final UnitType? existing;

  /// Names of the OTHER unit types (for the duplicate-name check).
  final List<String> otherNames;

  /// PocketBase access; tests pass a fake.
  final ReservationGateway gateway;

  const UnitTypeForm({
    super.key,
    this.existing,
    required this.otherNames,
    this.gateway = const ReservationGateway(),
  });

  @override
  State<UnitTypeForm> createState() => _UnitTypeFormState();
}

class _UnitTypeFormState extends State<UnitTypeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _capacity;
  late final TextEditingController _sortOrder;
  late bool _isActive;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _name = TextEditingController(text: t?.name ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _capacity = TextEditingController(
      text: t != null && t.defaultCapacity > 0 ? '${t.defaultCapacity}' : '',
    );
    _sortOrder = TextEditingController(
      text: t != null && t.sortOrder != 0 ? '${t.sortOrder}' : '',
    );
    _isActive = t?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _capacity.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final type = UnitType(
      id: widget.existing?.id ?? '',
      name: ConfigRules.normalizeName(_name.text),
      description: _description.text.trim(),
      defaultCapacity: int.parse(_capacity.text.trim()),
      isActive: _isActive,
      sortOrder: ConfigRules.parseSortOrder(_sortOrder.text),
    );

    try {
      if (widget.existing == null) {
        await widget.gateway.createUnitType(type);
      } else {
        await widget.gateway.updateUnitType(type);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      // Keep everything the user typed; just show what went wrong.
      setState(() {
        _saving = false;
        _error = ConfigService.friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                hint: 'e.g. Cottage, Villa, Function Hall',
                icon: Icons.category,
              ),
              validator: (v) => ConfigRules.validateName(
                v,
                existingNames: widget.otherNames,
                itemLabel: 'unit type',
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
              decoration: AppInputs.decoration(
                hint: 'What guests get with this type',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FieldLabel(
                  text: 'Default capacity',
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
          const SizedBox(height: 12),
          ManageSwitchRow(
            label: 'Active',
            description: 'Inactive types can’t be chosen for new units.',
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
