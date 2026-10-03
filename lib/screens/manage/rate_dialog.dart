import 'package:flutter/material.dart';
import '../../logic/config_rules.dart';
import '../../models/rate.dart';
import '../../models/stay_type.dart';
import '../../models/unit_type.dart';
import '../../services/config_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/confirm_dialog.dart';
import 'manage_common.dart';

/// Rate editor (unit type + stay type → price in ₱).
/// Pops `true` when a rate was saved or removed.
///
/// Rates only affect NEW reservations: existing reservations keep the
/// rate and total saved when they were booked.
class RateForm extends StatefulWidget {
  final List<UnitType> unitTypes;
  final List<StayType> stayTypes;
  final List<Rate> rates;
  final String initialUnitTypeId;
  final String initialStayTypeId;

  const RateForm({
    super.key,
    required this.unitTypes,
    required this.stayTypes,
    required this.rates,
    required this.initialUnitTypeId,
    required this.initialStayTypeId,
  });

  @override
  State<RateForm> createState() => _RateFormState();
}

class _RateFormState extends State<RateForm> {
  final _formKey = GlobalKey<FormState>();
  final _price = TextEditingController();
  late String _unitTypeId;
  late String _stayTypeId;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unitTypeId = widget.initialUnitTypeId;
    _stayTypeId = widget.initialStayTypeId;
    _loadPriceText();
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Rate? get _existing =>
      ConfigRules.rateFor(widget.rates, _unitTypeId, _stayTypeId);

  StayType? get _stayType {
    for (final s in widget.stayTypes) {
      if (s.id == _stayTypeId) return s;
    }
    return null;
  }

  /// Shows the current price of the selected combination (if any).
  void _loadPriceText() {
    final existing = _existing;
    if (existing == null) {
      _price.text = '';
    } else {
      final p = existing.price;
      _price.text =
          p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ConfigService.saveRate(
        unitTypeId: _unitTypeId,
        stayTypeId: _stayTypeId,
        price: ConfigRules.parsePrice(_price.text),
      );
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

  Future<void> _remove() async {
    final existing = _existing;
    if (existing == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove this rate?',
      message: 'New reservations for this combination will be blocked until '
          'a rate is set again. Existing reservations keep their saved price.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ConfigService.deleteRate(existing.id);
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
    final existing = _existing;
    final stayType = _stayType;
    final perNight = stayType?.pricingBasis == PricingBasis.perNight;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(
            text: 'Unit type',
            child: DropdownButtonFormField<String>(
              initialValue: _unitTypeId,
              isExpanded: true,
              decoration: AppInputs.decoration(icon: Icons.category),
              style: AppText.body,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              dropdownColor: AppColors.surface,
              items: [
                for (final t in widget.unitTypes)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(
                      t.isActive ? t.name : '${t.name} (inactive)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _unitTypeId = v);
                      _loadPriceText();
                    },
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel(
            text: 'Stay type',
            child: DropdownButtonFormField<String>(
              initialValue: _stayTypeId,
              isExpanded: true,
              decoration: AppInputs.decoration(icon: Icons.schedule),
              style: AppText.body,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              dropdownColor: AppColors.surface,
              items: [
                for (final s in widget.stayTypes)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      s.isActive ? s.name : '${s.name} (inactive)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _stayTypeId = v);
                      _loadPriceText();
                    },
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel(
            text: perNight ? 'Price per night (₱)' : 'Price per stay (₱)',
            child: TextFormField(
              controller: _price,
              style: AppText.body,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: AppInputs.decoration(
                hint: 'e.g. 2500',
                icon: Icons.payments_outlined,
              ).copyWith(prefixText: '₱ '),
              validator: ConfigRules.validatePrice,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            existing == null
                ? 'No rate is set for this combination yet.'
                : 'Current rate: ${CurrencyFormat.peso(existing.price)}'
                    '${perNight ? ' per night' : ' per stay'}',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          const FormMessage(
            'Changes to rates only affect new reservations.',
            isError: false,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            FormMessage(_error!),
          ],
          const SizedBox(height: 20),
          FormButtons(saving: _saving, onSave: _save, saveLabel: 'Save Rate'),
          if (existing != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _remove,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cancelled,
                side: const BorderSide(color: AppColors.cancelled, width: 2),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove Rate'),
            ),
          ],
        ],
      ),
    );
  }
}
