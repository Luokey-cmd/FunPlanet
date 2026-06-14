import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const assetsRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../assets');

export const IMAGE_MIME_EXT = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

const MAX_BYTES = 8 * 1024 * 1024;

export function saveAdminAssetImage({ imageBase64, mimeType, subdir }) {
  const type = String(mimeType ?? '');
  const ext = IMAGE_MIME_EXT[type];
  if (!ext || !imageBase64) {
    throw new Error('请上传 JPG、PNG、WebP 或 GIF 图片');
  }

  let buffer;
  try {
    buffer = Buffer.from(String(imageBase64), 'base64');
  } catch {
    throw new Error('图片数据无效');
  }

  if (buffer.length === 0 || buffer.length > MAX_BYTES) {
    throw new Error('图片大小需在 8MB 以内');
  }

  const safeSubdir = String(subdir ?? '').replace(/\\/g, '/').replace(/^\/+|\/+$/g, '');
  if (!safeSubdir || safeSubdir.includes('..')) {
    throw new Error('无效的上传目录');
  }

  const dir = path.join(assetsRoot, safeSubdir);
  fs.mkdirSync(dir, { recursive: true });

  const filename = `${crypto.randomUUID()}.${ext}`;
  fs.writeFileSync(path.join(dir, filename), buffer);

  return `assets/${safeSubdir}/${filename}`;
}
