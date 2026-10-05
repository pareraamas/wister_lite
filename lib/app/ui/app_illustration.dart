import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../gen/assets.gen.dart';
import '../theme/app_theme.dart';

/// Path aset ilustrasi (dibuat Agen Ilustrasi). Nama file adalah kontrak.
abstract final class AppIllustrations {
  static const _gen = Assets.illustrations;

  // Spot empty state (viewBox 160).
  static final emptyBeranda = _gen.empty.emptyBeranda;
  static final emptyAnggaran = _gen.empty.emptyAnggaran;
  static final emptyStatistik = _gen.empty.emptyStatistik;
  static final emptyKategori = _gen.empty.emptyKategori;

  // Micro-illustration (viewBox 64).
  static final confirmHapus = _gen.confirmHapus;
  static final buatBaru = _gen.buatBaru;
  static final hariIniKosong = _gen.hariIniKosong;

  /// Animasi centang sukses (Lottie).
  static final successCheck = Assets.lottie.successCheck;

  static final List<String> empty = [emptyBeranda, emptyAnggaran, emptyStatistik, emptyKategori];
  static final List<String> micro = [confirmHapus, buatBaru, hariIniKosong];
}

/// Ekspresi maskot Dompi. Hanya untuk momen ringan (empty state, sukses,
/// budget aman) — jangan dipakai di layar over-budget atau error.
enum DompiMood {
  senang('Dompi senang'),
  bangga('Dompi bangga'),
  mengantuk('Dompi mengantuk'),
  waspada('Dompi waspada');

  const DompiMood(this._label);

  final String _label;

  /// Label semantik bawaan bila ilustrasi tidak dekoratif (sudah diterjemahkan).
  String get label => _label.tr;

  String get asset => switch (this) {
    DompiMood.senang => Assets.illustrations.dompi.dompiSenang,
    DompiMood.bangga => Assets.illustrations.dompi.dompiBangga,
    DompiMood.mengantuk => Assets.illustrations.dompi.dompiMengantuk,
    DompiMood.waspada => Assets.illustrations.dompi.dompiWaspada,
  };
}

/// Ikon kategori bawaan (SVG putih 24×24) di `assets/icon_category/`.
/// Path disimpan di SQLite sebagai `Category.icon`; path lama (`assets/uil_*`)
/// dinormalisasi lewat [resolve] saat dibaca.
abstract final class CategoryIcons {
  static const _gen = Assets.iconCategory;
  static const _legacyPrefix = 'assets/uil_';
  static const _dirPrefix = 'assets/icon_category/uil_';

  /// Memetakan path rilis lama (`assets/uil_x.svg`) ke lokasi baru.
  static String resolve(String icon) => icon.startsWith(_legacyPrefix) ? icon.replaceFirst(_legacyPrefix, _dirPrefix) : icon;

  static final basketball = _gen.uilBasketball;
  static final bookOpen = _gen.uilBookOpen;
  static final carSideview = _gen.uilCarSideview;
  static final clapperBoard = _gen.uilClapperBoard;
  static final gift = _gen.uilGift;
  static final home = _gen.uilHome;
  static final pizzaSlice = _gen.uilPizzaSlice;
  static final rssAlt = _gen.uilRssAlt;
  static final shoppingCart = _gen.uilShoppingCart;

  // Tambahan redesign.
  static final coffee = _gen.uilCoffee;
  static final utensils = _gen.uilUtensils;
  static final bus = _gen.uilBus;
  static final gasStation = _gen.uilGasStation;
  static final motorcycle = _gen.uilMotorcycle;
  static final plane = _gen.uilPlane;
  static final luggage = _gen.uilLuggage;
  static final heartPulse = _gen.uilHeartPulse;
  static final pill = _gen.uilPill;
  static final shirt = _gen.uilShirt;
  static final shoppingBag = _gen.uilShoppingBag;
  static final scissors = _gen.uilScissors;
  static final smartphone = _gen.uilSmartphone;
  static final wifi = _gen.uilWifi;
  static final monitor = _gen.uilMonitor;
  static final bolt = _gen.uilBolt;
  static final droplet = _gen.uilDroplet;
  static final receipt = _gen.uilReceipt;
  static final building = _gen.uilBuilding;
  static final wrench = _gen.uilWrench;
  static final stroller = _gen.uilStroller;
  static final paw = _gen.uilPaw;
  static final gamepad = _gen.uilGamepad;
  static final music = _gen.uilMusic;
  static final dumbbell = _gen.uilDumbbell;
  static final graduationCap = _gen.uilGraduationCap;
  static final briefcase = _gen.uilBriefcase;
  static final wallet = _gen.uilWallet;
  static final money = _gen.uilMoney;
  static final creditCard = _gen.uilCreditCard;
  static final piggyBank = _gen.uilPiggyBank;
  static final chartLine = _gen.uilChartLine;
  static final handHeart = _gen.uilHandHeart;
  static final tag = _gen.uilTag;

  /// Ikon kategori bawaan lama (rilis sebelum redesign), urut seperti `ExpenseType`.
  static final List<String> legacy = [pizzaSlice, rssAlt, bookOpen, gift, carSideview, shoppingCart, home, basketball, clapperBoard];

