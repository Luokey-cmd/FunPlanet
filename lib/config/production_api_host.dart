/// 正式 APK 连接的线上 API 地址（部署 server 到云服务器后填写）。
/// 必须是手机能访问的公网地址，推荐 HTTPS，不要末尾斜杠。
/// 例如：https://api.yourdomain.com
///
/// 打包正式 APK：scripts/build-apk-production.ps1
const String kProductionApiBaseUrl = 'http://8.134.249.51:3000';
