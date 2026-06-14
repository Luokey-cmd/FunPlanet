import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { signToken } from '../utils/jwt.js';
import { fail, ok } from '../utils/response.js';

const router = Router();

function validatePhone(phone) {
  if (!/^1\d{10}$/.test(phone)) return '请输入正确的 11 位手机号';
  return null;
}

function validatePassword(password) {
  if (!password || password.length < 6) return '密码至少 6 位';
  return null;
}

function validateNickname(nickname) {
  const value = nickname?.trim() ?? '';
  if (value.length < 2) return '昵称至少 2 个字';
  if (value.length > 16) return '昵称最多 16 个字';
  return null;
}

function serializeUser(user) {
  return {
    id: user.id,
    phone: user.phone,
    nickname: user.nickname,
    userId: user.userId,
  };
}

function generateUserId(phone) {
  const suffix = phone.slice(-4);
  const stamp = Date.now().toString();
  return `${suffix}${stamp.slice(-6)}`;
}

router.post('/register', async (req, res) => {
  const phone = String(req.body?.phone ?? '').trim();
  const password = String(req.body?.password ?? '');
  const confirmPassword = String(req.body?.confirmPassword ?? password);
  const nickname = String(req.body?.nickname ?? '').trim();

  const phoneError = validatePhone(phone);
  if (phoneError) return fail(res, 400, phoneError);
  const nicknameError = validateNickname(nickname);
  if (nicknameError) return fail(res, 400, nicknameError);
  const passwordError = validatePassword(password);
  if (passwordError) return fail(res, 400, passwordError);
  if (password !== confirmPassword) return fail(res, 400, '两次输入的密码不一致');

  const exists = await prisma.user.findUnique({ where: { phone } });
  if (exists) return fail(res, 409, '该手机号已注册');

  const hash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: {
      phone,
      password: hash,
      nickname,
      userId: generateUserId(phone),
      profile: { create: { avatarPath: '', points: 0, funCoins: 0 } },
    },
  });

  const token = signToken({ sub: user.id, phone: user.phone });
  ok(res, { token, user: serializeUser(user) });
});

router.post('/login', async (req, res) => {
  const phone = String(req.body?.phone ?? '').trim();
  const password = String(req.body?.password ?? '');

  const phoneError = validatePhone(phone);
  if (phoneError) return fail(res, 400, phoneError);
  const passwordError = validatePassword(password);
  if (passwordError) return fail(res, 400, passwordError);

  const user = await prisma.user.findUnique({ where: { phone } });
  if (!user) return fail(res, 404, '账号不存在，请先注册');

  const match = await bcrypt.compare(password, user.password);
  if (!match) return fail(res, 401, '密码错误');

  const token = signToken({ sub: user.id, phone: user.phone });
  ok(res, { token, user: serializeUser(user) });
});

router.get('/me', authRequired, async (req, res) => {
  const user = await prisma.user.findUnique({ where: { id: req.user.sub } });
  if (!user) return fail(res, 404, '用户不存在');
  ok(res, { user: serializeUser(user) });
});

export default router;
