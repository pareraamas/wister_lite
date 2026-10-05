import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/data/services/share_service.dart';
import 'package:wister_lite/app/ui/ui.dart';
import 'package:wister_lite/app/ults/clock.dart';
import 'package:wister_lite/app/widgets/app_snackbar.dart';

/// Pratinjau & ekspor kartu ringkasan bulanan sebagai PNG.
///
/// Argumen route: bulan (`DateTime`) yang diringkas; default bulan ini.
class ShareCardController extends GetxController {
  final ExpenseRepository _repository = Get.find<ExpenseRepository>();

  late final DateTime month;
  final data = Rxn<ShareSummaryData>();
  final format = ShareCardFormat.story.obs;
  final hideAmounts = false.obs;
  final isLoading = true.obs;
  final isSharing = false.obs;

  /// `RepaintBoundary` kartu Story.
  final storyKey = GlobalKey();

  /// `RepaintBoundary` tiap slide Feed; jumlahnya ikut banyaknya anggaran.
  final _slideKeys = <GlobalKey>[];

  GlobalKey slideKey(int index) {
    while (_slideKeys.length <= index) {
      _slideKeys.add(GlobalKey());
    }
    return _slideKeys[index];
  }

  int get slideCount => data.value == null ? 0 : ShareFeedSlide.countFor(data.value!);

  /// Jumlah gambar yang akan dibagikan untuk format aktif.
  int get imageCount => format.value == ShareCardFormat.story ? 1 : slideCount;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    final base = arg is DateTime ? arg : Clock.now();
    month = DateTime(base.year, base.month);
    loadData();
  }

  @override
  void onReady() {
    super.onReady();
    // Ikon app (PNG) didekode async; siapkan sebelum pengguna menekan Bagikan.
    final context = Get.context;
    if (context != null) ShareAppMark.precache(context);
  }

  Future<void> loadData() async {
    final categories = await _repository.getCategories();
    final spending = await _repository.getCategorySpendingForMonth(month);
    final budgets = await _repository.getBudgetsForMonth(month);
    final income = await _repository.getMonthlyTotal(month, 'income');
    final expense = await _repository.getMonthlyTotal(month, 'expense');

    final ranked = categories.where((c) => (spending[c.id] ?? 0) > 0).toList()..sort((a, b) => spending[b.id]!.compareTo(spending[a.id]!));
    final byId = {for (final c in categories) c.id: c};
    final budgetRows = [
      for (final b in budgets)
        if (b.amount > 0 && byId[b.categoryId] != null)
          ShareCardBudget(label: byId[b.categoryId]!.label, color: byId[b.categoryId]!.color, spent: spending[b.categoryId] ?? 0, limit: b.amount),
    ]..sort((a, b) => b.used.compareTo(a.used));

    data.value = ShareSummaryData(
      month: month,
      income: income,
      expense: expense,
      categories: [for (final c in ranked) ShareCardSlice(label: c.label, amount: spending[c.id]!, color: c.color)],
      budgets: budgetRows,
    );
    isLoading.value = false;
  }

  /// Tangkap kartu pratinjau jadi PNG 1080 px lalu buka share sheet. Feed
  /// dibagikan sekaligus agar bisa diunggah sebagai satu carousel.
  Future<void> share({Rect? origin}) async {
    if (isSharing.value) return;
    isSharing.value = true;
    try {
      final story = format.value == ShareCardFormat.story;
      final keys = story ? [storyKey] : [for (var i = 0; i < slideCount; i++) slideKey(i)];
      final stamp = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final images = <(Uint8List, String)>[];
      for (var i = 0; i < keys.length; i++) {
        final png = await _capture(keys[i]);
        images.add((
          png,
          story
              ? 'ringkasan-@stamp-story.png'.trParams({'stamp': stamp})
              : 'ringkasan-@stamp-feed-@n.png'.trParams({'stamp': stamp, 'n': '${i + 1}'}),
        ));
      }
      await Get.find<ShareService>().shareImages(images, origin: origin);
    } catch (_) {
      showAppSnackBar('Gagal membuat gambar. Coba lagi.'.tr);
    } finally {
      isSharing.value = false;
    }
  }

  Future<Uint8List> _capture(GlobalKey key) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('Kartu belum dirender');
    // Ukuran boundary = ukuran logis kartu, tidak terpengaruh skala pratinjau.
    final image = await boundary.toImage(pixelRatio: format.value.pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('PNG kosong');
    return bytes.buffer.asUint8List();
  }
}
