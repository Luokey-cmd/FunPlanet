/// Debug 联调时填写电脑局域网 IP（cmd 运行 ipconfig 查看）。
/// 只在本机填写，不要把局域网 IP 上传到公开仓库；不用时保持为空。
/// 正式 APK 请看 lib/config/production_api_host.dart 的说明，
/// 并用 scripts/build-apk-production.ps1 打包。
const String kLocalApiHostOverride = '';
