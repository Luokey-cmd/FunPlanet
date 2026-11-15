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

const MAX_BYTES = 4 * 1024 * 1024;

export function saveUserAvatar({ userId, imageBase64, mimeType }) {
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
    throw new Error('头像大小需在 4MB 以内');
  }

  const safeId = String(userId).replace(/[^a-zA-Z0-9_-]/g, '_');
  const dir = path.join(assetsRoot, 'images/user-avatars');
  fs.mkdirSync(dir, { recursive: true });

  const filename = `${safeId}.${ext}`;
  fs.writeFileSync(path.join(dir, filename), buffer);

  return `assets/images/user-avatars/${filename}`;
}

export function isDisplayableAvatarPath(avatarPath) {
  const p = String(avatarPath ?? '').trim();
  if (!p) return false;
  return p.startsWith('assets/') || p.startsWith('http://') || p.startsWith('https://');
}
