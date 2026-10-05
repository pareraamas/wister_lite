import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wister_lite/app/config/app_env.dart';
import 'package:wister_lite/app/data/api/fake_wister_api.dart';
import 'package:wister_lite/app/data/api/http_wister_api.dart';
import 'package:wister_lite/app/data/api/wister_api.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/data/services/ad_service.dart';
import 'package:wister_lite/app/data/services/auth_service.dart';
import 'package:wister_lite/app/data/services/home_widget_service.dart';
import 'package:wister_lite/app/data/services/share_service.dart';
import 'package:wister_lite/app/data/services/sync_service.dart';

class InitialBinding extends Bindings {
  InitialBinding(this.prefs);

  final SharedPreferences prefs;

  @override
  void dependencies() {
    final WisterApi api = AppEnv.useFakeApi ? FakeWisterApi() : HttpWisterApi(AppEnv.apiBaseUrl);
    Get.put<ExpenseRepository>(ExpenseRepository(), permanent: true);
    Get.put<ShareService>(ShareService(), permanent: true);
    Get.put<HomeWidgetService>(HomeWidgetService(), permanent: true);
    Get.put<AuthService>(AuthService(prefs, api), permanent: true);
    Get.put<AdService>(AdService(prefs), permanent: true);
    Get.put<SyncService>(SyncService(prefs, api), permanent: true);
  }
}
