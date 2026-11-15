/// 正式 APK 连接的线上 API 地址。
///
/// 安全要求：不要把真实服务器地址（IP 或域名）写进这个文件再上传到
/// 公开仓库，否则任何人都能看到你的服务器在哪。
/// 本文件在仓库里保持为空，真实地址只在打包时提供，二选一：
///   1. 打包时传参：.\scripts\build-apk-production.ps1 -ApiUrl https://你的域名
///   2. 只在本机把地址填到下面，填完不要提交这个文件。
/// 必须是手机能访问的公网地址，必须 HTTPS，不要末尾斜杠。
/// 例如：https://api.yourdomain.com
const String kProductionApiBaseUrl = '';
