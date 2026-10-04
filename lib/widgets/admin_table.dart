import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// One column of an [AdminTable].
///
/// Set [sortable] to make the header clickable (the table's `onSort`
/// decides what sorting means).
class AdminColumn {
  final String label;
  final int flex;
  final TextAlign align;
  final bool sortable;

  const AdminColumn(
    this.label, {
    this.flex = 1,
    this.align = TextAlign.left,
    this.sortable = false,
  });
}

/// One row of an [AdminTable]. [cells] must match the number of columns.
class AdminRow {
  final List<Widget> cells;
  final VoidCallback? onTap;

  const AdminRow({required this.cells, this.onTap});
}

/// Desktop table in the Figma "Reservation List" style: white card,
/// uppercase grey header, divided rows.
///
/// Optional extras (all off by default, so existing tables look the same):
/// * Sorting: mark columns `sortable`, pass [onSort] plus the current
///   [sortColumnIndex] / [sortAscending]. The table only draws the
///   indicator; the caller sorts the rows.
/// * Pagination: pass an [AdminPagination] (or any widget) as [pagination];
///   it is shown in the footer next to the [footer] text.
class AdminTable extends StatelessWidget {
  final List<AdminColumn> columns;
  final List<AdminRow> rows;
  final String? footer;

  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex)? onSort;
  final Widget? pagination;

  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.pagination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                for (var c = 0; c < columns.length; c++)
                  Expanded(flex: columns[c].flex, child: _headerCell(c)),
              ],
            ),
          ),

          // Rows
          for (var i = 0; i < rows.length; i++)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: rows[i].onTap,
                hoverColor: rows[i].onTap == null
                    ? Colors.transparent
                    : AppColors.background,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: i == rows.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.divider),
                          ),
                  ),
                  child: Row(
                    children: [
                      for (var c = 0; c < columns.length; c++)
                        Expanded(
                          flex: columns[c].flex,
                          child: Align(
                            alignment: _alignmentFor(columns[c].align),
                            child: c < rows[i].cells.length
                                ? rows[i].cells[c]
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          if (footer != null || pagination != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: footer == null
                        ? const SizedBox.shrink()
                        : Text(footer!, style: AppText.caption),
                  ),
                  ?pagination,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerCell(int index) {
    final column = columns[index];
    final style = AppText.overline.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );

    if (!column.sortable || onSort == null) {
      return Text(
        column.label.toUpperCase(),
        textAlign: column.align,
        style: style,
      );
    }

    final isSorted = sortColumnIndex == index;
    final icon = !isSorted
        ? Icons.unfold_more
        : (sortAscending ? Icons.arrow_upward : Icons.arrow_downward);

    return Align(
      alignment: _alignmentFor(column.align),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => onSort!(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  column.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: isSorted
                      ? style.copyWith(color: AppColors.textPrimary)
                      : style,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 14,
                color: isSorted ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Alignment _alignmentFor(TextAlign align) {
    switch (align) {
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }
}

/// Page controls for an [AdminTable] footer: ‹ 1 2 3 … 9 ›.
/// [page] is zero-based.
class AdminPagination extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  const AdminPagination({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  /// Page numbers to show (zero-based); `null` stands for a "…" gap.
  /// Always includes the first and last page and up to one page on each
  /// side of the current one.
  static List<int?> pageItems(int page, int pageCount) {
    if (pageCount <= 0) return const [];
    if (pageCount <= 7) return [for (var i = 0; i < pageCount; i++) i];

    final current = _limit(page, 0, pageCount - 1);
    final start = _limit(current - 1, 1, pageCount - 2);
    final end = _limit(current + 1, 1, pageCount - 2);

    return [
      0,
      if (start > 1) null,
      for (var i = start; i <= end; i++) i,
      if (end < pageCount - 2) null,
      pageCount - 1,
    ];
  }

  static int _limit(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    final current = _limit(page, 0, pageCount - 1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(
          Icons.chevron_left,
          'Previous page',
          current > 0 ? () => onPageChanged(current - 1) : null,
        ),
        for (final item in pageItems(current, pageCount))
          item == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('…', style: AppText.caption),
                )
              : _pageButton(item, item == current),
        _arrow(
          Icons.chevron_right,
          'Next page',
          current < pageCount - 1 ? () => onPageChanged(current + 1) : null,
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      color: AppColors.textSecondary,
      disabledColor: AppColors.textDisabled,
      onPressed: onPressed,
    );
  }

  Widget _pageButton(int index, bool selected) {
    final radius = BorderRadius.circular(6);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: selected ? null : () => onPageChanged(index),
          child: Container(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${index + 1}',
              style: AppText.value.copyWith(
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
