import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const assetsRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../assets');

const MIME_EXT = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

const MAX_BYTES = 8 * 1024 * 1024;
const ALLOWED_PREFIXES = ['assets/images/ai-community/', 'assets/images/ai-art/', 'assets/images/reviews/'];

export function saveCommunityImage({ imageBase64, mimeType }) {
  const type = String(mimeType ?? '');
  const ext = MIME_EXT[type];
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

  const dir = path.join(assetsRoot, 'images/ai-community');
  fs.mkdirSync(dir, { recursive: true });

  const filename = `${crypto.randomUUID()}.${ext}`;
  fs.writeFileSync(path.join(dir, filename), buffer);

  return `assets/images/ai-community/${filename}`;
}

export function isAllowedCommunityImagePath(imagePath) {
  const value = String(imagePath ?? '').trim();
  if (!value) return true;
  return ALLOWED_PREFIXES.some((prefix) => value.startsWith(prefix));
}

export async function assertUserOwnsImagePath(imagePath, userId) {
  const value = String(imagePath ?? '').trim();
  if (!value) return;
  if (!isAllowedCommunityImagePath(value)) {
    throw new Error('图片路径无效');
  }
  if (value.startsWith('assets/images/ai-art/')) {
    const safeUserId = String(userId).replace(/[^a-zA-Z0-9_-]/g, '_');
    if (!value.includes(`/ai-art/${safeUserId}/`)) {
      throw new Error('只能使用自己的 AI 绘画作品');
    }
  }
}
