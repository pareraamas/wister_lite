import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/services/transaction_export.dart';
import 'package:wister_lite/app/modules/home/controllers/home_controller.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';
import 'package:wister_lite/app/widgets/month_year_picker_sheet.dart';

import '../controllers/statistik_controller.dart';
import 'package:wister_lite/app/translations/tr_context.dart';

class StatistikView extends GetView<StatistikController> {
  const StatistikView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        final month = controller.selectedMonth.value;
        return RefreshIndicator(
          onRefresh: controller.loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              PageAppBar(
                title: 'Statistik'.tr,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _monthSwitcher(context, month),
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(AppIcons.dotsThreeVertical),
                        tooltip: 'Export & bagikan'.tr,
                        onPressed: () => _showExportSheet(context),
                      ),
                    ),
                  ],
                ),
              ),
              ..._content(context),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        );
      }),
    );
  }

  Widget _monthSwitcher(BuildContext context, DateTime month) {
    return MonthSwitcher(
      month: month,
      onPrev: controller.goToPreviousMonth,
      onNext: controller.goToNextMonth,
      onTap: () async {
        final picked = await showMonthYearPickerSheet(context, month);
        if (picked != null) controller.setMonth(picked);
      },
    );
  }

  List<Widget> _content(BuildContext context) {
    if (controller.isLoading.value) {
      return const [
        SliverToBoxAdapter(
          child: SkeletonList(itemCount: 3, shape: SkeletonShape.card, padding: EdgeInsets.all(AppSpacing.page)),
        ),
      ];
    }
    final hasAny = controller.totalIncome.value > 0 || controller.totalExpense.value > 0;
    if (!hasAny) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState.statistik(
            onAction: () {
              if (Get.isRegistered<HomeController>()) Get.find<HomeController>().openCreate();
            },
          ),
        ),
      ];
    }

    final slices = controller.donutSlices;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, 0),
        sliver: SliverList.list(
          children: [
            _Totals(controller: controller),
            const SizedBox(height: AppSpacing.section),
            Semantics(header: true, child: Text('Pengeluaran per kategori'.tr, style: context.text.titleMedium)),
            const SizedBox(height: AppSpacing.s12),
            if (slices.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.card),
                  child: Text('Belum ada pengeluaran bulan ini.'.tr, style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted)),
                ),
              )
            else ...[
              _Donut(slices: slices, total: controller.totalExpense.value, key: ValueKey(controller.selectedMonth.value)),
              const SizedBox(height: AppSpacing.section),
              for (var i = 0; i < slices.length; i++) ...[
                _RankRow(rank: i + 1, slice: slices[i], share: controller.shareOf(slices[i].amount)),
                const SizedBox(height: AppSpacing.s8),
              ],
            ],
          ],
        ),
      ),
    ];
  }
}

/// Menu ⋮ Statistik: bagikan gambar, export (bulan terpilih / semua), dan
/// import. [anchor] = tombol pemicu, jadi jangkar share sheet di iPad.
void _showExportSheet(BuildContext anchor) {
  AppSheet.show<void>(
    anchor,
    title: 'Export & bagikan'.tr,
    child: _ExportSheet(origin: _originOf(anchor)),
  );
}

Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.origin});

  final Rect? origin;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _allTime = false;

  StatistikController get _controller => Get.find<StatistikController>();

  Widget _option(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: context.colors.brand),
    title: Text(title),
    subtitle: Text(subtitle, style: context.text.bodySmall?.copyWith(color: context.colors.inkMuted)),
    contentPadding: EdgeInsets.zero,
    onTap: () {
      Navigator.of(context).pop();
      onTap();
    },
  );

  void _export(ExportFormat format) => _controller.export(format, allTime: _allTime, origin: widget.origin);

  @override
  Widget build(BuildContext context) {
    final month = _controller.selectedMonth.value;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _option(
            AppIcons.image,
            'Bagikan sebagai gambar'.tr,
            'Kartu ringkasan @month untuk Story atau Feed'.trParams({'month': AppFormat.monthYear(month)}),
            _controller.openShareCard,
          ),
          const Divider(height: AppSpacing.s24),
          Semantics(header: true, child: Text('Export data'.tr, style: context.text.titleSmall)),
          const SizedBox(height: AppSpacing.s8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(AppFormat.monthYearShort(month))),
              ButtonSegment(value: true, label: Text('Semua'.trIn('period'))),
            ],
            selected: {_allTime},
            onSelectionChanged: (s) => setState(() => _allTime = s.first),
          ),
          const SizedBox(height: AppSpacing.s4),
          _option(AppIcons.fileXls, 'Excel (.xlsx)', 'Sheet transaksi + ringkasan per kategori'.tr, () => _export(ExportFormat.excel)),
          _option(AppIcons.filePdf, 'Laporan PDF'.tr, 'Siap dicetak atau dikirim'.tr, () => _export(ExportFormat.pdf)),
          _option(AppIcons.fileCsv, 'CSV', 'Untuk Google Sheets atau aplikasi lain'.tr, () => _export(ExportFormat.csv)),
          const Divider(height: AppSpacing.s24),
          _option(AppIcons.downloadSimple, 'Import dari CSV / Excel'.tr, 'Formatnya sama dengan file hasil export'.tr, _controller.pickImportFile),
        ],
      ),
    );
  }
}

