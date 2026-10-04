import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';
import 'package:wister_lite/app/ults/clock.dart';

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  /// Ruang bawah agar item terakhir tidak tertutup FAB tengah.
  static const _fabClearance = 96.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: controller.onRefresh,
        child: Obx(
          () => CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              PageAppBar(
                title: controller.greeting,
                trailing: _MoreMenu(controller: controller),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 0),
                sliver: SliverList.list(
                  children: [
                    Text('Jangan lupa catat keuanganmu hari ini.', style: context.text.bodySmall?.copyWith(color: context.colors.inkMuted)),
                    const SizedBox(height: AppSpacing.s20),
                    BalanceCard(amount: controller.totalBalance.value, caption: 'Semua pemasukan dikurangi pengeluaran'),
                    const SizedBox(height: AppSpacing.stack),
                    Row(
                      children: [
                        Expanded(
                          child: _MonthTotal(label: 'Masuk bulan ini', amount: controller.totalIncomeMonth.value, kind: AmountKind.income),
                        ),
                        const SizedBox(width: AppSpacing.stack),
                        Expanded(
                          child: _MonthTotal(label: 'Keluar bulan ini', amount: controller.totalOutcomeMonth.value, kind: AmountKind.expense),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stack),
                    _TodayRow(amount: controller.totalOutcomeDay.value),
                    const SizedBox(height: AppSpacing.stack),
                    _BudgetSummaryCard(
                      used: controller.budgetedSpent,
                      budget: controller.totalBudget,
                      alertCount: controller.budgetAlertCount,
                      onTap: controller.openBudget,
                    ),
                    if (controller.last7Days.length == 7) ...[
                      const SizedBox(height: AppSpacing.stack),
                      _TrendCard(days: controller.last7Days, dailyAverage: controller.dailyAverage, monthChange: controller.monthChange),
                    ],
                    if (controller.topCategories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.stack),
                      _TopCategoriesCard(
                        items: controller.topCategories,
                        monthTotal: controller.totalOutcomeMonth.value,
                        onTap: controller.openStatistik,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    _HistoryHeader(onTap: controller.openHistory),
                  ],
                ),
              ),
              ..._history(context),
              const SliverToBoxAdapter(child: SizedBox(height: _fabClearance)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _history(BuildContext context) {
    if (controller.isLoading.value) {
      return const [SliverToBoxAdapter(child: SkeletonList(itemCount: 3, padding: EdgeInsets.all(AppSpacing.page)))];
    }
    final today = controller.todayExpenses;
    if (today.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            illustration: AppIllustrations.hariIniKosong,
            title: 'Belum ada transaksi hari ini',
            message: 'Catat pemasukan atau pengeluaranmu hari ini.',
            actionLabel: 'Tambah',
            onAction: controller.openCreate,
            illustrationSize: 120,
          ),
        ),
      ];
    }

    final reduced = AppMotion.reduced(context);
    final shown = today.take(HomeController.todayLimit).toList();
    final more = today.length - shown.length;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        sliver: SliverList.separated(
          itemCount: shown.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
          itemBuilder: (context, i) {
            final tile = _tile(context, shown[i]);
            if (reduced) return tile;
            // Masuk bertahap 40 ms per item.
            return tile
                .animate(delay: AppMotion.stagger * i)
                .fadeIn(duration: AppMotion.medium, curve: AppMotion.standard)
                .slideY(begin: 0.08, end: 0, duration: AppMotion.medium, curve: AppMotion.standard);
          },
        ),
      ),
      if (more > 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Center(
              child: TextButton(onPressed: controller.openHistory, child: Text('Lihat $more transaksi lainnya')),
            ),
          ),
        ),
    ];
  }

  Widget _tile(BuildContext context, Expense expense) {
    final category = expense.category;
    final isIncome = expense.transactionType == 'income';
    final hasNote = category == null || expense.name != category.label;
    return TransactionTile(
      dismissKey: ValueKey(expense.id),
      title: hasNote ? expense.name : category.label,
      categoryLabel: hasNote ? category?.label : null,
      amount: expense.price,
      kind: isIncome ? AmountKind.income : AmountKind.expense,
      categoryIcon: category?.icon ?? CategoryIcons.shoppingCart,
      categoryColor: category?.color ?? context.colors.inkMuted,
      onTap: () => controller.openEdit(expense),
      onDelete: () => controller.deleteExpense(expense),
    );
  }
}

