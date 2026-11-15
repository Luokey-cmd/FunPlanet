/// 全局 UI 尺寸缩放（基准 1.0 对应 1080×2412 竖屏逻辑尺寸）
class AppScale {
  static const factor = 0.8;

  /// 字号额外加大（原先三号，楷书视觉偏小后再加大两号）
  static const fontBump = 5.0;

  static double s(double value) => value * factor;

  static double t(double value) => s(value) + fontBump;
}
