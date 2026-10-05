import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/modules/main_nav/controllers/main_nav_controller.dart';
import 'package:wister_lite/app/routes/app_pages.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';
import 'package:wister_lite/app/widgets/month_year_picker_sheet.dart';

import '../controllers/budget_controller.dart';

class BudgetView extends GetView<BudgetController> {
  const BudgetView({super.key});

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
                title: 'Anggaran',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _monthSwitcher(context, month),
                    IconButton(
                      icon: const Icon(AppIcons.tag),
                      tooltip: 'Kelola kategori',
                      onPressed: () async {
                        await Get.toNamed(Routes.CATEGORY_LIST);
                        MainNavController.refreshAll();
                      },
                    ),
                  ],
                ),
              ),
              ..._content(context),
              // Ruang untuk FAB tengah.
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
          child: SkeletonList(itemCount: 4, shape: SkeletonShape.budget, padding: EdgeInsets.all(AppSpacing.page)),
        ),
      ];
    }
    if (controller.categories.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState.kategori(onAction: () => Get.toNamed(Routes.CATEGORY_CREATE)?.then((_) => controller.loadData())),
        ),
      ];
    }

    final withBudget = controller.categoriesWithBudget;
    final without = controller.categoriesWithoutBudget;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, 0),
        sliver: SliverList.list(
          children: [
            if (withBudget.isEmpty)
              EmptyState.anggaran(illustrationSize: 120, onAction: () => _openSheet(context, without.first))
            else ...[
              _RemainingCard(controller: controller),
              const SizedBox(height: AppSpacing.section),
              _SectionTitle(
                'Kategori',
                trailing: without.isEmpty
                    ? null
                    : TextButton.icon(
                        onPressed: () => _openSheet(context, without.first),
                        icon: const Icon(AppIcons.plus, size: 18),
                        label: const Text('Tambah'),
                      ),
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, c) in withBudget.indexed) ...[
                      if (i > 0) const Divider(indent: AppSpacing.card, endIndent: AppSpacing.card),
                      _BudgetTile(category: c, controller: controller, onTap: () => _openSheet(context, c)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Future<void> _openSheet(BuildContext context, Category category) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => _BudgetSheet(category: category, controller: controller),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
    child: Row(
      children: [
        Expanded(child: Semantics(header: true, child: Text(text, style: context.text.titleMedium))),
        ?trailing,
      ],
    ),
  );
}

/// Kartu "Sisa bulan ini" untuk semua kategori yang punya budget.
class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.controller});

  final BudgetController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final remaining = controller.remaining;
    final over = remaining < 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(over ? 'Lewat anggaran' : 'Sisa bulan ini', style: context.text.labelLarge?.copyWith(color: over ? c.danger : c.inkMuted)),
                      const SizedBox(height: AppSpacing.s4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: AmountText(
                          remaining.abs(),
                          size: AmountSize.large,
                          color: over ? c.danger : c.ink,
                          semanticsPrefix: over ? 'Lewat anggaran' : 'Sisa bulan ini',
                        ),
                      ),
                    ],
                  ),
                ),
                // Dompi hanya di momen aman, tidak saat over-budget.
                if (controller.allUnderPace) AppIllustration.dompi(DompiMood.bangga, size: 72, semanticLabel: 'Dompi bangga, semua anggaran aman'),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            // Penjelasan penanda pace lewat tooltip (ketuk bar), bukan caption permanen.
            Tooltip(
              message: 'Garis tegak = posisi hari ini di bulan ini',
              triggerMode: TooltipTriggerMode.tap,
              excludeFromSemantics: true,
              child: BudgetProgress.fromAmounts(
                used: controller.budgetedSpent,
                budget: controller.totalBudget,
                pace: controller.paceMarker,
                showRemaining: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris ringkas kategori ber-anggaran: nama + sisa, lalu bar dan detail nominal.
class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.category, required this.controller, required this.onTap});

  final Category category;
  final BudgetController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final budget = controller.budgetByCategory[category.id] ?? 0;
    final spent = controller.spendingByCategory[category.id] ?? 0;
    final remaining = budget - spent;
    final ratio = BudgetProgress.ratioOf(spent, budget);
    final status = BudgetProgress.statusOf(ratio, warningThreshold: context.components.budgetProgress.warningThreshold);
    final (statusText, statusColor) = switch (status) {
      BudgetStatus.safe => ('Sisa ${AppFormat.rupiah(remaining)}', c.ink),
      BudgetStatus.warning => ('Sisa ${AppFormat.rupiah(remaining)}', c.warning),
      BudgetStatus.over => ('Lewat ${AppFormat.rupiah(remaining)}', c.danger),
    };
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card, vertical: AppSpacing.s12),
          child: Row(
            children: [
              CategoryBlob(iconAsset: category.icon, color: category.color, size: CategoryBlobSize.small),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(category.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        // Nominal sudah dibacakan lewat semantics BudgetProgress.
                        ExcludeSemantics(
                          child: Text(statusText, style: AppTypography.amountSmall.copyWith(color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    BudgetProgress.fromAmounts(used: spent, budget: budget, pace: controller.paceMarker, showDetails: false),
                    const SizedBox(height: AppSpacing.s4),
                    ExcludeSemantics(
                      child: Text(
                        '${AppFormat.rupiah(spent)} dari ${AppFormat.rupiah(budget)}',
                        style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet atur budget: konteks pengeluaran bulan ini + nominal via keypad.
class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({required this.category, required this.controller});

  final Category category;
  final BudgetController controller;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late Category _category = widget.category;
  late int _amount = _current.round();

  double get _current => widget.controller.budgetByCategory[_category.id] ?? 0;

  /// Kategori yang bisa dipilih: hanya saat menambah anggaran baru.
  late final List<Category> _choices = _current > 0 ? const [] : widget.controller.categoriesWithoutBudget;

  Future<void> _save(double amount) async {
    await widget.controller.setBudget(_category.id, amount);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickCategory() async {
    final picked = await AppSheet.show<Category>(
      context,
      title: 'Pilih kategori',
      child: _CategoryPicker(categories: _choices, selectedId: _category.id),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _category = picked;
      _amount = _current.round();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spent = widget.controller.spendingByCategory[_category.id] ?? 0;
    return AppSheet(
      title: 'Anggaran ${_category.label}',
      subtitle: 'Terpakai bulan ini ${AppFormat.rupiah(spent)}',
      leading: CategoryBlob(iconAsset: _category.icon, color: _category.color, size: CategoryBlobSize.large),
      trailing: _choices.length > 1 ? TextButton(onPressed: _pickCategory, child: const Text('Ganti')) : null,
      primaryLabel: 'Simpan anggaran',
      onPrimary: _amount > 0 ? () => _save(_amount.toDouble()) : null,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AmountText(_amount, size: AmountSize.display, color: _amount == 0 ? c.inkMuted : null, semanticsPrefix: 'Anggaran'),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            AmountKeypad(value: _amount, onChanged: (v) => setState(() => _amount = v)),
            if (_current > 0) ...[
              const SizedBox(height: AppSpacing.s8),
              TextButton.icon(
                onPressed: () => _save(0),
                style: TextButton.styleFrom(foregroundColor: c.danger),
                icon: const Icon(AppIcons.trash),
                label: const Text('Hapus anggaran'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grid kategori yang belum punya anggaran; bisa di-scroll berapa pun jumlahnya.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.categories, required this.selectedId});

  final List<Category> categories;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GridView.builder(
      shrinkWrap: true,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisExtent: 104,
        crossAxisSpacing: AppSpacing.s8,
        mainAxisSpacing: AppSpacing.s8,
      ),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final selected = cat.id == selectedId;
        return Semantics(
          button: true,
          selected: selected,
          label: cat.label,
          excludeSemantics: true,
          child: Material(
            color: selected ? c.brandContainer : c.surfaceContainerLow,
            borderRadius: AppRadius.inputAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(cat),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CategoryBlob(iconAsset: cat.icon, color: cat.color, size: CategoryBlobSize.large),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      cat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.text.labelMedium?.copyWith(color: selected ? c.onBrandContainer : c.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
