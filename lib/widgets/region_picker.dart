import 'package:flutter/material.dart';

import '../data/region_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';

/// 省市区三级选择（hx 2026-11-27 拍板真做）：底部弹层三列并排——
/// 省 / 市 / 区县，点省换市列、点市换区县列，选中项紫字加浅底；
/// 点「确定」回选择结果，关掉弹层（右上叉/点外侧）返回 null。
/// 地址编辑页与小豆对话里的地址小表共用这一份，两处长得一致。
/// 输入 initial 是打开时的预选（编辑老地址时带入拆出的省市区）。
Future<RegionSelection?> showRegionPicker(BuildContext context, {RegionSelection? initial}) async {
  await RegionData.ensureLoaded();
  if (!context.mounted) return null;
  return showModalBottomSheet<RegionSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppScale.s(16))),
    ),
    builder: (_) => _RegionPickerSheet(initial: initial),
  );
}

class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet({this.initial});

  final RegionSelection? initial;

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  late String _province;
  late String _city;
  late String _district;

  @override
  void initState() {
    super.initState();
    final provinces = RegionData.provinces;
    _province = widget.initial?.province ?? (provinces.isEmpty ? '' : provinces.first);
    if (!provinces.contains(_province)) _province = provinces.isEmpty ? '' : provinces.first;
    final cities = RegionData.citiesOf(_province);
    _city = widget.initial?.city ?? (cities.isEmpty ? '' : cities.first);
    if (!cities.contains(_city)) _city = cities.isEmpty ? '' : cities.first;
    final districts = RegionData.districtsOf(_province, _city);
    _district = widget.initial?.district ?? (districts.isEmpty ? '' : districts.first);
    if (!districts.contains(_district)) _district = districts.isEmpty ? '' : districts.first;
  }

  void _pickProvince(String province) {
    final cities = RegionData.citiesOf(province);
    final city = cities.isEmpty ? '' : cities.first;
    final districts = RegionData.districtsOf(province, city);
    setState(() {
      _province = province;
      _city = city;
      _district = districts.isEmpty ? '' : districts.first;
    });
  }

  void _pickCity(String city) {
    final districts = RegionData.districtsOf(_province, city);
    setState(() {
      _city = city;
      _district = districts.isEmpty ? '' : districts.first;
    });
  }

  Widget _column(List<String> items, String selected, ValueChanged<String> onPick) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item == selected;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(item),
          child: Container(
            height: AppScale.s(40),
            alignment: Alignment.center,
            color: isSelected ? AppColors.secondary : Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: AppScale.s(4)),
            child: Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppScale.t(13),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.foreground,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.62;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(14), AppScale.s(8), AppScale.s(6)),
            child: Row(
              children: [
                Text(
                  '选择省市区',
                  style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.w700, color: AppColors.foreground),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: AppScale.s(20), color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _column(RegionData.provinces, _province, _pickProvince)),
                Expanded(child: _column(RegionData.citiesOf(_province), _city, _pickCity)),
                Expanded(
                  child: _column(RegionData.districtsOf(_province, _city), _district, (d) => setState(() => _district = d)),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(10), AppScale.s(16), AppScale.s(12)),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(
                  (province: _province, city: _city, district: _district),
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: AppScale.s(11)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8A5FD6), AppColors.primary]),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '确定',
                    style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
