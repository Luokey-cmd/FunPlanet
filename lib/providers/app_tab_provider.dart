import 'package:flutter/foundation.dart';
import '../widgets/app_tab_bar.dart';

class AppTabProvider extends ChangeNotifier {
  void Function(AppTab)? _navigate;

  // 首页分类小按钮带过来的「待选商城分类」：在首页点某个分类时先记
  // 在这里，再切到商城页；商城页读到后选中同名分类并立刻清掉。
  // 一次性传递，清不掉的话商城页每次重建都会被强行拨回这个分类。
  String? _pendingMallCategory;
  String? get pendingMallCategory => _pendingMallCategory;

  void attach(void Function(AppTab tab) navigate) => _navigate = navigate;

  void detach() => _navigate = null;

  void goTo(AppTab tab) => _navigate?.call(tab);

  // 跳商城并选中指定分类，效果与在商城页里点那个分类按钮一致。
  void goToMallCategory(String categoryId) {
    _pendingMallCategory = categoryId;
    notifyListeners();
    goTo(AppTab.mall);
  }

  void clearPendingMallCategory() {
    if (_pendingMallCategory == null) return;
    _pendingMallCategory = null;
    notifyListeners();
  }
}
