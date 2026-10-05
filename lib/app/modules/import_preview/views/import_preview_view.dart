import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/services/transaction_csv.dart';
import 'package:wister_lite/app/data/services/transaction_import.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

import '../controllers/import_preview_controller.dart';

class ImportPreviewView extends GetView<ImportPreviewController> {
  const ImportPreviewView({super.key});

  /// Batas baris yang ditampilkan agar layar tetap ringan untuk file besar.
  static const _sampleCount = 5;
  static const _issueCount = 20;

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan;
    final n = plan.expenses.length;
    return Scaffold(
      appBar: AppBar(title: Text('Pratinjau Import'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, AppSpacing.s24),
        children: [
          if (plan.missingColumns.isNotEmpty)
            _Notice(
              title: 'Kolom wajib tidak ditemukan'.tr,
              message: 'File harus punya kolom @cols. Pakai template agar formatnya pas.'.trParams({
                'cols': [for (final c in plan.missingColumns) _columnLabel(c)].join(', '),
              }),
            )
          else if (plan.isEmpty)
            _Notice(
              title: 'Tidak ada transaksi baru'.tr,
              message: plan.duplicates > 0
                  ? 'Semua transaksi di file ini sudah ada di catatanmu.'.tr
                  : 'Tidak ada baris yang bisa dibaca. Cek bagian "Dilewati" di bawah atau pakai template.'.tr,
            )
          else
            _Summary(controller: controller),
          if (plan.newCategories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            _Header('Kategori baru (@n)'.trParams({'n': '${plan.newCategories.length}'})),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Dibuat otomatis. Ikon dan warnanya bisa diubah di Kelola Kategori.'.tr,
              style: context.text.bodySmall?.copyWith(color: context.colors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                for (final c in plan.newCategories)
                  Chip(
                    avatar: CircleAvatar(backgroundColor: c.color, radius: 6),
                    label: Text(c.label),
                  ),
              ],
            ),
          ],
          if (plan.duplicates > 0 || plan.issues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            _Header('Dilewati (@n)'.trParams({'n': '${plan.duplicates + plan.issues.length}'})),
            const SizedBox(height: AppSpacing.s8),
            _Skipped(plan: plan, maxIssues: _issueCount),
          ],
          if (n > 0) ...[
            const SizedBox(height: AppSpacing.section),
            _Header(n > _sampleCount ? 'Contoh @shown dari @total transaksi'.trParams({'shown': '$_sampleCount', 'total': '$n'}) : 'Transaksi'.tr),
            const SizedBox(height: AppSpacing.s8),
            for (final e in plan.expenses.take(_sampleCount)) ...[
              TransactionTile(
                title: e.name,
                amount: e.price,
                kind: e.transactionType == 'income' ? AmountKind.income : AmountKind.expense,
                categoryIcon: e.category!.icon,
                categoryColor: e.category!.color,
                categoryLabel: e.category!.label,
                dateLabel: '${AppFormat.dayMonthShort(e.dateTime)} ${e.dateTime.year}',
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ],
          const SizedBox(height: AppSpacing.s16),
          Center(
            child: Builder(
              builder: (context) => TextButton.icon(
                onPressed: () => controller.shareTemplate(origin: _originOf(context)),
                icon: const Icon(AppIcons.fileCsv),
                label: Text('Bagikan template CSV'.tr),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: n == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, AppSpacing.s16),
                child: Obx(
                  () => FilledButton(
                    onPressed: controller.isSaving.value ? null : controller.save,
                    child: Text('Impor @n transaksi'.trParams({'n': '$n'})),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Sama dengan header CSV/Excel di bahasa aktif.
String _columnLabel(ImportColumn c) => TransactionCsv.headers[c.index];

Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(header: true, child: Text(text, style: context.text.titleMedium));
}

class _Summary extends StatelessWidget {
  const _Summary({required this.controller});

  final ImportPreviewController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final range = controller.range!;
    String date(DateTime d) => '${AppFormat.dayMonthShort(d)} ${d.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('@n transaksi siap diimpor'.trParams({'n': '${controller.expenses.length}'}), style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.s4),
            Text(
              range.$1 == range.$2 ? date(range.$1) : '${date(range.$1)} – ${date(range.$2)}',
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s16,
              runSpacing: AppSpacing.s4,
              children: [
                AmountText(controller.total('income'), kind: AmountKind.income, semanticsPrefix: 'Total pemasukan'.tr),
                AmountText(controller.total('expense'), kind: AmountKind.expense, semanticsPrefix: 'Total pengeluaran'.tr),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      color: c.warningContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.warning, color: c.onWarningContainer),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall?.copyWith(color: c.onWarningContainer)),
                  const SizedBox(height: AppSpacing.s4),
                  Text(message, style: context.text.bodyMedium?.copyWith(color: c.onWarningContainer)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skipped extends StatelessWidget {
  const _Skipped({required this.plan, required this.maxIssues});

  final ImportPlan plan;
  final int maxIssues;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = context.text.bodySmall?.copyWith(color: c.inkMuted);
    final rest = plan.issues.length - maxIssues;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.duplicates > 0) Text('@n transaksi sudah ada di catatanmu'.trParams({'n': '${plan.duplicates}'}), style: context.text.bodyLarge),
            if (plan.duplicates > 0 && plan.issues.isNotEmpty) const SizedBox(height: AppSpacing.s12),
            if (plan.issues.isNotEmpty) ...[
              Text('@n baris tidak bisa dibaca'.trParams({'n': '${plan.issues.length}'}), style: context.text.bodyLarge),
              const SizedBox(height: AppSpacing.s4),
              for (final issue in plan.issues.take(maxIssues)) Text(issue.toString(), style: muted),
              if (rest > 0) Text('+@n baris lainnya'.trParams({'n': '$rest'}), style: muted),
            ],
          ],
        ),
      ),
    );
  }
}
