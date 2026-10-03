import 'package:flutter/material.dart';
import '../../logic/config_rules.dart';
import '../../models/unit.dart';
import '../../models/unit_type.dart';
import '../../services/config_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/active_badge.dart';
import '../../widgets/adaptive_form.dart';
import '../../widgets/admin_table.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/responsive.dart';
import 'manage_common.dart';
import 'unit_form.dart';
import 'unit_types_screen.dart';

enum _StatusFilter { all, active, inactive }

/// Manage Resort → Units (Cottage 1, Villa A, Function Hall, …).
class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  List<Unit> _units = [];
  List<UnitType> _types = [];
  ReservationUsage? _usage;
  bool _loading = true;
  String? _error;

  String _search = '';
  String? _typeFilter; // null = all unit types
  _StatusFilter _statusFilter = _StatusFilter.all;

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
      final units = await ConfigService.getUnits();
      final types = await ConfigService.getUnitTypes();
      final usage = await ConfigService.getReservationUsage();
      if (!mounted) return;
      setState(() {
        _units = units;
        _types = types;
        _usage = usage;
        if (_typeFilter != null && !types.any((t) => t.id == _typeFilter)) {
          _typeFilter = null;
        }
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

  List<Unit> get _filtered {
    final query = _search.trim().toLowerCase();
    return _units.where((u) {
      if (query.isNotEmpty &&
          !u.name.toLowerCase().contains(query) &&
          !u.typeName.toLowerCase().contains(query)) {
        return false;
      }
      if (_typeFilter != null && u.unitTypeId != _typeFilter) return false;
      if (_statusFilter == _StatusFilter.active && !u.isActive) return false;
      if (_statusFilter == _StatusFilter.inactive && u.isActive) return false;
      return true;
    }).toList();
  }

  int _reservations(Unit u) => _usage?.unitTotal(u.id) ?? 0;
  int _upcoming(Unit u) => _usage?.unitUpcoming(u.id) ?? 0;

  String _typeLabel(Unit u) => u.typeName.isEmpty ? 'No unit type' : u.typeName;

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _openForm([Unit? unit]) async {
    final saved = await showAdaptiveForm<bool>(
      context,
      title: unit == null ? 'Add Unit' : 'Edit Unit',
      builder: (_) => UnitForm(
        existing: unit,
        unitTypes: _types,
        maxUpcomingGuests: unit == null
            ? 0
            : (_usage?.unitMaxUpcomingGuests(unit.id) ?? 0),
      ),
    );
    if (saved == true && mounted) {
      showManageMessage(
        context,
        unit == null ? 'Unit added.' : 'Unit updated.',
      );
      _load();
    }
  }

  Future<void> _openUnitTypes() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const UnitTypesScreen()));
    if (mounted) _load();
  }

  Future<void> _deactivate(Unit unit) async {
    final upcoming = _upcoming(unit);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Deactivate ${unit.name}?',
      message: upcoming == 0
          ? 'It will no longer be offered for new reservations. '
                'Existing reservations are not affected.'
          : '$upcoming upcoming reservation${upcoming == 1 ? '' : 's'} '
                'stay as they are. The unit will no longer be offered for new '
                'reservations.',
      confirmLabel: 'Deactivate',
    );
    if (!confirmed) return;
    try {
      await ConfigService.setUnitActive(unit.id, false);
      if (!mounted) return;
      showManageMessage(context, '${unit.name} deactivated.');
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  Future<void> _activate(Unit unit) async {
    try {
      await ConfigService.setUnitActive(unit.id, true);
      if (!mounted) return;
      showManageMessage(context, '${unit.name} activated.');
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  Future<void> _delete(Unit unit) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${unit.name}?',
      message: 'This unit has no reservations. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ConfigService.deleteUnit(unit.id); // re-checks reservations first
      if (!mounted) return;
      showManageMessage(context, '${unit.name} deleted.');
      _load();
    } catch (e) {
      if (mounted) showManageMessage(context, ConfigService.friendlyError(e));
    }
  }

  List<ManageAction> _actionsFor(Unit unit) {
    final reservations = _reservations(unit);
    return [
      ManageAction(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _openForm(unit),
      ),
      unit.isActive
          ? ManageAction(
              label: 'Deactivate',
              icon: Icons.pause_circle_outline,
              onPressed: () => _deactivate(unit),
            )
          : ManageAction(
              label: 'Activate',
              icon: Icons.play_circle_outline,
              onPressed: () => _activate(unit),
            ),
      ManageAction(
        label: 'Delete',
        icon: Icons.delete_outline,
        destructive: true,
        onPressed: ConfigRules.canDeleteUnit(reservations)
            ? () => _delete(unit)
            : null,
        disabledReason:
            'Has $reservations reservation'
            '${reservations == 1 ? '' : 's'} — deactivate instead',
      ),
    ];
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showToolbar = !_loading && _error == null && _types.isNotEmpty;
    // On desktop the Add button sits in the page header (it used to be at
    // the end of the toolbar); phone and tablet keep it in the toolbar.
    final addInHeader = showToolbar && ManagePage.usesDesktopLayout(context);

    return ManagePage(
      title: 'Units',
      onRefresh: _load,
      intro:
          'Everything guests can book: rooms, cottages, villas, pavilions, '
          'function halls and more.',
      addLabel: addInHeader ? 'Add Unit' : null,
      onAdd: addInHeader ? () => _openForm() : null,
      children: [
        if (showToolbar) ...[
          _buildToolbar(),
          const SizedBox(height: AppSpacing.md),
        ],
        ..._buildContent(),
      ],
    );
  }

  Widget _buildToolbar() {
    final typeDropdown = DropdownButtonFormField<String?>(
      initialValue: _typeFilter,
      isExpanded: true,
      decoration: AppInputs.decoration(icon: Icons.category),
      style: AppText.body,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      dropdownColor: AppColors.surface,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All unit types'),
        ),
        for (final t in _types)
          DropdownMenuItem<String?>(
            value: t.id,
            child: Text(t.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => _typeFilter = v),
    );

    final statusChips = ManageFilterChips<_StatusFilter>(
      values: _StatusFilter.values,
      labels: const ['All', 'Active', 'Inactive'],
      selected: _statusFilter,
      onSelected: (v) => setState(() => _statusFilter = v),
    );

    final search = ManageSearchField(
      hint: 'Search units',
      onChanged: (v) => setState(() => _search = v),
    );

    if (Breakpoints.isPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManageAddButton(label: 'Add Unit', onPressed: () => _openForm()),
          const SizedBox(height: 12),
          search,
          const SizedBox(height: 12),
          typeDropdown,
          const SizedBox(height: 12),
          statusChips,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            SizedBox(width: 220, child: typeDropdown),
            if (!ManagePage.usesDesktopLayout(context)) ...[
              const SizedBox(width: 12),
              ManageAddButton(label: 'Add Unit', onPressed: () => _openForm()),
            ],
          ],
        ),
        const SizedBox(height: 12),
        statusChips,
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
    if (_types.isEmpty) {
      return [
        ManageEmptyCard(
          icon: Icons.category_outlined,
          message:
              'Create a unit type first (for example "Cottage"), '
              'then add units to it.',
          actionLabel: 'Go to Unit Types',
          onAction: _openUnitTypes,
        ),
      ];
    }
    if (_units.isEmpty) {
      return [
        ManageEmptyCard(
          icon: Icons.meeting_room_outlined,
          message: 'No units yet. Add your first one, e.g. "Cottage 1".',
          actionLabel: 'Add Unit',
          onAction: () => _openForm(),
        ),
      ];
    }

    final units = _filtered;
    if (units.isEmpty) {
      return const [
        ManageEmptyCard(
          icon: Icons.search_off,
          message: 'No units match your filters.',
        ),
      ];
    }

    if (Breakpoints.isDesktop(context)) {
      return [
        AdminTable(
          columns: const [
            AdminColumn('Name', flex: 3),
            AdminColumn('Unit type', flex: 3),
            AdminColumn('Capacity', flex: 2),
            AdminColumn('Upcoming', flex: 2),
            AdminColumn('Status', flex: 2),
            AdminColumn('Actions', flex: 3, align: TextAlign.right),
          ],
          rows: [
            for (final unit in units)
              AdminRow(
                onTap: () => _openForm(unit),
                cells: [
                  Text(unit.name, style: AppText.valueStrong),
                  Text(_typeLabel(unit), style: AppText.body),
                  Text('${unit.capacity} guests', style: AppText.body),
                  Text('${_upcoming(unit)}', style: AppText.bodySecondary),
                  ActiveBadge(isActive: unit.isActive),
                  ManageActionIcons(actions: _actionsFor(unit)),
                ],
              ),
          ],
          footer:
              'Showing ${units.length} of ${_units.length} '
              'unit${_units.length == 1 ? '' : 's'}',
        ),
      ];
    }

    return [
      ManageCardGrid(
        children: [
          for (final unit in units)
            AppCard(
              onTap: () => _openForm(unit),
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
                                unit.name,
                                style: AppText.cardTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActiveBadge(isActive: unit.isActive),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_typeLabel(unit)} · up to ${unit.capacity} guests',
                          style: AppText.bodySecondary,
                        ),
                        Text(
                          '${_upcoming(unit)} upcoming reservation'
                          '${_upcoming(unit) == 1 ? '' : 's'}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  ManageActionMenu(actions: _actionsFor(unit)),
                ],
              ),
            ),
        ],
      ),
    ];
  }
}
