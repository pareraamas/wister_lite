import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

import '../controllers/category_create_controller.dart';

class CategoryCreateView extends GetView<CategoryCreateController> {
  const CategoryCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((controller.isEditing ? 'Ubah Kategori' : 'Buat Kategori').tr),
        actions: [
          if (controller.isEditing) IconButton(icon: const Icon(AppIcons.trash), tooltip: 'Hapus kategori'.tr, onPressed: () => _confirmDelete(context)),
          const SizedBox(width: AppSpacing.s4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  const _Preview(),
                  const SizedBox(height: AppSpacing.section),
                  Obx(
                    () => TextField(
                      controller: controller.labelController,
                      maxLength: CategoryCreateController.maxLabelLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Nama kategori'.tr,
                        hintText: 'Misal: Jajan'.tr,
                        errorText: controller.labelError.value?.tr,
                        prefixIcon: const Icon(AppIcons.tag),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  _Label('Warna'.tr),
                  const _ColorPicker(),
                  const SizedBox(height: AppSpacing.section),
                  _Label('Ikon'.tr),
                  const _IconPicker(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, AppSpacing.s16),
              child: SizedBox(
                width: double.infinity,
                child: Obx(
                  () => FilledButton(
                    onPressed: controller.isLoading.value ? null : controller.saveCategory,
                    child: Text((controller.isEditing ? 'Simpan perubahan' : 'Simpan kategori').tr),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Hapus kategori ini?'.tr,
      message: 'Kategori "@name" akan dihapus. Kategori yang masih dipakai transaksi tidak bisa dihapus.'.trParams({
        'name': controller.editingCategory!.label,
      }),
    );
    // Guard "masih dipakai" ada di controller, lengkap dengan pesan ramahnya.
    if (ok) await controller.deleteCategory();
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
    child: Semantics(
      header: true,
      child: Text(text, style: context.text.titleSmall?.copyWith(color: context.colors.inkMuted)),
    ),
  );
}

/// Pratinjau langsung; "memantul" setiap kali warna atau ikon diganti.
class _Preview extends GetView<CategoryCreateController> {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final color = controller.selectedColor.value;
      final icon = controller.selectedIcon.value;
      final name = controller.label.value.trim();
      Widget blob = CategoryBlob(iconAsset: icon, color: color, size: CategoryBlobSize.large, semanticLabel: 'Pratinjau ikon kategori'.tr);
      if (!AppMotion.reduced(context)) {
        blob = blob
            .animate(key: ValueKey('${color.toARGB32()}|$icon'))
            .scaleXY(begin: 0.8, end: 1, duration: AppMotion.long, curve: Curves.elasticOut);
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24, horizontal: AppSpacing.card),
          child: Column(
            children: [
              SizedBox(height: 72, child: Center(child: blob)),
              const SizedBox(height: AppSpacing.s12),
              Text(
                name.isEmpty ? 'Nama kategori'.tr : name,
                textAlign: TextAlign.center,
                style: context.text.titleLarge?.copyWith(color: name.isEmpty ? context.colors.inkMuted : null),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _ColorPicker extends GetView<CategoryCreateController> {
  const _ColorPicker();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      final selected = controller.selectedColor.value.toARGB32();
      return Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          for (var i = 0; i < CategoryCreateController.availableColors.length; i++)
            Builder(
              builder: (context) {
                final color = CategoryCreateController.availableColors[i];
                final isSelected = color.toARGB32() == selected;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: 'Warna @n'.trParams({'n': '${i + 1}'}),
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () => controller.selectColor(color),
                    radius: 28,
                    child: AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.short),
                      width: AppSpacing.minTouch,
                      height: AppSpacing.minTouch,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? c.ink : c.outlineVariant, width: isSelected ? 3 : 1),
                      ),
                      child: isSelected ? Icon(AppIcons.check, color: c.ink) : null,
                    ),
                  ),
                );
              },
            ),
        ],
      );
    });
  }
}

class _IconPicker extends GetView<CategoryCreateController> {
  const _IconPicker();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      final selectedIcon = controller.selectedIcon.value;
      final color = controller.selectedColor.value;
      return Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          for (final icon in CategoryIcons.all)
            Semantics(
              button: true,
              selected: icon == selectedIcon,
              label: 'Ikon @name'.trParams({'name': CategoryIcons.labelOf(icon).tr}),
              excludeSemantics: true,
              child: Material(
                color: icon == selectedIcon ? c.brandContainer : c.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.inputAll,
                  side: BorderSide(color: icon == selectedIcon ? c.brand : c.outlineVariant, width: icon == selectedIcon ? 2 : 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => controller.selectIcon(icon),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    child: CategoryBlob(iconAsset: icon, color: color),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
