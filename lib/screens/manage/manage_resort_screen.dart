import 'package:flutter/material.dart';
import '../../logic/config_rules.dart';
import '../../models/rate.dart';
import '../../models/stay_type.dart';
import '../../models/unit.dart';
import '../../models/unit_type.dart';
import '../../services/config_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/responsive.dart';
import 'manage_common.dart';
import 'rates_screen.dart';
import 'stay_types_screen.dart';
import 'unit_types_screen.dart';
import 'units_screen.dart';

/// Manage Resort: entry point to Unit Types, Units, Stay Types and Rates,
/// with counts and a setup checklist.
class ManageResortScreen extends StatefulWidget {
  const ManageResortScreen({super.key});

  @override
  State<ManageResortScreen> createState() => _ManageResortScreenState();
}

class _ManageResortScreenState extends State<ManageResortScreen> {
  List<UnitType> _unitTypes = [];
  List<Unit> _units = [];
  List<StayType> _stayTypes = [];
  List<Rate> _rates = [];
  bool _loading = true;
  String? _error;

  /// How many missing-rate lines to show before summarising the rest.
  static const int _maxMissingRatesShown = 6;

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
      final units = await ConfigService.getUnits();
      final stayTypes = await ConfigService.getStayTypes();
      final rates = await ConfigService.getRates();
      if (!mounted) return;
      setState(() {
        _unitTypes = unitTypes;
        _units = units;
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

  Widget _screenFor(ConfigSection section) {
    switch (section) {
      case ConfigSection.unitTypes:
        return const UnitTypesScreen();
      case ConfigSection.units:
        return const UnitsScreen();
      case ConfigSection.stayTypes:
        return const StayTypesScreen();
      case ConfigSection.rates:
        return const RatesScreen();
    }
  }

  Future<void> _open(ConfigSection section) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _screenFor(section)));
    if (mounted) _load(); // counts may have changed
  }

  String _activeOfTotal(int active, int total) =>
      '$active active / $total total';

  @override
  Widget build(BuildContext context) {
    return ManagePage(
      title: 'Manage Resort',
      onRefresh: _load,
      intro:
          'Set up what your resort offers. These settings drive the units, '
          'stay types and prices available when adding reservations.',
      isHub: true,
      children: [..._buildContent()],
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

    final sections = [
      _SectionCard(
        icon: Icons.category_outlined,
        title: 'Unit Types',
        count: _activeOfTotal(
          _unitTypes.where((t) => t.isActive).length,
          _unitTypes.length,
        ),
        description: 'Room, Cottage, Villa…',
        onTap: () => _open(ConfigSection.unitTypes),
      ),
      _SectionCard(
        icon: Icons.meeting_room_outlined,
        title: 'Units',
        count: _activeOfTotal(
          _units.where((u) => u.isActive).length,
          _units.length,
        ),
        description: 'Everything guests can book',
        onTap: () => _open(ConfigSection.units),
      ),
      _SectionCard(
        icon: Icons.schedule,
        title: 'Stay Types',
        count: _activeOfTotal(
          _stayTypes.where((s) => s.isActive).length,
          _stayTypes.length,
        ),
        description: 'Overnight, Day Tour…',
        onTap: () => _open(ConfigSection.stayTypes),
      ),
      _SectionCard(
        icon: Icons.payments_outlined,
        title: 'Rates',
        count: '${_rates.length} configured',
        description: 'Price per unit type & stay type',
        onTap: () => _open(ConfigSection.rates),
      ),
    ];

    return [
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final int columns;
          if (Breakpoints.isDesktop(context) && constraints.maxWidth >= 900) {
            columns = 4;
          } else if (constraints.maxWidth >= 480) {
            columns = 2;
          } else {
            columns = 1;
          }
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in sections) SizedBox(width: width, child: card),
            ],
          );
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      _buildChecklist(),
    ];
  }

  Widget _buildChecklist() {
    final issues = ConfigRules.setupChecklist(
      unitTypes: _unitTypes,
      units: _units,
      stayTypes: _stayTypes,
      rates: _rates,
    );
    final missingRates = issues
        .where((i) => i.section == ConfigSection.rates)
        .toList();
    final otherIssues = issues
        .where((i) => i.section != ConfigSection.rates)
        .toList();
    final shownRates = missingRates.take(_maxMissingRatesShown).toList();
    final hiddenRates = missingRates.length - shownRates.length;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('SETUP CHECKLIST', style: AppText.overline),
          const SizedBox(height: 8),
          if (issues.isEmpty)
            const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.checkedIn, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Everything is set up. Reservations can be created for '
                    'every active unit and stay type.',
                    style: AppText.body,
                  ),
                ),
              ],
            ),
          for (final issue in otherIssues)
            _IssueRow(
              message: issue.message,
              actionLabel: 'Open',
              onAction: () => _open(issue.section),
            ),
          for (final issue in shownRates)
            _IssueRow(
              message: issue.message,
              actionLabel: 'Go to Rates',
              onAction: () => _open(ConfigSection.rates),
            ),
          if (hiddenRates > 0)
            _IssueRow(
              message:
                  'and $hiddenRates more missing '
                  'rate${hiddenRates == 1 ? '' : 's'}',
              actionLabel: 'Go to Rates',
              onAction: () => _open(ConfigSection.rates),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String count;
  final String description;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: AppText.valueStrong.copyWith(color: AppColors.primary),
                ),
                Text(description, style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _IssueRow({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.body)),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
