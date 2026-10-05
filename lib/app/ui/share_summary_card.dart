import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../gen/assets.gen.dart';
import '../theme/app_theme.dart';
import 'app_format.dart';
import 'app_illustration.dart';

/// Ukuran kanvas kartu bagikan. [size] dalam logical pixel; diekspor dengan
/// `pixelRatio` = [exportWidth] / lebar, jadi Story = 1080×1920, Feed = 1080×1350.
enum ShareCardFormat {
  story('Story', Size(360, 640)),

  /// Carousel beberapa slide 4:5 ([ShareFeedSlide]).
  feed('Feed', Size(360, 450));

  const ShareCardFormat(this.label, this.size);

  final String label;
  final Size size;

  static const double exportWidth = 1080;

  double get pixelRatio => exportWidth / size.width;
}

/// Satu kategori pengeluaran. [color] null = gabungan "Lainnya".
class ShareCardSlice {
  const ShareCardSlice({required this.label, required this.amount, this.color});

  final String label;
  final double amount;
  final Color? color;
}

/// Anggaran satu kategori bulan ini.
class ShareCardBudget {
  const ShareCardBudget({required this.label, required this.color, required this.spent, required this.limit});

  final String label;
  final Color color;
  final double spent;
  final double limit;

  /// Rasio terpakai (bisa > 1 bila lewat).
  double get used => limit <= 0 ? 0 : spent / limit;
}

/// Data ringkasan bulanan untuk kartu Story & slide Feed.
class ShareSummaryData {
  const ShareSummaryData({required this.month, required this.income, required this.expense, this.categories = const [], this.budgets = const []});

  final DateTime month;
  final double income;
  final double expense;

  /// Semua kategori berpengeluaran, terbesar dulu (belum digabung).
  final List<ShareCardSlice> categories;
  final List<ShareCardBudget> budgets;

  double get balance => income - expense;

  /// "Hemat 32% dari pemasukan" — tetap bermakna walau nominal disembunyikan.
  String? get highlight {
    if (income <= 0) return null;
    if (balance < 0) return 'Pengeluaran melebihi pemasukan'.tr;
    return 'Hemat @n% dari pemasukan'.trParams({'n': '${(balance / income * 100).round()}'});
  }

  /// [max] kategori terbesar + "Lainnya" untuk sisanya.
  List<ShareCardSlice> top(int max) {
    if (categories.length <= max) return categories;
    final rest = categories.skip(max).fold(0.0, (sum, s) => sum + s.amount);
    return [...categories.take(max), ShareCardSlice(label: 'Lainnya'.tr, amount: rest)];
  }

  double shareOf(double amount) => expense <= 0 ? 0 : (amount / expense).clamp(0.0, 1.0);
}

String _money(num amount, bool hide) => hide ? 'Rp •••' : AppFormat.rupiah(amount);

/// Nominal ringkas untuk baris sempit: 950, 450rb, 1,2jt, 2,5M.
String _compact(num amount) {
  final n = amount.abs();
  String short(double v, String unit) => '${(v * 10).round() % 10 == 0 ? v.round() : v.toStringAsFixed(1).replaceAll('.', ',')}$unit';
  // Satuan ikut bahasa: rb/jt/M (ribu/juta/miliar) ↔ K/M/B.
  final en = Get.locale?.languageCode == 'en';
  if (n >= 1e9) return short(n / 1e9, en ? 'B' : 'M');
  if (n >= 1e6) return short(n / 1e6, en ? 'M' : 'jt');
  if (n >= 1e3) return '${(n / 1e3).round()}${en ? 'K' : 'rb'}';
  return AppFormat.digits(n);
}

/// Kanvas kartu: tema terang, tanpa skala teks sistem, latar brand.
/// Gambar yang dibagikan jadi sama di semua perangkat & mode gelap.
class _Canvas extends StatelessWidget {
  const _Canvas({required this.size, required this.builder, this.ornament});

  static final _theme = AppTheme.light();

