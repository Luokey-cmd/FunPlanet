/// 会话内页面内存缓存：二次进入先渲染旧数据，再静默刷新（参考 peduliAI PeduliPageMemoryCache）。
class PageMemoryCache {
  PageMemoryCache._();

  static final Map<String, Object> _store = <String, Object>{};
  static final List<void Function()> _clearListeners = <void Function()>[];

  static const products = 'shop_products';
  static const orders = 'shop_orders';
  static const favorites = 'user_favorites';
  static const browseHistory = 'user_browse_history';
  static const aiCommunity = 'ai_community_feed';

  static String _key(String page, {String? userId}) {
    final uid = (userId ?? 'guest').trim();
    return '${uid.isEmpty ? 'guest' : uid}|$page';
  }

  static T? read<T>(String page, {String? userId}) {
    final v = _store[_key(page, userId: userId)];
    if (v is T) return v;
    return null;
  }

  static void write(String page, Object value, {String? userId}) {
    _store[_key(page, userId: userId)] = value;
  }

  static void remove(String page, {String? userId}) {
    _store.remove(_key(page, userId: userId));
  }

  static void addClearListener(void Function() listener) {
    if (_clearListeners.contains(listener)) return;
    _clearListeners.add(listener);
  }

  static void clearAll() {
    _store.clear();
    for (final fn in List<void Function()>.of(_clearListeners)) {
      try {
        fn();
      } catch (_) {}
    }
  }
}
