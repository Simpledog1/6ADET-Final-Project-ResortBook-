// Small building blocks shared by the Manage Resort screens.
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/responsive.dart';

/// Page frame for a Manage Resort screen: header, pull-to-refresh and a
/// content column limited to a comfortable width.
class ManagePage extends StatelessWidget {
  final String title;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  const ManagePage({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = Breakpoints.isDesktop(context) ? 1200.0 : 720.0;
    return Scaffold(
      appBar: AppHeader(title: title),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: AppSpacing.lg * 2),
          children: [
            ResponsiveContent(
              maxWidth: maxWidth,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Short explanation under the page title.
class ManageIntro extends StatelessWidget {
  final String text;

  const ManageIntro(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(text, style: AppText.bodySecondary),
    );
  }
}

/// "Add …" button: full width on phones, compact on wider screens.
class ManageAddButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const ManageAddButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      style: Breakpoints.isPhone(context) ? null : CompactButtons.filled(),
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 20),
      label: Text(label),
    );
    if (Breakpoints.isPhone(context)) return button;
    return Align(alignment: Alignment.centerRight, child: button);
  }
}

/// Rounded search box (same look as the Reservation List search).
class ManageSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const ManageSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color),
        );

    return SizedBox(
      height: AppSpacing.searchHeight,
      child: TextField(
        style: AppText.body,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13.5),
          border: border(AppColors.border),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.primary),
        ),
      ),
    );
  }
}

/// Pill-shaped filter options (Figma "All / Reserved / …" chips).
class ManageFilterChips<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onSelected;

  const ManageFilterChips({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < values.length; i++)
          _chip(labels[i], values[i] == selected, () => onSelected(values[i])),
      ],
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    final radius = BorderRadius.circular(999);
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppText.value.copyWith(
              fontSize: 13,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One action on a configuration record (edit, deactivate, delete…).
/// A null [onPressed] means the action is unavailable; [disabledReason]
/// explains why (shown as a tooltip / menu subtitle).
class ManageAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final String? disabledReason;

  const ManageAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.disabledReason,
  });
}

/// Desktop: a row of icon buttons with tooltips.
class ManageActionIcons extends StatelessWidget {
  final List<ManageAction> actions;

  const ManageActionIcons({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    // Scales down instead of overflowing in narrow table columns.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            Tooltip(
              message: action.onPressed == null
                  ? (action.disabledReason ?? action.label)
                  : action.label,
              child: IconButton(
                icon: Icon(action.icon, size: 20),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                color: action.destructive
                    ? AppColors.cancelled
                    : AppColors.textSecondary,
                disabledColor: AppColors.textDisabled,
                onPressed: action.onPressed,
              ),
            ),
        ],
      ),
    );
  }
}

/// Phone / tablet: a "⋮" menu with the same actions.
class ManageActionMenu extends StatelessWidget {
  final List<ManageAction> actions;

  const ManageActionMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      color: AppColors.surface,
      onSelected: (index) => actions[index].onPressed?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onPressed != null,
            child: Row(
              children: [
                Icon(
                  actions[i].icon,
                  size: 18,
                  color: actions[i].onPressed == null
                      ? AppColors.textDisabled
                      : (actions[i].destructive
                          ? AppColors.cancelled
                          : AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(actions[i].label),
                      if (actions[i].onPressed == null &&
                          actions[i].disabledReason != null)
                        Text(
                          actions[i].disabledReason!,
                          style: AppText.caption,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Error card with a Retry button.
class LoadErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const LoadErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 28,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            style: CompactButtons.outlined(),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Empty state card with an optional action button.
class ManageEmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ManageEmptyCard({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodySecondary,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: CompactButtons.filled(),
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays out cards in one column on phones and two columns on wider screens.
class ManageCardGrid extends StatelessWidget {
  final List<Widget> children;

  const ManageCardGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// Labelled on/off setting styled like the form inputs.
class ManageSwitchRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const ManageSwitchRow({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.value.copyWith(
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                if (description != null)
                  Text(description!, style: AppText.caption),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Inline message box for forms (error = red, warning = orange).
class FormMessage extends StatelessWidget {
  final String message;
  final bool isError;

  const FormMessage(this.message, {super.key, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.cancelled : AppColors.warningText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? AppColors.cancelledTint : AppColors.warningTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: isError ? AppColors.cancelledDot : AppColors.warningBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppText.body.copyWith(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Save + Cancel buttons at the bottom of a configuration form.
class FormButtons extends StatelessWidget {
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  const FormButtons({
    super.key,
    required this.saving,
    required this.onSave,
    this.saveLabel = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(saveLabel),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Shows a short message at the bottom of the screen.
void showManageMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
