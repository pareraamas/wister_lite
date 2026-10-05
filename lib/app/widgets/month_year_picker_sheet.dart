import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

/// Pemilih bulan & tahun (dibuka dari chip [MonthSwitcher]).
Future<DateTime?> showMonthYearPickerSheet(BuildContext context, DateTime initialMonth) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => _MonthYearPickerSheet(initialMonth: initialMonth),
  );
}

class _MonthYearPickerSheet extends StatefulWidget {
  const _MonthYearPickerSheet({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _year = widget.initialMonth.year;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppSheet(
      title: 'Pilih bulan'.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setState(() => _year--),
                tooltip: 'Tahun sebelumnya'.tr,
                icon: const Icon(AppIcons.caretLeft),
              ),
              Text('$_year', style: context.text.titleLarge?.copyWith(fontFeatures: AppTypography.tabular)),
              IconButton(
                onPressed: () => setState(() => _year++),
                tooltip: 'Tahun berikutnya'.tr,
                icon: const Icon(AppIcons.caretRight),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisExtent: 52,
                mainAxisSpacing: AppSpacing.s8,
                crossAxisSpacing: AppSpacing.s8,
              ),
              itemBuilder: (context, index) {
                final month = DateTime(_year, index + 1);
                final selected = _year == widget.initialMonth.year && index + 1 == widget.initialMonth.month;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: AppFormat.monthYear(month),
                  excludeSemantics: true,
                  child: Material(
                    color: selected ? c.brand : c.surfaceContainerLowest,
                    shape: StadiumBorder(side: BorderSide(color: selected ? c.brand : c.outlineVariant)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(month),
                      child: Center(
                        child: Text(
                          AppFormat.monthsShort[index],
                          style: context.text.labelLarge?.copyWith(color: selected ? c.onBrand : c.ink),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
