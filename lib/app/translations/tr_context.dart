import 'package:get/get.dart';

extension ContextTr on String {
  /// Untuk kata yang terjemahannya beda per konteks ("Keluar" akun = "Sign out",
  /// uang keluar = "Out"). Key `konteks:teks` dicari dulu, lalu `teks` biasa.
  String trIn(String context) {
    final key = '$context:$this';
    final value = key.tr;
    return value == key ? tr : value;
  }
}
