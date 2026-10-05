import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

import '../controllers/category_list_controller.dart';

class CategoryListView extends GetView<CategoryListController> {
  const CategoryListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kelola Kategori'.tr)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-kategori',
        tooltip: 'Buat kategori'.tr,
        onPressed: controller.goToCreate,
        child: const Icon(AppIcons.plus, size: 28),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const SkeletonList(itemCount: 6, padding: EdgeInsets.all(AppSpacing.page));
        }
        return RefreshIndicator(
          onRefresh: controller.loadCategories,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (controller.categories.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: EmptyState.kategori(onAction: controller.goToCreate))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, 96),
                  sliver: SliverList.separated(
                    itemCount: controller.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      final category = controller.categories[index];
                      return Card(
                        child: ListTile(
                          onTap: () => controller.goToEdit(category),
                          leading: CategoryBlob(iconAsset: category.icon, color: category.color),
                          title: Text(category.label),
                          trailing: Icon(AppIcons.caretRight, color: context.colors.inkMuted, semanticLabel: 'Ubah'.tr),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
