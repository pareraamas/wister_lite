import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/models/transaction_filter.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';
import 'package:wister_lite/app/ults/clock.dart';
import 'package:wister_lite/app/ults/curency_formatter.dart';
import 'package:wister_lite/app/ults/date_formatter.dart';
import 'package:wister_lite/app/ults/string_currency_parsing.dart';

import '../controllers/transaction_history_controller.dart';

class TransactionHistoryView extends GetView<TransactionHistoryController> {
  const TransactionHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Riwayat Transaksi'.tr)),
      body: RefreshIndicator(
        onRefresh: controller.reload,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 240) controller.loadMore();
            return false;
          },
          child: Obx(
            () => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, 0),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _SearchField(controller: controller)),
                          const SizedBox(width: AppSpacing.s8),
                          _FilterButton(controller: controller),
                        ],
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: _ActiveFilters(controller: controller)),
                if (!controller.isLoading.value && controller.items.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s4, AppSpacing.page, 0),
                    sliver: SliverToBoxAdapter(child: _Summary(totals: controller.totals.value)),
                  ),
                ..._list(context),
                if (controller.isLoadingMore.value)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.page),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _list(BuildContext context) {
    if (controller.isLoading.value) {
      return const [SliverToBoxAdapter(child: SkeletonList(itemCount: 6, padding: EdgeInsets.all(AppSpacing.page)))];
    }
    final items = controller.items;
    if (items.isEmpty) {
      final f = controller.filter.value;
      return [
        SliverToBoxAdapter(
          child: f.isActive
              ? EmptyState(
                  illustration: AppIllustrations.emptyStatistik,
                  title: 'Tidak ada yang cocok'.tr,
                  message: 'Coba ubah atau hapus filternya.'.tr,
                  actionLabel: 'Hapus filter'.tr,
                  onAction: controller.resetFilters,
                  illustrationSize: 140,
                )
              : EmptyState.beranda(illustrationSize: 140),
        ),
      ];
    }

    // Urutan nominal: daftar rata dengan tanggal di tiap baris.
    if (!controller.filter.value.sort.byDate) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s12, AppSpacing.page, 0),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
            itemBuilder: (context, i) => _tile(context, items[i], showDate: true),
          ),
        ),
      ];
    }

    final groups = <DateTime, List<Expense>>{};
    for (final e in items) {
      groups.putIfAbsent(DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day), () => []).add(e);
    }
    return [
      for (final entry in groups.entries)
        SliverMainAxisGroup(
          slivers: [
            PinnedHeaderSliver(
              child: DateGroupHeader(
                label: entry.key.toHumanReadable(),
                net: entry.value.fold(0.0, (sum, e) => sum + (e.transactionType == 'income' ? e.price : -e.price)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              sliver: SliverList.separated(
                itemCount: entry.value.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
                itemBuilder: (context, i) => _tile(context, entry.value[i]),
              ),
            ),
          ],
        ),
    ];
  }

  Widget _tile(BuildContext context, Expense expense, {bool showDate = false}) {
    final category = expense.category;
    final isIncome = expense.transactionType == 'income';
    final hasNote = category == null || !category.matchesLabel(expense.name);
    return TransactionTile(
      dismissKey: ValueKey(expense.id),
      title: hasNote ? expense.name : category.label,
      categoryLabel: hasNote ? category?.label : null,
      amount: expense.price,
      kind: isIncome ? AmountKind.income : AmountKind.expense,
      categoryIcon: category?.icon ?? CategoryIcons.shoppingCart,
      categoryColor: category?.color ?? context.colors.inkMuted,
      dateLabel: showDate ? _dateShort(expense.dateTime) : null,
      onTap: () => controller.openEdit(expense),
      onDelete: () => controller.deleteExpense(expense),
    );
  }
}

String _dateShort(DateTime d) => d.year == Clock.now().year ? AppFormat.dayMonthShort(d) : '${AppFormat.dayMonthShort(d)} ${d.year}';

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TransactionHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.searchController,
      builder: (context, value, _) => TextField(
        controller: controller.searchController,
        onChanged: controller.onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari catatan atau kategori'.tr,
          prefixIcon: const Icon(AppIcons.magnifyingGlass),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(tooltip: 'Hapus pencarian'.tr, onPressed: controller.clearSearch, icon: const Icon(AppIcons.x)),
        ),
      ),
    );
  }
}

/// Tombol Filter di samping kolom cari, dengan jumlah filter aktif.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final TransactionHistoryController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final f = controller.filter.value;
    final n = f.copyWith(query: '').activeCount + (f.sort == TransactionSort.newest ? 0 : 1);
    return Badge(
      isLabelVisible: n > 0,
      label: Text('$n'),
      child: IconButton.filledTonal(
        tooltip: n > 0 ? 'Filter, @n aktif'.trParams({'n': '$n'}) : 'Filter'.tr,
        onPressed: () => _openFilterSheet(context, controller),
        icon: const Icon(AppIcons.funnelSimple),
      ),
    );
  });
}

