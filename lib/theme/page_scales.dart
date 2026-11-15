import 'app_scale.dart';

/// 首页、商城页组件放大系数（+20%）
const homeMallPageScale = 1.2;

double hmS(double value) => AppScale.s(value * homeMallPageScale);
