import 'package:flutter/foundation.dart';
import '../widgets/app_tab_bar.dart';

class AppTabProvider extends ChangeNotifier {
  void Function(AppTab)? _navigate;

  void attach(void Function(AppTab tab) navigate) => _navigate = navigate;

  void detach() => _navigate = null;

  void goTo(AppTab tab) => _navigate?.call(tab);
}