/// Label bulan aktif: ringkasan Masuk/Keluar di bawah selalu bulan ini.
/// Tombol "lainnya" di header: pilihan bahasa dan mode tema.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.controller});

  final HomeController controller;

  static const _locales = [(Locale('id', 'ID'), 'Bahasa Indonesia'), (Locale('en', 'US'), 'English')];
  static const _modes = [
    (ThemeMode.light, 'Terang', AppIcons.sun),
    (ThemeMode.dark, 'Gelap', AppIcons.moon),
    (ThemeMode.system, 'Ikuti sistem', AppIcons.monitor),
  ];

  @override
  Widget build(BuildContext context) => PopupMenuButton<Object>(
    icon: const Icon(AppIcons.dotsThreeVertical),
    tooltip: 'Lainnya',
    onSelected: (value) => switch (value) {
      Locale l => controller.changeLocale(l),
      ThemeMode m => controller.changeThemeMode(m),
      _ => null,
    },
    itemBuilder: (context) => [
      _header(context, 'Bahasa'),
      for (final (locale, label) in _locales)
        _option(context, value: locale, label: label, icon: AppIcons.translate, selected: controller.locale.value == locale),
      const PopupMenuDivider(),
      _header(context, 'Tema'),
      for (final (mode, label, icon) in _modes)
        _option(context, value: mode, label: label, icon: icon, selected: controller.themeMode.value == mode),
    ],
  );

  PopupMenuEntry<Object> _header(BuildContext context, String label) => PopupMenuItem<Object>(
    enabled: false,
    height: 32,
    child: Text(label, style: context.text.labelMedium?.copyWith(color: context.colors.inkMuted)),
  );

  PopupMenuEntry<Object> _option(
    BuildContext context, {
    required Object value,
    required String label,
    required IconData icon,
    required bool selected,
  }) => PopupMenuItem<Object>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: selected ? context.colors.brand : context.colors.inkMuted),
        const SizedBox(width: AppSpacing.s12),
        Expanded(child: Text(label)),
        if (selected) Icon(AppIcons.check, size: 20, color: context.colors.brand),
      ],
    ),
  );
}

class _MonthTotal extends StatelessWidget {
  const _MonthTotal({required this.label, required this.amount, required this.kind});

  final String label;
  final double amount;
  final AmountKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final container = kind == AmountKind.income ? c.incomeContainer : c.expenseContainer;
    final onContainer = kind == AmountKind.income ? c.onIncomeContainer : c.onExpenseContainer;
    return Card(
      color: container,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.labelLarge?.copyWith(color: onContainer)),
            const SizedBox(height: AppSpacing.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: AmountText(amount, kind: kind, size: AmountSize.large, color: onContainer, semanticsPrefix: label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris "Hari ini" — totalnya sudah dihitung controller sejak dulu, kini tampil.
class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final empty = amount <= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card, vertical: AppSpacing.s12),
        child: Row(
          children: [
            if (empty) ...[AppIllustration(AppIllustrations.hariIniKosong, size: 40), const SizedBox(width: AppSpacing.s12)],
            Expanded(
              child: Text(
                empty ? 'Hari ini belum ada pengeluaran' : 'Keluar hari ini',
                style: context.text.bodyLarge?.copyWith(color: empty ? c.inkMuted : c.ink),
              ),
            ),
            if (!empty) AmountText(amount, kind: AmountKind.expense, semanticsPrefix: 'Keluar hari ini'),
          ],
        ),
      ),
    );
  }
}

/// Kartu yang bisa diketuk dengan judul + caret, dipakai ringkasan di beranda.
class _TappableCard extends StatelessWidget {
  const _TappableCard({required this.title, required this.onTap, required this.child, this.tooltip});

