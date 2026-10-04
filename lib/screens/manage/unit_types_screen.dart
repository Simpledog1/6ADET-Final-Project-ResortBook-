import 'package:flutter/material.dart';
import '../../logic/config_rules.dart';
import '../../models/unit.dart';
import '../../models/unit_type.dart';
import '../../services/config_service.dart';
import '../../services/reservation_gateway.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/active_badge.dart';
import '../../widgets/adaptive_form.dart';
import '../../widgets/admin_table.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/responsive.dart';
import 'manage_common.dart';
import 'unit_type_form.dart';

/// Manage Resort → Unit Types (Room, Cottage, Villa, …).
class UnitTypesScreen extends StatefulWidget {
  /// PocketBase access; tests pass a fake.
  final ReservationGateway gateway;

  const UnitTypesScreen({super.key, this.gateway = const ReservationGateway()});

  @override
  State<UnitTypesScreen> createState() => _UnitTypesScreenState();
}

class _UnitTypesScreenState extends State<UnitTypesScreen> {
  List<UnitType> _types = [];
  List<Unit> _units = [];
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
      final types = await widget.gateway.getUnitTypes();
      final units = await widget.gateway.getUnits();
      if (!mounted) return;
      setState(() {
        _types = types;
        _units = units;
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

  int _unitCount(UnitType type) =>
      _units.where((u) => u.unitTypeId == type.id).length;

  int _activeUnitCount(UnitType type) =>
      ConfigRules.activeUnitsOfType(type.id, _units).length;

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _openForm([UnitType? type]) async {
    final otherNames = _types
        .where((t) => t.id != type?.id)
        .map((t) => t.name)
        .toList();
    final saved = await showAdaptiveForm<bool>(
      context,
      title: type == null ? 'Add Unit Type' : 'Edit Unit Type',
      builder: (_) => UnitTypeForm(
        existing: type,
        otherNames: otherNames,
        gateway: widget.gateway,
      ),
    );
    if (saved == true && mounted) {
      showManageMessage(
        context,
        type == null ? 'Unit type added.' : 'Unit type updated.',
      );
      _load();
    }
  }

  Future<void> _deactivate(UnitType type) async {
    final activeUnits = ConfigRules.activeUnitsOfType(type.id, _units);
    final count = activeUnits.length;
    var alsoDeactivateUnits = false; // OFF by default

    final confirmed = await showConfirmDialog(
      context,
      title: 'Deactivate ${type.name}?',
      message: count == 0
          ? 'No active units use this type. It will no longer be offered '
                'for new units. Existing reservations are not affected.'
          : '$count active unit${count == 1 ? '' : 's'} use this type. '
                'Existing reservations are not affected, and units are never '
                'deleted.',
      confirmLabel: 'Deactivate',
      details: count == 0
          ? null
          : StatefulBuilder(
              builder: (context, setLocal) => CheckboxListTile(
                value: alsoDeactivateUnits,
                onChanged: (v) =>
                    setLocal(() => alsoDeactivateUnits = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Also deactivate these $count unit${count == 1 ? '' : 's'}',
                  style: AppText.body,
                ),
                subtitle: Text(
                  activeUnits.map((u) => u.name).join(', '),
                  style: AppText.caption,
                ),
              ),
            ),
    );
    if (!confirmed) return;

    try {
      final unitsToDeactivate = ConfigRules.unitsToDeactivateWithType(
        unitTypeId: type.id,
        units: _units,
        alsoDeactivateUnits: alsoDeactivateUnits,
      );
      await widget.gateway.deactivateUnitType(
        type.id,
        alsoDeactivateUnitIds: unitsToDeactivate.map((u) => u.id).toList(),
      );
      if (!mounted) return;
      showManageMessage(
        context,
        unitsToDeactivate.isEmpty
            ? '${type.name} deactivated.'
            : '${type.name} and ${unitsToDeactivate.length} '
                  'unit${unitsToDeactivate.length == 1 ? '' : 's'} deactivated.',
      );
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  Future<void> _activate(UnitType type) async {
    try {
      await widget.gateway.setUnitTypeActive(type.id, true);
      if (!mounted) return;
      final inactiveUnits = _units
          .where((u) => u.unitTypeId == type.id && !u.isActive)
          .length;
      showManageMessage(
        context,
        inactiveUnits == 0
            ? '${type.name} activated.'
            : '${type.name} activated. Its $inactiveUnits inactive '
                  'unit${inactiveUnits == 1 ? ' stays' : 's stay'} inactive — '
                  'reactivate them from Units.',
      );
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  Future<void> _delete(UnitType type) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${type.name}?',
      message:
          'No units use this type. Any rates set for it are removed too. '
          'Existing reservations keep their saved names and prices. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.gateway.deleteUnitType(type.id); // re-checks usage first
      if (!mounted) return;
      showManageMessage(context, '${type.name} deleted.');
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  List<ManageAction> _actionsFor(UnitType type) {
    final unitCount = _unitCount(type);
    return [
      ManageAction(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _openForm(type),
      ),
      type.isActive
          ? ManageAction(
              label: 'Deactivate',
              icon: Icons.pause_circle_outline,
              onPressed: () => _deactivate(type),
            )
          : ManageAction(
              label: 'Activate',
              icon: Icons.play_circle_outline,
              onPressed: () => _activate(type),
            ),
      ManageAction(
        label: 'Delete',
        icon: Icons.delete_outline,
        destructive: true,
        onPressed: ConfigRules.canDeleteUnitType(unitCount)
            ? () => _delete(type)
            : null,
        disabledReason: ConfigRules.unitTypeInUseMessage(unitCount),
      ),
    ];
  }

  String _unitsLabel(UnitType type) {
    final total = _unitCount(type);
    final active = _activeUnitCount(type);
    if (total == 0) return 'No units';
    return '$total unit${total == 1 ? '' : 's'} ($active active)';
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ManagePage(
      title: 'Unit Types',
      onRefresh: _load,
      intro:
          'Group your units into types such as Room, Cottage or Villa. '
          'Rates are set per unit type.',
      addLabel: 'Add Unit Type',
      onAdd: () => _openForm(),
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
    if (_types.isEmpty) {
      return [
        ManageEmptyCard(
          icon: Icons.category_outlined,
          message: 'No unit types yet. Add your first one, e.g. "Cottage".',
          actionLabel: 'Add Unit Type',
          onAction: () => _openForm(),
        ),
      ];
    }

    if (Breakpoints.isDesktop(context)) {
      return [
        AdminTable(
          columns: const [
            AdminColumn('Name', flex: 4),
            AdminColumn('Default capacity', flex: 2),
            AdminColumn('Units', flex: 3),
            AdminColumn('Status', flex: 2),
            AdminColumn('Actions', flex: 3, align: TextAlign.right),
          ],
          rows: [
            for (final type in _types)
              AdminRow(
                onTap: () => _openForm(type),
                cells: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(type.name, style: AppText.valueStrong),
                      if (type.description.isNotEmpty)
                        Text(
                          type.description,
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  Text('${type.defaultCapacity} guests', style: AppText.body),
                  Text(_unitsLabel(type), style: AppText.bodySecondary),
                  ActiveBadge(isActive: type.isActive),
                  ManageActionIcons(actions: _actionsFor(type)),
                ],
              ),
          ],
          footer: '${_types.length} unit type${_types.length == 1 ? '' : 's'}',
        ),
      ];
    }

    return [
      ManageCardGrid(
        children: [
          for (final type in _types)
            AppCard(
              onTap: () => _openForm(type),
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
                                type.name,
                                style: AppText.cardTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActiveBadge(isActive: type.isActive),
                          ],
                        ),
                        if (type.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(type.description, style: AppText.caption),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Default capacity ${type.defaultCapacity} · '
                          '${_unitsLabel(type)}',
                          style: AppText.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  ManageActionMenu(actions: _actionsFor(type)),
                ],
              ),
            ),
        ],
      ),
    ];
  }
}