Future<void> _openFilterSheet(BuildContext context, TransactionHistoryController controller) async {
  final result = await AppSheet.show<TransactionFilter>(
    context,
    title: 'Filter'.tr,
    child: _FilterSheet(controller: controller),
  );
  if (result != null) controller.applyFilter(result);
}

/// Filter yang sedang aktif sebagai chip; ketuk untuk ubah, ✕ untuk lepas.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller});

  final TransactionHistoryController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final f = controller.filter.value;
    final cats = controller.categories;
    final chips = <(String, VoidCallback)>[
      if (f.transactionType != null) (f.transactionType == 'income' ? 'Pemasukan'.tr : 'Pengeluaran'.tr, () => controller.setType(null)),
      if (f.hasPeriod) (_periodLabel(f.start, f.end), () => controller.setPeriod(null, null)),
      if (f.categoryIds.isNotEmpty)
        (
          f.categoryIds.length == 1
              ? cats.firstWhereOrNull((c) => c.id == f.categoryIds.first)?.label ?? '1 kategori'.tr
              : '@n kategori'.trParams({'n': '${f.categoryIds.length}'}),
          () => controller.setCategories(const {}),
        ),
      if (f.hasAmount) (_amountLabel(f.minAmount, f.maxAmount), () => controller.setAmount(null, null)),
      if (f.sort != TransactionSort.newest) (f.sort.label, () => controller.setSort(TransactionSort.newest)),
    ];
    if (chips.isEmpty) return const SizedBox(height: AppSpacing.s8);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.stack, AppSpacing.page, AppSpacing.s8),
      child: Row(
        children: [
          for (final (label, onRemove) in chips)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s8),
              child: InputChip(
                label: Text(label),
                onPressed: () => _openFilterSheet(context, controller),
                onDeleted: onRemove,
                deleteButtonTooltipMessage: 'Hapus filter @label'.trParams({'label': label}),
                deleteIcon: const Icon(AppIcons.x, size: 16),
              ),
            ),
          if (chips.length > 1) TextButton(onPressed: controller.resetFilters, child: Text('Reset'.tr)),
        ],
      ),
    );
  });
}

String _day(DateTime d) => '${AppFormat.dayMonthShort(d)} ${d.year}';

String _periodLabel(DateTime? start, DateTime? end) {
  if (start == null) return 'Sampai @date'.trParams({'date': _day(end!)});
  if (end == null) return 'Sejak @date'.trParams({'date': _day(start)});
  final lastOfMonth = DateTime(start.year, start.month + 1, 0);
  if (start.day == 1 && DateUtils.isSameDay(end, lastOfMonth)) return AppFormat.monthYearShort(start);
  if (DateUtils.isSameDay(start, end)) return _day(start);
  final from = start.year == end.year ? AppFormat.dayMonthShort(start) : _day(start);
  return '$from – ${_day(end)}';
}

String _amountLabel(double? min, double? max) => switch ((min, max)) {
  (final min?, final max?) => '${AppFormat.rupiah(min)} – ${AppFormat.rupiah(max)}',
  (final min?, null) => '≥ ${AppFormat.rupiah(min)}',
  (null, final max?) => '≤ ${AppFormat.rupiah(max)}',
  _ => '',
};