  final Size size;
  final WidgetBuilder builder;
  final CustomPainter Function(AppColors c)? ornament;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Builder(
          builder: (context) {
            final c = context.colors;
            return SizedBox.fromSize(
              size: size,
              child: DecoratedBox(
                decoration: BoxDecoration(color: c.brand),
                child: CustomPaint(
                  painter: ornament?.call(c),
                  child: Padding(padding: const EdgeInsets.all(AppSpacing.s24), child: builder(context)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Kartu Story (9:16) satu gambar.
class ShareSummaryCard extends StatelessWidget {
  const ShareSummaryCard({super.key, required this.data, this.hideAmounts = false});

  /// Kartu memuat maksimal 3 kategori terbesar + "Lainnya".
  static const maxRows = 3;

  final ShareSummaryData data;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    return _Canvas(
      size: ShareCardFormat.story.size,
      builder: (context) {
        final c = context.colors;
        final t = context.text;
        final onBrand = t.labelLarge?.copyWith(color: c.onBrand);
        final slices = data.top(maxRows);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ringkasan keuangan'.tr, style: onBrand),
                      const SizedBox(height: AppSpacing.s4),
                      Text(AppFormat.monthYear(data.month), style: t.headlineMedium?.copyWith(color: c.onBrand)),
                    ],
                  ),
                ),
                // Dompi hanya untuk momen ringan, bukan saat tekor.
                if (data.balance >= 0) AppIllustration.dompi(DompiMood.bangga, size: 88),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),
            Expanded(
              child: _WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Total(data: data, hideAmounts: hideAmounts),
                    const SizedBox(height: AppSpacing.s12),
                    Expanded(
                      child: slices.isEmpty
                          ? const _NoExpense()
                          : Column(
                              children: [
                                Expanded(
                                  child: Center(child: _Donut(slices: slices, size: 168)),
                                ),
                                const SizedBox(height: AppSpacing.s16),
                                _CategoryRows(data: data, slices: slices, withAmount: !hideAmounts),
                              ],
                            ),
                    ),
                    if (data.highlight != null) ...[const SizedBox(height: AppSpacing.s12), _Highlight(data: data)],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ShareAppMark(size: 32, showName: false),
                const SizedBox(width: AppSpacing.s8),
                Text('Dicatat dengan Wister Lite'.tr, style: onBrand),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Satu slide carousel Feed (4:5). Ornamen latar digambar di kanvas selebar
/// semua slide lalu digeser per [index], jadi menyambung saat digeser.
class ShareFeedSlide extends StatelessWidget {
  const ShareFeedSlide({super.key, required this.data, required this.index, this.hideAmounts = false});

  /// Maksimal kategori di slide kategori (+ "Lainnya").
  static const maxRows = 5;

  /// Baris anggaran per slide; sisanya lanjut ke slide berikutnya.
  static const budgetsPerSlide = 6;

  final ShareSummaryData data;
  final int index;
  final bool hideAmounts;

  /// Sampul, kategori, masuk vs keluar, lalu satu slide per [budgetsPerSlide] anggaran.
  static int countFor(ShareSummaryData data) => 3 + (data.budgets.length / budgetsPerSlide).ceil();

  @override
  Widget build(BuildContext context) {
    final count = countFor(data);
    return _Canvas(
      size: ShareCardFormat.feed.size,
      ornament: (c) => _RibbonPainter(index: index, count: count, colors: c),
      builder: (context) {
        final c = context.colors;
        final t = context.text;
        final small = t.labelMedium?.copyWith(color: c.onBrand);
        final (title, body) = switch (index) {
          0 => (null, _cover(context)),
          1 => ('Ke mana uangnya pergi?'.tr, _categories(context)),
          2 => ('Masuk vs keluar'.tr, _cashflow(context)),
          _ => ('Anggaran bulan ini'.tr, _budgets(context, index - 3)),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(AppFormat.monthYear(data.month), style: small),
              Text(title, style: t.headlineSmall?.copyWith(color: c.onBrand)),
              const SizedBox(height: AppSpacing.s12),
            ],
            Expanded(child: body),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: switch (index) {
                    0 => const SizedBox.shrink(),
                    _ when index == count - 1 => Text('Dicatat dengan Wister Lite'.tr, style: small),
                    _ => Text('Wister Lite', style: small),
                  },
                ),
                Text(
                  index == 0 ? 'Geser →   @page/@total'.trParams({'page': '${index + 1}', 'total': '$count'}) : '${index + 1}/$count',
                  style: small,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _cover(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(alignment: AlignmentDirectional.centerStart, child: ShareAppMark(size: 40)),
        const SizedBox(height: AppSpacing.s16),
        Text('Ringkasan keuangan'.tr, style: t.labelLarge?.copyWith(color: c.onBrand)),
        Text('${AppFormat.months[data.month.month - 1]} ${data.month.year}', style: t.headlineMedium?.copyWith(color: c.onBrand)),
        // Dompi jadi fokus sampul; disembunyikan saat tekor (aturan maskot).
        Expanded(
          child: data.balance >= 0
              ? Align(alignment: AlignmentDirectional.bottomEnd, child: AppIllustration.dompi(DompiMood.bangga, size: 128))
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.s8),
        _WhiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Total(data: data, hideAmounts: hideAmounts),
              if (data.highlight != null) ...[const SizedBox(height: AppSpacing.s12), _Highlight(data: data)],
            ],
          ),
        ),
      ],
    );
  }

  Widget _categories(BuildContext context) {
    final slices = data.top(maxRows);
    return _WhiteCard(
      child: slices.isEmpty
          ? const _NoExpense()
          : Column(
              children: [
                Expanded(
                  child: Center(child: _Donut(slices: slices, size: 112)),
                ),
                const SizedBox(height: AppSpacing.s12),
                _CategoryRows(data: data, slices: slices, withAmount: !hideAmounts),
              ],
            ),
    );
  }

  Widget _cashflow(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final max = math.max(data.income, data.expense);
    Widget bar(String label, double amount, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: t.titleSmall?.copyWith(color: c.ink)),
            ),
            Text(_money(amount, hideAmounts), style: AppTypography.amountMedium.copyWith(color: c.ink)),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        _Bar(value: max <= 0 ? 0 : amount / max, color: color, height: 16),
      ],
    );

    final balance = data.balance;
    // Bukan `.tr`: key 'Masuk'/'Keluar' sudah berarti masuk/keluar akun.
    final en = Get.locale?.languageCode == 'en';
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar(en ? 'In' : 'Masuk', data.income, c.incomeFill),
          const SizedBox(height: AppSpacing.s20),
          bar(en ? 'Out' : 'Keluar', data.expense, c.expenseFill),
          const Spacer(),
          Divider(color: c.outlineVariant, height: AppSpacing.s24),
          Row(
            children: [
              Expanded(
                child: Text('Selisih'.tr, style: t.titleSmall?.copyWith(color: c.ink)),
              ),
              Text(
                hideAmounts ? 'Rp •••' : '${balance < 0 ? AppFormat.minus : ''}${AppFormat.rupiah(balance)}',
                style: AppTypography.amountLarge.copyWith(color: balance < 0 ? c.danger : c.ink),
              ),
            ],
          ),
          if (data.highlight != null) ...[const SizedBox(height: AppSpacing.s12), _Highlight(data: data)],
        ],
      ),
    );
  }

  Widget _budgets(BuildContext context, int page) {
    final c = context.colors;
    final t = context.text;
    final tokens = context.components.budgetProgress;
    final safe = data.budgets.where((b) => b.used <= 1).length;
    final rows = data.budgets.skip(page * budgetsPerSlide).take(budgetsPerSlide).toList();
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '@safe dari @total anggaran aman'.trParams({'safe': '$safe', 'total': '${data.budgets.length}'}),
            style: t.titleMedium?.copyWith(color: c.ink),
          ),
          const SizedBox(height: AppSpacing.s12),
          for (final (i, b) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                SizedBox.square(
                  dimension: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: b.color, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    b.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(color: c.ink),
                  ),
                ),
                if (!hideAmounts) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    'Rp ${_compact(b.spent)} / ${_compact(b.limit)}',
                    style: t.bodySmall?.copyWith(color: c.inkMuted, fontFeatures: AppTypography.tabular),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                ],
                Text(
                  '${(b.used * 100).round()}%',
                  style: t.labelLarge?.copyWith(color: c.ink, fontFeatures: AppTypography.tabular),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            _Bar(value: b.used.clamp(0.0, 1.0), color: tokens.colorFor(b.used), height: 6),
          ],
        ],
      ),
    );
  }
}

