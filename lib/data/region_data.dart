import 'dart:convert';

import 'package:flutter/services.dart';

/// 省市区三级名单（assets/data/regions.json，公开行政区划数据，
/// 只留名称：省 → 市 → 区县，共 31 省级、342 市、3056 区县）。
/// 第一次用时异步加载并缓存，之后同步取。直辖市在数据里已把
/// 「市辖区」并成市名本身（北京市的市一级就是北京市）。
class RegionData {
  static Map<String, Map<String, List<String>>> _data = const {};
  static Future<void>? _loading;

  static bool get isLoaded => _data.isNotEmpty;

  static Future<void> ensureLoaded() {
    if (isLoaded) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/regions.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _data = decoded.map(
      (province, cities) => MapEntry(
        province,
        (cities as Map<String, dynamic>).map(
          (city, districts) => MapEntry(city, (districts as List).cast<String>()),
        ),
      ),
    );
  }

  static List<String> get provinces => _data.keys.toList();

  static List<String> citiesOf(String province) => _data[province]?.keys.toList() ?? const [];

  static List<String> districtsOf(String province, String city) => _data[province]?[city] ?? const [];
}

/// 一次省市区选择结果。district 可能为空（市认出了、区县没选/没认出）。
typedef RegionSelection = ({String province, String city, String district});

/// 选择结果的展示文案：直辖市省市同名只写一遍。
String regionLabel(RegionSelection region) => [
      region.province,
      if (region.city != region.province) region.city,
      if (region.district.isNotEmpty) region.district,
    ].join(' ');

/// 拼回要存进地址 detail 的整句：省 市 区县 + 街道门牌，空格分隔
/// （服务端只存一个 detail 字符串，订单页等处都按整句展示；
/// 直辖市省市同名不重复写）。
String composeDetail(RegionSelection region, String street) => [
      region.province,
      if (region.city != region.province) region.city,
      if (region.district.isNotEmpty) region.district,
      street.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

/// 把已存的 detail 拆回「省市区 + 剩余街道」：编辑老地址时用。
/// 靠名单从头往后认（同级按名字长到短试，防前缀误认）：认出
/// 省、市才算拆到，区县认不出就留空；只认出省、或都没认出，
/// 返回 region 为空、整句原样留在 rest 里，一个字不丢。
/// 直辖市：detail 里可能是「北京市 东城区…」（省市合并写）也
/// 可能是「北京市 北京市 东城区…」，两种都认。
({RegionSelection? region, String rest}) splitRegionFromDetail(String detail) {
  final text = detail.trim();
  if (text.isEmpty || !RegionData.isLoaded) return (region: null, rest: text);
  List<String> byLengthDesc(List<String> names) => [...names]..sort((a, b) => b.length.compareTo(a.length));
  for (final province in byLengthDesc(RegionData.provinces)) {
    if (!text.startsWith(province)) continue;
    var rest = text.substring(province.length).trimLeft();
    for (final city in byLengthDesc(RegionData.citiesOf(province))) {
      // 直辖市省市同名：先试不带市名、直接认区县的那种写法。
      if (city == province) {
        for (final district in byLengthDesc(RegionData.districtsOf(province, city))) {
          if (rest.startsWith(district)) {
            return (region: (province: province, city: city, district: district), rest: rest.substring(district.length).trim());
          }
        }
      }
      if (!rest.startsWith(city)) continue;
      final rest2 = rest.substring(city.length).trimLeft();
      for (final district in byLengthDesc(RegionData.districtsOf(province, city))) {
        if (rest2.startsWith(district)) {
          return (region: (province: province, city: city, district: district), rest: rest2.substring(district.length).trim());
        }
      }
      // 市认出了、区县没认出：也算拆到，区县留空让用户补选。
      return (region: (province: province, city: city, district: ''), rest: rest2.trim());
    }
    // 只认出省：多半是随手打的，不硬拆。
    return (region: null, rest: text);
  }
  return (region: null, rest: text);
}
