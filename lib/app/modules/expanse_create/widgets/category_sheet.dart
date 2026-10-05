import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

import '../controllers/expanse_create_controller.dart';

/// Sheet "Pilih kategori": grid 4 kolom, reaktif terhadap `controller.categories`
/// sehingga kategori yang baru dibuat langsung muncul.
Future<void> showCategorySheet(BuildContext context, ExpanseCreateController controller) {
  return AppSheet.show<void>(
    context,
    title: 'Pilih kategori'.tr,
    child: _CategoryGrid(controller: controller),
  );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.controller});

  final ExpanseCreateController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: Obx(() {
            final categories = controller.categories.toList();
            final selectedId = controller.selectedCategory.value?.id;
            return GridView.builder(
              shrinkWrap: true,
              itemCount: categories.length + 1,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 96,
                mainAxisExtent: 104,
                crossAxisSpacing: AppSpacing.s8,
                mainAxisSpacing: AppSpacing.s8,
              ),
              itemBuilder: (context, index) {
                if (index == categories.length) {
                  return _GridItem(
                    label: 'Buat baru'.tr,
                    icon: AppIllustration(AppIllustrations.buatBaru, size: 56),
                    onTap: () async {
                      final created = await controller.openCreateCategory();
                      if (created && context.mounted) Navigator.of(context).pop();
                    },
                  );
                }
                final c = categories[index];
                return _GridItem(
                  label: c.label,
                  selected: c.id == selectedId,
                  icon: CategoryBlob(iconAsset: c.icon, color: c.color, size: CategoryBlobSize.large),
                  onTap: () => _pick(context, c),
                );
              },
            );
          }),
        ),
        const SizedBox(height: AppSpacing.s8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: controller.openManageCategories,
            icon: const Icon(AppIcons.pencilSimple),
            label: Text('Kelola kategori'.tr),
          ),
        ),
      ],
    );
  }

  void _pick(BuildContext context, Category category) {
    controller.selectCategory(category);
    Navigator.of(context).pop();
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({required this.label, required this.icon, required this.onTap, this.selected = false});

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.brandContainer : c.surfaceContainerLow,
        borderRadius: AppRadius.inputAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(height: AppSpacing.s4),
                Text(
                  label,
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
  }
}