/// Pita gelombang + lingkaran di batas slide, digambar di kanvas selebar
/// [count] slide lalu digeser ke [index].
class _RibbonPainter extends CustomPainter {
  _RibbonPainter({required this.index, required this.count, required this.colors});

  final int index;
  final int count;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = size.width * count;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-index * size.width, 0);

    double wave(double x) => size.height * 0.52 + size.height * 0.16 * math.sin(x / total * math.pi * 2 * 1.25 + 0.6);
    final ribbon = Path()..moveTo(0, wave(0));
    for (double x = 0; x <= total; x += 6) {
      ribbon.lineTo(x, wave(x));
    }
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = colors.brandContainer.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 64
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = colors.accent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Lingkaran tepat di batas slide: separuh di kiri, separuh di kanan.
    // Tinggi di area kartu (bukan judul) agar tidak menimpa teks.
    final dot = Paint()..color = colors.accent.withValues(alpha: 0.28);
    for (var k = 1; k < count; k++) {
      canvas.drawCircle(Offset(k * size.width, k.isOdd ? size.height * 0.36 : size.height * 0.68), 40, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.index != index || old.count != count || old.colors != colors;
}

/// Ikon app (Dompi di latar teal, sama dengan ikon launcher) + nama app.
class ShareAppMark extends StatelessWidget {
  const ShareAppMark({super.key, this.size = 32, this.showName = true});

  /// Salinan 256 px dari `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`.
  /// Perbarui bila ikon launcher berubah.
  static ImageProvider provider(double size) => ResizeImage(Assets.appIcon.provider(), width: (size * 3).round());

  /// Panggil sebelum kartu ditangkap agar ikon sudah terdekode.
  static Future<void> precache(BuildContext context) => Future.wait([
    for (final s in const [32.0, 40.0]) precacheImage(provider(s), context),
  ]);

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(size * 0.23);
    // Garis tipis agar ikon teal tetap terpisah dari latar brand.
    final icon = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: c.onBrand.withValues(alpha: 0.6), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image(image: provider(size), width: size, height: size, filterQuality: FilterQuality.medium),
      ),
    );
    if (!showName) return icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: AppSpacing.s8),
        Text('Wister Lite', style: context.text.titleSmall?.copyWith(color: c.onBrand)),
      ],
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: context.colors.surfaceContainerLowest, borderRadius: AppRadius.cardAll),
    child: Padding(padding: const EdgeInsets.all(AppSpacing.s20), child: child),
  );
}

