import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/modules/budget/views/budget_view.dart';
import 'package:wister_lite/app/modules/home/views/home_view.dart';
import 'package:wister_lite/app/modules/statistik/views/statistik_view.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

import '../controllers/main_nav_controller.dart';

class MainNavView extends GetView<MainNavController> {
  const MainNavView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: NotificationListener<UserScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical) {
              controller.onUserScroll(n.direction, atTop: n.metrics.pixels <= n.metrics.minScrollExtent);
            }
            return false;
          },
          child: IndexedStack(index: controller.selectedIndex.value, children: const [HomeView(), BudgetView(), StatistikView()]),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: _HidingFab(visible: controller.fabVisible.value, onPressed: controller.openCreateTransaction),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.selectedIndex.value,
          onDestinationSelected: controller.changeTab,
          destinations: [
            _destination(context, AppIcons.wallet, AppIconsFill.wallet, 'Beranda'.tr),
            _destination(context, AppIcons.target, AppIconsFill.target, 'Anggaran'.tr),
            _destination(context, AppIcons.chartDonut, AppIconsFill.chartDonut, 'Statistik'.tr),
          ],
        ),
      ),
    );
  }

  NavigationDestination _destination(BuildContext context, IconData icon, IconData active, String label) {
    Widget selected = Icon(active);
    if (!AppMotion.reduced(context)) {
      // Pegas kecil saat tab jadi aktif.
      selected = selected.animate().scaleXY(begin: 0.8, end: 1, duration: AppMotion.long, curve: Curves.elasticOut);
    }
    return NavigationDestination(icon: Icon(icon), selectedIcon: selected, label: label, tooltip: label);
  }
}

/// FAB tambah transaksi yang turun keluar layar saat disembunyikan.
class _HidingFab extends StatelessWidget {
  const _HidingFab({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.medium);
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 2),
          duration: duration,
          curve: AppMotion.emphasized,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            child: FloatingActionButton(
              heroTag: 'fab-tambah',
              tooltip: 'Tambah transaksi'.tr,
              onPressed: onPressed,
              child: const Icon(AppIcons.plus, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
