/// Debug 联调时填写电脑局域网 IP（cmd 运行 ipconfig）。
/// 正式 APK 请配置 lib/config/production_api_host.dart 并用 scripts/build-apk-production.ps1 打包。
const String kLocalApiHostOverride = '192.168.172.184';