/// Semua filter dalam satu sheet. Perubahan baru berlaku setelah "Tampilkan".
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.controller});

  final TransactionHistoryController controller;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  final _formatter = CureencyFormatter();
  late TransactionFilter _draft = widget.controller.filter.value;
  late final _min = TextEditingController(text: _format(_draft.minAmount));
  late final _max = TextEditingController(text: _format(_draft.maxAmount));

  /// Jumlah hasil draft; null selama dihitung.
  int? _count;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String _format(double? v) =>
      v == null ? '' : _formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: v.toStringAsFixed(0))).text;

  double? _parse(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.toDoubleFromRupiah();

  void _update(TransactionFilter f) {
    setState(() => _draft = f);
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final gen = ++_generation;
    setState(() => _count = null);
    final n = await widget.controller.countFor(_draft);
    if (mounted && gen == _generation) setState(() => _count = n);
  }

  void _onAmountChanged(String _) => _update(_draft.copyWith(minAmount: () => _parse(_min), maxAmount: () => _parse(_max)));

  void _reset() {
    _min.clear();
    _max.clear();
    _update(_draft.cleared().copyWith(query: _draft.query));
  }

  void _apply() {
    var (min, max) = (_draft.minAmount, _draft.maxAmount);
    if (min != null && max != null && min > max) (min, max) = (max, min);
    Navigator.pop(context, _draft.copyWith(minAmount: () => min, maxAmount: () => max));
  }

  @override
  Widget build(BuildContext context) {
    final f = _draft;
    final now = Clock.now();
    final presets = <(String, DateTime?, DateTime?)>[
      ('Semua'.tr, null, null),
      ('Bulan ini'.tr, DateTime(now.year, now.month), DateTime(now.year, now.month + 1, 0)),
      ('Bulan lalu'.tr, DateTime(now.year, now.month - 1), DateTime(now.year, now.month, 0)),
      ('3 bulan terakhir'.tr, DateTime(now.year, now.month - 2), DateTime(now.year, now.month + 1, 0)),
      ('Tahun ini'.tr, DateTime(now.year), DateTime(now.year, 12, 31)),
    ];
    bool sameDay(DateTime? a, DateTime? b) => a == null ? b == null : b != null && DateUtils.isSameDay(a, b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              _SectionLabel('Jenis'.tr),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'all', label: Text('Semua'.tr)),
                  ButtonSegment(value: 'income', label: Text('Pemasukan'.tr)),
                  ButtonSegment(value: 'expense', label: Text('Pengeluaran'.tr)),
                ],
                selected: {f.transactionType ?? 'all'},
                onSelectionChanged: (s) => _update(f.copyWith(transactionType: () => s.first == 'all' ? null : s.first)),
              ),
              _SectionLabel('Rentang tanggal'.tr),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  for (final (label, s, e) in presets)
                    ChoiceChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(label),
                      selected: sameDay(f.start, s) && sameDay(f.end, e),
                      onSelected: (_) => _update(f.withPeriod(s, e)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.stack),
              Row(
                children: [
                  Expanded(
                    child: _DateField(label: 'Dari'.tr, value: f.start, lastDate: f.end, onChanged: (d) => _update(f.withPeriod(d, f.end))),
                  ),
                  const SizedBox(width: AppSpacing.stack),
                  Expanded(
                    child: _DateField(label: 'Sampai'.tr, value: f.end, firstDate: f.start, onChanged: (d) => _update(f.withPeriod(f.start, d))),
                  ),
                ],
              ),
              _SectionLabel('Kategori'.tr),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  for (final c in widget.controller.categories)
                    FilterChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: CircleAvatar(backgroundColor: c.color, radius: 6),
                      labelPadding: const EdgeInsetsDirectional.only(start: AppSpacing.s2, end: AppSpacing.s4),
                      label: Text(c.label),
                      showCheckmark: false,
                      selected: f.categoryIds.contains(c.id),
                      onSelected: (on) => _update(f.copyWith(categoryIds: on ? {...f.categoryIds, c.id} : ({...f.categoryIds}..remove(c.id)))),
                    ),
                ],
              ),
              _SectionLabel('Nominal'.tr),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_formatter],
                      textInputAction: TextInputAction.next,
                      onChanged: _onAmountChanged,
                      decoration: InputDecoration(labelText: 'Minimal'.tr, hintText: 'Rp. 0'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.stack),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_formatter],
                      onChanged: _onAmountChanged,
                      decoration: InputDecoration(labelText: 'Maksimal'.tr, hintText: 'Rp. 0'),
                    ),
                  ),
                ],
              ),
              _SectionLabel('Urutkan'.tr),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  for (final s in TransactionSort.values)
                    ChoiceChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(s.label),
                      selected: f.sort == s,
                      onSelected: (_) => _update(f.copyWith(sort: s)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _reset, child: Text('Reset'.tr)),
            ),
            const SizedBox(width: AppSpacing.stack),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _apply,
                child: Text(_count == null ? 'Terapkan'.tr : 'Tampilkan @n transaksi'.trParams({'n': '$_count'})),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.section, bottom: AppSpacing.s8),
    child: Semantics(
      header: true,
      child: Text(text, style: context.text.titleSmall?.copyWith(color: context.colors.ink)),
    ),
  );
}

/// Kolom tanggal yang membuka date picker; ✕ mengosongkan (rentang terbuka).
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onChanged, this.firstDate, this.lastDate});

  final String label;
  final DateTime? value;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final first = DateUtils.dateOnly(firstDate ?? DateTime(2000));
    final last = DateUtils.dateOnly(lastDate ?? DateTime(2100));
    var initial = DateUtils.dateOnly(value ?? Clock.now());
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      currentDate: Clock.now(),
      helpText: label,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: AppRadius.fullAll,
      child: InputDecorator(
        isEmpty: v == null,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: v == null
              ? const Icon(AppIcons.calendarBlank)
              : IconButton(tooltip: 'Kosongkan @label'.trParams({'label': label}), onPressed: () => onChanged(null), icon: const Icon(AppIcons.x)),
        ),
        child: Text(v == null ? '' : _day(v), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Jumlah transaksi yang cocok beserta total masuk & keluarnya.
class _Summary extends StatelessWidget {
  const _Summary({required this.totals});

  final TransactionTotals totals;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@n transaksi'.trParams({'n': '${totals.count}'}), style: context.text.labelLarge?.copyWith(color: c.inkMuted)),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                Expanded(
                  child: _SummaryAmount(label: 'Masuk'.tr, amount: totals.income, kind: AmountKind.income),
                ),
                const SizedBox(width: AppSpacing.stack),
                Expanded(
                  child: _SummaryAmount(label: 'Keluar'.tr, amount: totals.expense, kind: AmountKind.expense),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({required this.label, required this.amount, required this.kind});

  final String label;
  final double amount;
  final AmountKind kind;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.text.bodySmall?.copyWith(color: context.colors.inkMuted)),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: AmountText(amount, kind: kind, semanticsPrefix: label),
      ),
    ],
  );
}
