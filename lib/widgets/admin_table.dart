import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// One column of an [AdminTable].
class AdminColumn {
  final String label;
  final int flex;
  final TextAlign align;

  const AdminColumn(this.label, {this.flex = 1, this.align = TextAlign.left});
}

/// One row of an [AdminTable]. [cells] must match the number of columns.
class AdminRow {
  final List<Widget> cells;
  final VoidCallback? onTap;

  const AdminRow({required this.cells, this.onTap});
}

/// Desktop table in the Figma "Reservation List" style: white card,
/// uppercase grey header, divided rows.
class AdminTable extends StatelessWidget {
  final List<AdminColumn> columns;
  final List<AdminRow> rows;
  final String? footer;

  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
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
                for (final column in columns)
                  Expanded(
                    flex: column.flex,
                    child: Text(
                      column.label.toUpperCase(),
                      textAlign: column.align,
                      style: AppText.overline.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Rows
          for (var i = 0; i < rows.length; i++)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: rows[i].onTap,
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

          if (footer != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Text(footer!, style: AppText.caption),
            ),
        ],
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