class _Total extends StatelessWidget {
  const _Total({required this.data, required this.hideAmounts});

  final ShareSummaryData data;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total pengeluaran'.tr, style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
        Text(_money(data.expense, hideAmounts), style: AppTypography.amountLarge.copyWith(color: c.ink)),
      ],
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.data});

  final ShareSummaryData data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final over = data.balance < 0;
    return DecoratedBox(
      decoration: BoxDecoration(color: over ? c.warningContainer : c.brandContainer, borderRadius: AppRadius.inputAll),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
        child: Text(
          data.highlight!,
          textAlign: TextAlign.center,
          style: context.text.labelLarge?.copyWith(color: over ? c.onWarningContainer : c.onBrandContainer),
        ),
      ),
    );
  }
}

class _NoExpense extends StatelessWidget {
  const _NoExpense();

  @override
  Widget build(BuildContext context) => Center(
    child: Text('Belum ada pengeluaran bulan ini.'.tr, style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted)),
  );
}

class _Donut extends StatelessWidget {
  const _Donut({required this.slices, required this.size});

  final List<ShareCardSlice> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: size,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: size * 0.3,
          startDegreeOffset: -90,
          pieTouchData: PieTouchData(enabled: false),
          sections: [
            for (final s in slices) PieChartSectionData(value: s.amount, color: s.color ?? c.outline, radius: size * 0.18, showTitle: false),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

class _CategoryRows extends StatelessWidget {
  const _CategoryRows({required this.data, required this.slices, required this.withAmount});

  final ShareSummaryData data;
  final List<ShareCardSlice> slices;
  final bool withAmount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: s.color ?? c.outline, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(color: c.ink),
                  ),
                ),
                Text(
                  '${(data.shareOf(s.amount) * 100).round()}%',
                  style: t.labelLarge?.copyWith(color: c.ink, fontFeatures: AppTypography.tabular),
                ),
                if (withAmount) ...[
                  const SizedBox(width: AppSpacing.s8),
                  Text(AppFormat.rupiah(s.amount), style: AppTypography.amountSmall.copyWith(color: c.inkMuted)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.height});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.fullAll,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.components.budgetProgress.track),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(decoration: BoxDecoration(color: color)),
          ),
        ),
      ),
    );
  }
}