  final String title;
  final String? tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text(title, style: context.text.titleMedium)),
                ),
                Icon(AppIcons.caretRight, size: 20, color: context.colors.inkMuted, semanticLabel: tooltip),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Ringkasan anggaran bulan ini; tanpa budget = ajakan mengatur anggaran.
class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({required this.used, required this.budget, required this.alertCount, required this.onTap});

  final double used;
  final double budget;
  final int alertCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (budget <= 0) {
      return _row(
        context,
        leading: CircleAvatar(radius: 24, backgroundColor: c.brandContainer, child: Icon(AppIcons.target, color: c.onBrandContainer)),
        tooltip: 'Atur anggaran',
        children: [
          Text('Belum ada anggaran', style: context.text.bodySmall?.copyWith(color: c.inkMuted)),
          const SizedBox(height: AppSpacing.s2),
          Text('Atur anggaran bulan ini', style: context.text.bodyLarge?.copyWith(color: c.ink)),
        ],
      );
    }
    final tok = context.components.budgetProgress;
    final ratio = BudgetProgress.ratioOf(used, budget);
    final remaining = budget - used;
    final over = remaining < 0;
    final percent = ratio.isFinite ? (ratio * 100).round() : 100;
    final muted = context.text.bodySmall?.copyWith(color: c.inkMuted);
    return _row(
      context,
      tooltip: 'Lihat anggaran',
      // Cincin persen terpakai; warnanya mengikuti status anggaran.
      leading: SizedBox.square(
        dimension: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: ratio.isFinite ? ratio.clamp(0.0, 1.0) : 1,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: tok.colorFor(ratio),
              backgroundColor: tok.track,
            ),
            Center(child: Text('$percent%', style: context.text.labelSmall?.copyWith(color: c.ink, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
      children: [
        Text(over ? 'Lewat anggaran' : 'Sisa anggaran', style: muted),
        const SizedBox(height: AppSpacing.s2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: AmountText(remaining.abs(), color: over ? c.danger : c.ink, semanticsPrefix: over ? 'Lewat anggaran' : 'Sisa anggaran'),
        ),
        if (alertCount > 0) ...[
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(AppIconsFill.warning, size: 14, color: c.warning),
              const SizedBox(width: AppSpacing.s4),
              Flexible(child: Text('$alertCount kategori hampir habis', style: muted)),
            ],
          ),
        ],
      ],
    );
  }

  /// Kartu satu baris (seperti baris "Hari ini") yang bisa diketuk.
  Widget _row(BuildContext context, {required Widget leading, required String tooltip, required List<Widget> children}) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card, vertical: AppSpacing.s12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
            Icon(AppIcons.caretRight, size: 20, color: context.colors.inkMuted, semanticLabel: tooltip),
          ],
        ),
      ),
    ),
  );
}

class _TopCategoriesCard extends StatelessWidget {
  const _TopCategoriesCard({required this.items, required this.monthTotal, required this.onTap});

  final List<(Category, double)> items;
  final double monthTotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _TappableCard(
    title: 'Paling banyak keluar',
    tooltip: 'Lihat statistik',
    onTap: onTap,
    child: Column(
      children: [
        for (final (i, (category, amount)) in items.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s12),
          _TopCategoryRow(category: category, amount: amount, share: monthTotal > 0 ? amount / monthTotal : 0),
        ],
      ],
    ),
  );
}

class _TopCategoryRow extends StatelessWidget {
  const _TopCategoryRow({required this.category, required this.amount, required this.share});

  final Category category;
  final double amount;

