import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';
import 'package:wister_lite/app/ults/clock.dart';
import 'package:wister_lite/app/widgets/app_snackbar.dart';

import '../controllers/expanse_create_controller.dart';
import '../widgets/category_sheet.dart';

/// Form satu layar tanpa scroll: nominal selalu terlihat di tengah,
/// kategori satu baris geser, tanggal + Simpan menempel di keypad.
class ExpanseCreateView extends GetView<ExpanseCreateController> {
  const ExpanseCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    // Keyboard sistem terbuka (mengetik catatan) → keypad nominal disembunyikan
    // agar tidak ada dua keyboard bertumpuk.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(AppIcons.x), tooltip: 'Tutup'.tr, onPressed: Get.back),
            centerTitle: true,
            title: Obx(() => Semantics(label: controller.title, child: const _TypeToggle())),
            actions: [
              Obx(() {
                if (!controller.isEditing) return const SizedBox(width: AppSpacing.minTouch);
                return IconButton(icon: const Icon(AppIcons.trash), tooltip: 'Hapus transaksi'.tr, onPressed: () => _confirmDelete(context));
              }),
              const SizedBox(width: AppSpacing.s4),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.noteFocus.unfocus,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.s8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _AmountDisplay(),
                            const SizedBox(height: AppSpacing.s16),
                            _NoteField(controller: controller),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _CategoryStrip(onOpenAll: () => showCategorySheet(context, controller)),
                const SizedBox(height: AppSpacing.s12),
                if (!keyboardOpen) _BottomPanel(controller: controller, onPickDate: () => _pickDate(context)),
              ],
            ),
          ),
        ),
        const _SuccessOverlay(),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedDate.value,
      firstDate: DateTime(2000),
      lastDate: Clock.now(),
    );
    if (picked != null) controller.setDate(picked);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Hapus transaksi ini?'.tr,
      message: 'Catatan ini akan dihapus permanen dan tidak bisa dikembalikan.'.tr,
    );
    if (!ok) return;
    if (await controller.deleteExpanse()) {
      Get.back(result: true);
      showAppSnackBar('Transaksi dihapus'.tr);
    } else {
      showAppSnackBar('Gagal menghapus transaksi. Coba lagi, ya.'.tr);
    }
  }
}

/// Toggle Keluar/Masuk di AppBar; warnanya mengikuti tipe (coral / hijau).
class _TypeToggle extends GetView<ExpanseCreateController> {
  const _TypeToggle();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      final income = controller.isIncome;
      return SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 'expense', label: Text('Keluar'.tr)),
          ButtonSegment(value: 'income', label: Text('Masuk'.tr)),
        ],
        selected: {controller.transactionType.value},
        onSelectionChanged: (s) => controller.setType(s.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: income ? c.incomeContainer : c.expenseContainer,
          selectedForegroundColor: income ? c.onIncomeContainer : c.onExpenseContainer,
        ),
      );
    });
  }
}

class _AmountDisplay extends GetView<ExpanseCreateController> {
  const _AmountDisplay();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      final error = controller.amountError.value;
      final kind = controller.isIncome ? AmountKind.income : AmountKind.expense;
      final empty = controller.amount.value == 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AmountText(
              controller.amount.value,
              kind: empty ? AmountKind.neutral : kind,
              size: AmountSize.display,
              color: empty ? c.inkMuted : null,
              semanticsPrefix: 'Nominal'.tr,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text(error.tr, style: context.text.bodyMedium?.copyWith(color: c.danger)),
            ),
        ],
      );
    });
  }
}

/// Catatan opsional sebagai pill ringkas di bawah nominal.
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final ExpanseCreateController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const none = OutlineInputBorder(borderRadius: AppRadius.fullAll, borderSide: BorderSide.none);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: TextField(
        controller: controller.nameController,
        focusNode: controller.noteFocus,
        maxLength: 50,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        style: context.text.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Tambah catatan'.tr,
          fillColor: c.surfaceContainerLow,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          prefixIcon: Icon(AppIcons.note, color: c.inkMuted, size: 20),
          // Penyeimbang ikon kiri agar teks tetap di tengah.
          suffixIcon: const SizedBox(width: 20),
          border: none,
          enabledBorder: none,
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.fullAll,
            borderSide: BorderSide(color: c.brand),
          ),
          counterText: '',
        ),
      ),
    );
  }
}

/// Satu baris kategori yang bisa digeser; "Semua" selalu di depan.
class _CategoryStrip extends GetView<ExpanseCreateController> {
  const _CategoryStrip({required this.onOpenAll});

  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      final selectedId = controller.selectedCategory.value?.id;
      final error = controller.categoryError.value;
      final cats = controller.recentCategories.toList();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppSpacing.minTouch,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: cats.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Center(
                    child: ActionChip(
                      avatar: Icon(AppIcons.magnifyingGlass, color: c.brand),
                      label: Text('Semua'.tr),
                      tooltip: 'Pilih kategori'.tr,
                      onPressed: onOpenAll,
                    ),
                  );
                }
                final cat = cats[i - 1];
                return Center(
                  child: ChoiceChip(
                    avatar: CategoryBlob(iconAsset: cat.icon, color: cat.color, size: CategoryBlobSize.small),
                    label: Text(cat.label),
                    selected: cat.id == selectedId,
                    showCheckmark: false,
                    onSelected: (_) => controller.selectCategory(cat),
                  ),
                );
              },
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s4, AppSpacing.page, 0),
              child: Text(error.tr, style: context.text.bodyMedium?.copyWith(color: c.danger)),
            ),
        ],
      );
    });
  }
}

/// Keypad + baris [tanggal][Simpan] agar tidak butuh field tanggal terpisah.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.controller, required this.onPickDate});

  final ExpanseCreateController controller;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s12, AppSpacing.page, AppSpacing.s12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() => AmountKeypad(value: controller.amount.value, onChanged: controller.onAmountChanged)),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Obx(
                  () => Semantics(
                    button: true,
                    label: 'Tanggal @date, ketuk untuk mengubah'.trParams({'date': controller.dateLabel}),
                    excludeSemantics: true,
                    child: OutlinedButton.icon(
                      onPressed: onPickDate,
                      icon: const Icon(AppIcons.calendarBlank),
                      label: Text(controller.dateShortLabel),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Obx(() => FilledButton(onPressed: controller.isSaving.value ? null : controller.save, child: Text('Simpan'.tr))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Momen sukses: centang Lottie + Dompi senang, lalu form tertutup.
class _SuccessOverlay extends GetView<ExpanseCreateController> {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      if (!controller.justSaved.value) return const SizedBox.shrink();
      Widget content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIllustration.dompi(DompiMood.senang, size: 140),
          const SizedBox(height: AppSpacing.s8),
          SuccessCheck(onCompleted: controller.finishSave),
          const SizedBox(height: AppSpacing.s8),
          Text('Tersimpan!'.tr, style: context.text.titleLarge),
        ],
      );
      if (!AppMotion.reduced(context)) {
        content = content.animate().fadeIn(duration: AppMotion.short).scaleXY(begin: 0.9, end: 1, curve: AppMotion.emphasized);
      }
      return Positioned.fill(
        child: Material(
          color: c.surface.withValues(alpha: 0.94),
          child: Center(child: content),
        ),
      );
    });
  }
}
