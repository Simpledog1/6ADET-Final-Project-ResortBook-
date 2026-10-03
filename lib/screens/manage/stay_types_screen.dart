import 'package:flutter/material.dart';
import '../../logic/config_rules.dart';
import '../../models/stay_type.dart';
import '../../services/config_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/active_badge.dart';
import '../../widgets/adaptive_form.dart';
import '../../widgets/admin_table.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/responsive.dart';
import 'manage_common.dart';
import 'stay_type_form.dart';

/// Manage Resort → Stay Types (Overnight, Day Tour, Night Tour, custom…).
class StayTypesScreen extends StatefulWidget {
  const StayTypesScreen({super.key});

  @override
  State<StayTypesScreen> createState() => _StayTypesScreenState();
}

class _StayTypesScreenState extends State<StayTypesScreen> {
  List<StayType> _stayTypes = [];
  ReservationUsage? _usage;
  bool _loading = true;
  String? _error;

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
      final stayTypes = await ConfigService.getStayTypes();
      final usage = await ConfigService.getReservationUsage();
      if (!mounted) return;
      setState(() {
        _stayTypes = stayTypes;
        _usage = usage;
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

  int _reservations(StayType st) => _usage?.stayTypeTotal(st.id) ?? 0;

  String _times(StayType st) =>
      stayTimesLabel(st.checkInTime, st.checkOutTime, st.endsNextDay);

  String _basis(StayType st) =>
      st.pricingBasis == PricingBasis.perNight ? 'Per night' : 'Per stay';

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _openForm([StayType? stayType]) async {
    final otherNames = _stayTypes
        .where((s) => s.id != stayType?.id)
        .map((s) => s.name)
        .toList();
    final saved = await showAdaptiveForm<bool>(
      context,
      title: stayType == null ? 'Add Stay Type' : 'Edit Stay Type',
      builder: (_) => StayTypeForm(
        existing: stayType,
        otherNames: otherNames,
        isLastActive: stayType != null &&
            ConfigRules.isLastActiveStayType(stayType, _stayTypes),
        reservationCount: stayType == null ? 0 : _reservations(stayType),
      ),
    );
    if (saved == true && mounted) {
      showManageMessage(
        context,
        stayType == null ? 'Stay type added.' : 'Stay type updated.',
      );
      _load();
    }
  }

  Future<void> _deactivate(StayType st) async {
    final isLast = ConfigRules.isLastActiveStayType(st, _stayTypes);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Deactivate ${st.name}?',
      message: 'It will no longer be offered for new reservations. '
          'Existing reservations keep their saved stay type.',
      confirmLabel: 'Deactivate',
      details: isLast
          ? const FormMessage(
              'This is the last active stay type. New reservations cannot be '
              'created until another stay type is active.',
              isError: false,
            )
          : null,
    );
    if (!confirmed) return;
    try {
      await ConfigService.setStayTypeActive(st.id, false);
      if (!mounted) return;
      showManageMessage(context, '${st.name} deactivated.');
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  Future<void> _activate(StayType st) async {
    try {
      await ConfigService.setStayTypeActive(st.id, true);
      if (!mounted) return;
      showManageMessage(context, '${st.name} activated.');
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  Future<void> _delete(StayType st) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${st.name}?',
      message: 'No reservations use this stay type. Any rates set for it are '
          'removed too. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ConfigService.deleteStayType(st.id); // re-checks usage first
      if (!mounted) return;
      showManageMessage(context, '${st.name} deleted.');
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  List<ManageAction> _actionsFor(StayType st) {
    final reservations = _reservations(st);
    return [
      ManageAction(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _openForm(st),
      ),
      st.isActive
          ? ManageAction(
              label: 'Deactivate',
              icon: Icons.pause_circle_outline,
              onPressed: () => _deactivate(st),
            )
          : ManageAction(
              label: 'Activate',
              icon: Icons.play_circle_outline,
              onPressed: () => _activate(st),
            ),
      ManageAction(
        label: 'Delete',
        icon: Icons.delete_outline,
        destructive: true,
        onPressed: ConfigRules.canDeleteStayType(reservations)
            ? () => _delete(st)
            : null,
        disabledReason: 'Used by $reservations reservation'
            '${reservations == 1 ? '' : 's'} — deactivate instead',
      ),
    ];
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ManagePage(
      title: 'Stay Types',
      onRefresh: _load,
      children: [
        const ManageIntro(
          'How guests can stay: check-in and check-out times, whether the '
          'stay ends the next day, and how it is priced.',
        ),
        ManageAddButton(label: 'Add Stay Type', onPressed: () => _openForm()),
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
    if (_stayTypes.isEmpty) {
      return [
        ManageEmptyCard(
          icon: Icons.schedule,
          message: 'No stay types yet. Add one, e.g. "Overnight".',
          actionLabel: 'Add Stay Type',
          onAction: () => _openForm(),
        ),
      ];
    }

    final widgets = <Widget>[];
    if (!_stayTypes.any((s) => s.isActive)) {
      widgets.add(const FormMessage(
        'No stay type is active. New reservations cannot be created until '
        'one is activated.',
        isError: false,
      ));
      widgets.add(const SizedBox(height: AppSpacing.md));
    }

    if (Breakpoints.isDesktop(context)) {
      widgets.add(
        AdminTable(
          columns: const [
            AdminColumn('Name', flex: 3),
            AdminColumn('Times', flex: 4),
            AdminColumn('Nights', flex: 2),
            AdminColumn('Pricing', flex: 2),
            AdminColumn('Used by', flex: 2),
            AdminColumn('Status', flex: 2),
            AdminColumn('Actions', flex: 3, align: TextAlign.right),
          ],
          rows: [
            for (final st in _stayTypes)
              AdminRow(
                onTap: () => _openForm(st),
                cells: [
                  Text(st.name, style: AppText.valueStrong),
                  Text(_times(st), style: AppText.body),
                  Text(
                    st.allowMultipleNights ? 'Multiple' : 'Single',
                    style: AppText.bodySecondary,
                  ),
                  Text(_basis(st), style: AppText.bodySecondary),
                  Text(
                    '${_reservations(st)} reservation'
                    '${_reservations(st) == 1 ? '' : 's'}',
                    style: AppText.bodySecondary,
                  ),
                  ActiveBadge(isActive: st.isActive),
                  ManageActionIcons(actions: _actionsFor(st)),
                ],
              ),
          ],
          footer:
              '${_stayTypes.length} stay type${_stayTypes.length == 1 ? '' : 's'}',
        ),
      );
      return widgets;
    }

    widgets.add(
      ManageCardGrid(
        children: [
          for (final st in _stayTypes)
            AppCard(
              onTap: () => _openForm(st),
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                st.name,
                                style: AppText.cardTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActiveBadge(isActive: st.isActive),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_times(st), style: AppText.value),
                        Text(
                          '${_basis(st)}'
                          '${st.allowMultipleNights ? ' · multiple nights' : ''}'
                          ' · used by ${_reservations(st)} reservation'
                          '${_reservations(st) == 1 ? '' : 's'}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  ManageActionMenu(actions: _actionsFor(st)),
                ],
              ),
            ),
        ],
      ),
    );
    return widgets;
  }
}