  /// Porsi dari total pengeluaran bulan ini (0–1).
  final double share;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final percent = (share * 100).round();
    return Semantics(
      label: '${category.label}, ${AppFormat.spokenRupiah(amount)}, $percent persen pengeluaran bulan ini',
      excludeSemantics: true,
      child: Row(
        children: [
          CategoryBlob(iconAsset: category.icon, color: category.color, size: CategoryBlobSize.small),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(category.label, style: context.text.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: AppSpacing.s8),
                    AmountText(amount, kind: AmountKind.neutral, size: AmountSize.small),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: share.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: category.color,
                          backgroundColor: category.color.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text('$percent%', style: context.text.labelSmall?.copyWith(color: c.inkMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grafik batang pengeluaran 7 hari terakhir + rata-rata harian & pembanding bulan lalu.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.days, required this.dailyAverage, required this.monthChange});

  /// 7 nilai, indeks terakhir = hari ini.
  final List<double> days;
  final double dailyAverage;
  final double? monthChange;

  static const _chartHeight = 88.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = DateUtils.dateOnly(Clock.now());
    final max = days.fold(0.0, (a, b) => b > a ? b : a);
    final dates = [for (var i = 0; i < 7; i++) today.subtract(Duration(days: 6 - i))];
    final spoken = [for (var i = 0; i < 7; i++) '${AppFormat.dayMonthShort(dates[i])} ${AppFormat.spokenRupiah(days[i])}'].join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text('Pengeluaran 7 hari terakhir', style: context.text.titleMedium)),
            const SizedBox(height: AppSpacing.s12),
            Semantics(
              label: 'Grafik pengeluaran 7 hari terakhir: $spoken',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _DayBar(
                        date: dates[i],
                        amount: days[i],
                        ratio: max > 0 ? days[i] / max : 0,
                        isToday: i == 6,
                        height: _chartHeight,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Divider(height: 1, color: c.outlineVariant),
            const SizedBox(height: AppSpacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Rata-rata/hari bulan ini',
                    child: AmountText(dailyAverage, kind: AmountKind.neutral, size: AmountSize.small, semanticsPrefix: 'Rata-rata per hari'),
                  ),
                ),
                if (monthChange case final change?) ...[
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: _MonthChange(change: change)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.date, required this.amount, required this.ratio, required this.isToday, required this.height});

  final DateTime date;
  final double amount;
  final double ratio;
  final bool isToday;
  final double height;

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final barHeight = amount > 0 ? (height * ratio).clamp(4.0, height) : 2.0;
    return Tooltip(
      message: '${isToday ? 'Hari ini' : AppFormat.dayMonthShort(date)}: ${AppFormat.rupiah(amount)}',
      triggerMode: TooltipTriggerMode.tap,
      child: Column(
        children: [
          // Area sentuh setinggi grafik, lebih besar dari batangnya.
          SizedBox(
            height: height,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 20,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                decoration: BoxDecoration(
                  color: amount > 0 ? (isToday ? c.brand : c.brand.withValues(alpha: 0.45)) : c.outlineVariant,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            _days[date.weekday - 1],
            style: context.text.labelSmall?.copyWith(color: isToday ? c.ink : c.inkMuted, fontWeight: isToday ? FontWeight.w700 : null),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.text.bodySmall?.copyWith(color: context.colors.inkMuted)),
      const SizedBox(height: AppSpacing.s4),
      child,
    ],
  );
}

/// "12% lebih hemat" / "12% lebih boros" dibanding tanggal yang sama bulan lalu.
class _MonthChange extends StatelessWidget {
  const _MonthChange({required this.change});

  final double change;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final percent = (change.abs() * 100).round();
    final saving = change <= 0;
    final text = percent == 0 ? 'Sama seperti bulan lalu' : '$percent% lebih ${saving ? 'hemat' : 'boros'}';
    return _Stat(
      label: 'Dibanding bulan lalu',
      child: Row(
        children: [
          Icon(saving ? AppIconsFill.checkCircle : AppIconsFill.warning, size: 16, color: saving ? c.income : c.warning),
          const SizedBox(width: AppSpacing.s4),
          Flexible(child: Text(text, style: AppTypography.amountSmall.copyWith(color: c.ink))),
        ],
      ),
    );
  }
}

/// Judul "Transaksi hari ini" dengan tombol ">" ke halaman riwayat lengkap.
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(header: true, child: Text('Transaksi hari ini', style: context.text.titleLarge)),
      ),
      IconButton(
        onPressed: onTap,
        tooltip: 'Lihat semua riwayat',
        icon: const Icon(AppIcons.caretRight, semanticLabel: 'Lihat semua riwayat'),
      ),
    ],
  );
}
