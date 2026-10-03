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
import '../../widgets/active_badge.dart';
import '../../widgets/adaptive_form.dart';
import '../../widgets/app_card.dart';
import '../../widgets/responsive.dart';
import 'manage_common.dart';
import 'rate_dialog.dart';

/// Manage Resort → Rates: one price per unit type + stay type.
class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  List<UnitType> _unitTypes = [];
  List<StayType> _stayTypes = [];
  List<Rate> _rates = [];
  bool _loading = true;
  String? _error;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final unitTypes = await ConfigService.getUnitTypes();
      final stayTypes = await ConfigService.getStayTypes();
      final rates = await ConfigService.getRates();
      if (!mounted) return;
      setState(() {
        _unitTypes = unitTypes;
        _stayTypes = stayTypes;
        _rates = rates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ConfigService.friendlyError(e);
      });
    }
  }

  List<UnitType> get _visibleUnitTypes =>
      _unitTypes.where((t) => t.isActive || _showInactive).toList();

  List<StayType> get _visibleStayTypes =>
      _stayTypes.where((s) => s.isActive || _showInactive).toList();

  Rate? _rateFor(UnitType t, StayType s) =>
      ConfigRules.rateFor(_rates, t.id, s.id);

  String _basisSuffix(StayType s) =>
      s.pricingBasis == PricingBasis.perNight ? '/night' : '/stay';

  Future<void> _edit(UnitType type, StayType stayType) async {
    final changed = await showAdaptiveForm<bool>(
      context,
      title: 'Rate',
      builder: (_) => RateForm(
        unitTypes: _visibleUnitTypes,
        stayTypes: _visibleStayTypes,
        rates: _rates,
        initialUnitTypeId: type.id,
        initialStayTypeId: stayType.id,
      ),
    );
    if (changed == true && mounted) {
      showManageMessage(context, 'Rates updated.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ManagePage(
      title: 'Rates',
      onRefresh: _load,
      children: [
        const ManageIntro(
          'Set the price for each unit type and stay type. A missing rate '
          'blocks new reservations for that combination.',
        ),
        const FormMessage(
          'Changes to rates only affect new reservations. Existing '
          'reservations keep the rate and total saved when they were booked.',
          isError: false,
        ),
        const SizedBox(height: AppSpacing.md),
        ..._buildContent(),
      ],
    );
  }

  List<Widget> _buildContent() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [LoadErrorCard(message: _error!, onRetry: _load)];
    }

    final types = _visibleUnitTypes;
    final stays = _visibleStayTypes;
    final missing = ConfigRules.missingRates(
      unitTypes: _unitTypes,
      stayTypes: _stayTypes,
      rates: _rates,
    );

    final header = Row(
      children: [
        Expanded(
          child: Text(
            missing.isEmpty
                ? '${_rates.length} rate${_rates.length == 1 ? '' : 's'} '
                    'configured · every active combination has a rate'
                : '${_rates.length} rate${_rates.length == 1 ? '' : 's'} '
                    'configured · ${missing.length} missing',
            style: AppText.value.copyWith(
              color: missing.isEmpty
                  ? AppColors.checkedIn
                  : AppColors.cancelled,
            ),
          ),
        ),
        const Text('Show inactive', style: AppText.bodySecondary),
        Switch(
          value: _showInactive,
          onChanged: (v) => setState(() => _showInactive = v),
        ),
      ],
    );

    if (types.isEmpty || stays.isEmpty) {
      return [
        header,
        const SizedBox(height: 12),
        const ManageEmptyCard(
          icon: Icons.payments_outlined,
          message: 'Add at least one active unit type and stay type first, '
              'then set their rates here.',
        ),
      ];
    }

    return [
      header,
      const SizedBox(height: 12),
      Breakpoints.isDesktop(context)
          ? _buildMatrix(types, stays)
          : _buildGroupedList(types, stays),
    ];
  }

  // ── Desktop: unit types × stay types grid ──────────────────────────────

  Widget _buildMatrix(List<UnitType> types, List<StayType> stays) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const firstColumn = 220.0;
        var cellWidth = (constraints.maxWidth - firstColumn) / stays.length;
        if (cellWidth < 150) cellWidth = 150;
        final tableWidth = firstColumn + cellWidth * stays.length;

        final table = Container(
          width: tableWidth,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header row
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    _headerCell('Unit type', firstColumn),
                    for (final s in stays)
                      _headerCell(
                        '${s.name}${s.isActive ? '' : ' (inactive)'}',
                        cellWidth,
                        caption: s.pricingBasis == PricingBasis.perNight
                            ? 'per night'
                            : 'per stay',
                      ),
                  ],
                ),
              ),
              // One row per unit type
              for (var i = 0; i < types.length; i++)
                Container(
                  decoration: BoxDecoration(
                    border: i == types.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.divider),
                          ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: firstColumn,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  types[i].name,
                                  style: AppText.valueStrong,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!types[i].isActive) ...[
                                const SizedBox(width: 6),
                                const ActiveBadge(isActive: false),
                              ],
                            ],
                          ),
                        ),
                      ),
                      for (final s in stays)
                        SizedBox(
                          width: cellWidth,
                          child: _rateCell(types[i], s),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );

        if (tableWidth <= constraints.maxWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        );
      },
    );
  }

  Widget _headerCell(String label, double width, {String? caption}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppText.overline.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (caption != null) Text(caption, style: AppText.caption),
          ],
        ),
      ),
    );
  }

  Widget _rateCell(UnitType type, StayType stay) {
    final rate = _rateFor(type, stay);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _edit(type, stay),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: rate == null
                    ? Text(
                        'Not set',
                        style: AppText.value.copyWith(
                          color: AppColors.cancelled,
                        ),
                      )
                    : Text(
                        '${CurrencyFormat.peso(rate.price)}${_basisSuffix(stay)}',
                        style: AppText.valueStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              Icon(
                rate == null ? Icons.add_circle_outline : Icons.edit_outlined,
                size: 16,
                color: rate == null ? AppColors.cancelled : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Phone / tablet: grouped list ───────────────────────────────────────

  Widget _buildGroupedList(List<UnitType> types, List<StayType> stays) {
    return ManageCardGrid(
      children: [
        for (final type in types)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          type.name,
                          style: AppText.cardTitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!type.isActive) ...[
                        const SizedBox(width: 8),
                        const ActiveBadge(isActive: false),
                      ],
                    ],
                  ),
                ),
                for (final s in stays)
                  InkWell(
                    onTap: () => _edit(type, s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: AppText.value),
                                Text(
                                  s.pricingBasis == PricingBasis.perNight
                                      ? 'per night'
                                      : 'per stay',
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ),
                          _rateText(type, s),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rateText(UnitType type, StayType stay) {
    final rate = _rateFor(type, stay);
    if (rate == null) {
      return Text(
        'Not set',
        style: AppText.value.copyWith(color: AppColors.cancelled),
      );
    }
    return Text(
      '${CurrencyFormat.peso(rate.price)}${_basisSuffix(stay)}',
      style: AppText.valueStrong.copyWith(color: AppColors.primary),
    );
  }
}
