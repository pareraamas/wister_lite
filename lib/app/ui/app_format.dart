import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Format angka & tanggal bersama untuk komponen UI.
///
/// Nominal selalu tanpa desimal dengan pemisah ribuan titik ("Rp 25.000").
/// Nama bulan ditulis sendiri agar tidak bergantung pada
/// `initializeDateFormatting` (aman di test dan sebelum locale dimuat);
/// ikut bahasa aktif (`Get.locale`), default Indonesia.
abstract final class AppFormat {
  static final NumberFormat _digits = NumberFormat.decimalPattern('id_ID');

  /// Tanda minus tipografis (U+2212), lebih lebar dari tanda hubung.
  static const String minus = '−';

  static bool get _en => Get.locale?.languageCode == 'en';

  static List<String> get months => _en ? _monthsEn : _monthsId;

  static List<String> get monthsShort => _en ? _monthsShortEn : _monthsShortId;

  static const List<String> _monthsId = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _monthsShortId = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

  static const List<String> _monthsShortEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "25.000" — nilai absolut, dibulatkan, tanpa desimal.
  static String digits(num amount) => _digits.format(amount.abs().round());

  /// "Rp 25.000" — tanpa tanda.
  static String rupiah(num amount) => 'Rp ${digits(amount)}';

  /// "25.000 rupiah" — untuk label semantik screen reader.
  static String spokenRupiah(num amount) => '${digits(amount)} rupiah';

  /// "September 2026".
  static String monthYear(DateTime date) => '${months[date.month - 1]} ${date.year}';

  /// "Sep 2026".
  static String monthYearShort(DateTime date) => '${monthsShort[date.month - 1]} ${date.year}';

  /// "28 Sep".
  static String dayMonthShort(DateTime date) => '${date.day} ${monthsShort[date.month - 1]}';
}