  /// Semua ikon yang bisa dipilih, urut sesuai tampilan di pemilih ikon.
  static final List<String> all = [
    ...legacy,
    coffee,
    utensils,
    bus,
    gasStation,
    motorcycle,
    plane,
    luggage,
    heartPulse,
    pill,
    shirt,
    shoppingBag,
    scissors,
    smartphone,
    wifi,
    monitor,
    bolt,
    droplet,
    receipt,
    building,
    wrench,
    stroller,
    paw,
    gamepad,
    music,
    dumbbell,
    graduationCap,
    briefcase,
    wallet,
    money,
    creditCard,
    piggyBank,
    chartLine,
    handHeart,
    tag,
  ];

  /// Label untuk screen reader di pemilih ikon (kunci terjemahan; tampilkan lewat [labelOf]).
  static final Map<String, String> labels = {
    pizzaSlice: 'Makanan',
    rssAlt: 'Internet',
    bookOpen: 'Pendidikan',
    gift: 'Hadiah',
    carSideview: 'Transport',
    shoppingCart: 'Belanja',
    home: 'Rumah',
    basketball: 'Olahraga',
    clapperBoard: 'Hiburan',
    coffee: 'Kopi',
    utensils: 'Restoran',
    bus: 'Bus',
    gasStation: 'Bensin',
    motorcycle: 'Motor',
    plane: 'Pesawat',
    luggage: 'Liburan',
    heartPulse: 'Kesehatan',
    pill: 'Obat',
    shirt: 'Pakaian',
    shoppingBag: 'Tas belanja',
    scissors: 'Perawatan',
    smartphone: 'Pulsa',
    wifi: 'Wi-Fi',
    monitor: 'Streaming',
    bolt: 'Listrik',
    droplet: 'Air',
    receipt: 'Tagihan',
    building: 'Sewa',
    wrench: 'Servis',
    stroller: 'Anak',
    paw: 'Hewan peliharaan',
    gamepad: 'Game',
    music: 'Musik',
    dumbbell: 'Gym',
    graduationCap: 'Sekolah',
    briefcase: 'Kerja',
    wallet: 'Dompet',
    money: 'Uang tunai',
    creditCard: 'Kartu kredit',
    piggyBank: 'Tabungan',
    chartLine: 'Investasi',
    handHeart: 'Donasi',
    tag: 'Lainnya',
  };

  static String labelOf(String icon) => (labels[icon] ?? 'Ikon kategori').tr;
}

/// Memetakan warna terang bawaan ilustrasi ke token tema aktif, sehingga
/// satu file SVG tampil benar di light dan dark.
///
/// Kunci adalah RGB kontrak ilustrasi (bukan warna UI), alpha asli dipertahankan.
@immutable
class IllustrationColorMapper extends ColorMapper {
  /// Warna kontrak yang sengaja sama di light & dark (tidak dipetakan):
  /// pipi Dompi dan krem (badan palet, kilau koin). Detail di atasnya pakai
  /// `#1B2431`.
  static const fixedRgb = {0xF2A7B5, 0xFFE8C4};

  IllustrationColorMapper(AppColors c)
    : _map = {
        0x1B2430: c.ink,
        // Garis detail di atas isian yang tetap terang di dark (accent, krem):
        // selalu gelap agar tidak hilang saat `ink` berubah terang.
        0x1B2431: c.onAccent,
        0x0E8C7F: c.brand,
        0xCDEFE9: c.brandContainer,
        0xFFB547: c.accent,
        0xFFE7C2: c.accentContainer,
        0xFFFFFF: c.surfaceContainerLowest,
        0x1E9E5A: c.incomeFill,
        0xF0634A: c.expenseFill,
      };

  final Map<int, Color> _map;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    final target = _map[color.toARGB32() & 0xFFFFFF];
    if (target == null) return color;
    return target.withValues(alpha: target.a * color.a);
  }

  @override
  bool operator ==(Object other) {
    if (other is! IllustrationColorMapper || other._map.length != _map.length) return false;
    for (final e in _map.entries) {
      if (other._map[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(_map.entries.map((e) => Object.hash(e.key, e.value)));
}

/// Ilustrasi SVG yang warnanya mengikuti tema.
///
/// Jika [semanticLabel] null, ilustrasi dianggap dekoratif dan disembunyikan
/// dari screen reader. Bila aset gagal dimuat, dirender kotak kosong seukuran
/// [size] agar tata letak tidak bergeser.
class AppIllustration extends StatelessWidget {
  const AppIllustration(this.asset, {super.key, this.size = 160, this.semanticLabel});

  /// Maskot Dompi dengan ekspresi [mood].
  AppIllustration.dompi(DompiMood mood, {super.key, this.size = 160, this.semanticLabel}) : asset = mood.asset;

  final String asset;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final box = SizedBox.square(dimension: size);
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorMapper: IllustrationColorMapper(context.colors),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      placeholderBuilder: (_) => box,
      errorBuilder: (_, _, _) => box,
    );
  }
}
