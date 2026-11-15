const BANNER_PATH_PREFIX = /^素材[/\\]图片[/\\]横幅[/\\]/i;
const PRODUCT_PATH_PREFIX = /^素材[/\\]图片[/\\](?:商品|products)[/\\]/i;

/** 统一 imagePath 为可静态访问的路径 */
export function normalizeAssetPath(imagePath: string): string {
  let path = imagePath.trim().replace(/\\/g, "/");
  if (BANNER_PATH_PREFIX.test(path)) {
    path = path.replace(BANNER_PATH_PREFIX, "assets/images/banners/");
  } else if (PRODUCT_PATH_PREFIX.test(path)) {
    path = path.replace(PRODUCT_PATH_PREFIX, "assets/images/products/");
  } else if (!path.startsWith("assets/") && /^banner\d+\.(png|jpe?g|webp)$/i.test(path)) {
    path = `assets/images/banners/${path}`;
  }
  return path;
}

/** 将数据库中的 imagePath 转为可请求的 URL */
export function resolveAssetUrl(imagePath: string | null | undefined): string {
  if (!imagePath?.trim()) return "";
  const trimmed = imagePath.trim();
  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed;
  const normalized = normalizeAssetPath(trimmed);
  return normalized.startsWith("/") ? normalized : `/${normalized}`;
}
