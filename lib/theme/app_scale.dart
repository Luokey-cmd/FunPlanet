/// 全局 UI 尺寸缩放（基准 1.0 对应 1080×2412 竖屏逻辑尺寸）
class AppScale {
  static const factor = 0.8;

  static double s(double value) => value * factor;
}