Color _sliceColor(BuildContext context, DonutSlice s) => s.category?.color ?? context.colors.outline;

class _Totals extends StatelessWidget {
  const _Totals({required this.controller});

  final StatistikController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(String label, num amount, AmountKind kind, {Color? color}) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
              const SizedBox(height: AppSpacing.s4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: AmountText(amount, kind: kind, color: color, semanticsPrefix: label),
              ),
            ],
          ),
        ),
      ),
    );

    final balance = controller.balance;
    return Row(
      children: [
        item('Masuk'.tr, controller.totalIncome.value, AmountKind.income),
        const SizedBox(width: AppSpacing.s8),
        item('Keluar'.tr, controller.totalExpense.value, AmountKind.expense),
        const SizedBox(width: AppSpacing.s8),
        item('Selisih'.tr, balance, AmountKind.neutral, color: balance < 0 ? c.danger : null),
      ],
    );
  }
}

/// Donut maksimal 6 irisan + "Lainnya", total di tengah. Irisan tumbuh dari
/// tengah saat pertama tampil (diganti langsung jika animasi dimatikan).
class _Donut extends StatefulWidget {
  const _Donut({super.key, required this.slices, required this.total});

  final List<DonutSlice> slices;
  final double total;

  @override
  State<_Donut> createState() => _DonutState();
}

class _DonutState extends State<_Donut> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final touched = _touched != null && _touched! < widget.slices.length ? widget.slices[_touched!] : null;
    final centerLabel = touched?.label ?? 'Total keluar'.tr;
    final centerAmount = touched?.amount ?? widget.total;

    Widget chart(double grow) => PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 64,
        startDegreeOffset: -90,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            final index = event.isInterestedForInteractions ? response?.touchedSection?.touchedSectionIndex : null;
            if (index != _touched) setState(() => _touched = index != null && index >= 0 ? index : null);
          },
        ),
        sections: [
          for (var i = 0; i < widget.slices.length; i++)
            PieChartSectionData(
              value: widget.slices[i].amount,
              color: _sliceColor(context, widget.slices[i]),
              radius: (i == _touched ? 36.0 : 28.0) * grow,
              showTitle: false,
            ),
        ],
      ),
      duration: AppMotion.medium,
    );

    return Semantics(
      label: 'Donut pengeluaran: @items'.trParams({'items': [for (final s in widget.slices) '${s.label} ${AppFormat.rupiah(s.amount)}'].join(', ')}),
      excludeSemantics: true,
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppMotion.reduced(context)
                ? chart(1)
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppMotion.long,
                    curve: AppMotion.emphasized,
                    builder: (_, v, _) => chart(v),
                  ),
            SizedBox(
              width: 116,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AmountText(centerAmount, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.slice, required this.share});

  final int rank;
  final DonutSlice slice;
  final double share;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _sliceColor(context, slice);
    final category = slice.category;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$rank',
                    style: context.text.labelLarge?.copyWith(color: c.inkMuted, fontFeatures: AppTypography.tabular),
                  ),
                ),
                if (category != null)
                  CategoryBlob(iconAsset: category.icon, color: category.color, size: CategoryBlobSize.small)
                else
                  SizedBox.square(
                    dimension: 32,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: c.surfaceContainerHighest, shape: BoxShape.circle),
                    ),
                  ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: Text(slice.label, style: context.text.titleSmall)),
                Text(
                  '${(share * 100).round()}%',
                  style: context.text.labelLarge?.copyWith(color: c.inkMuted, fontFeatures: AppTypography.tabular),
                ),
                const SizedBox(width: AppSpacing.s12),
                AmountText(slice.amount, semanticsPrefix: slice.label),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            ClipRRect(
              borderRadius: AppRadius.fullAll,
              child: LinearProgressIndicator(value: share, minHeight: 6, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
