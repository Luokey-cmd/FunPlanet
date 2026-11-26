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

  // 文件名带时间戳、每次上传都换新名（2026-11-26 修）：旧版固定用
  // 「用户id.扩展名」，新头像覆盖旧文件、网址一个字不变，而 App 的
  // 网络图片带磁盘缓存、按网址存图——网址不变就永远端出第一次存的
  // 那张，表现就是「保存成功了但头像没换过来」。换新名 = 换新网址，
  // 缓存自然失效；同时把该用户之前的头像文件删掉，免得目录越堆越多。
  const filename = `${safeId}-${Date.now().toString(36)}.${ext}`;
  fs.writeFileSync(path.join(dir, filename), buffer);
  for (const old of fs.readdirSync(dir)) {
    if (old !== filename && (old.startsWith(`${safeId}-`) || old.startsWith(`${safeId}.`))) {
      try { fs.unlinkSync(path.join(dir, old)); } catch { /* 删不掉不挡上传 */ }
    }
  }

  return `assets/images/user-avatars/${filename}`;
}

export function isDisplayableAvatarPath(avatarPath) {
  const p = String(avatarPath ?? '').trim();
  if (!p) return false;
  return p.startsWith('assets/') || p.startsWith('http://') || p.startsWith('https://');
}
