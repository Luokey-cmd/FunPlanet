import { Router } from 'express';
import { prisma } from '../db.js';
import { authRequired } from '../middleware/auth.js';
import { fail, ok } from '../utils/response.js';

const router = Router();

// 地址展示文字拼法：省+市+区+detail(街道门牌)。老地址没有省市区字段（空文字），拼出来就是原来的 detail，不变样
export function composeDetail(row) {
  const parts = [row.province, row.city, row.district].filter(Boolean).join('');
  const detail = row.detail ?? '';
  if (parts && detail && !detail.startsWith(parts)) return parts + detail;
  return detail || parts;
}

function serializeAddress(row) {
  return {
    id: row.id,
    name: row.name,
    phone: row.phone,
    // detail 保持整段文字返回（老 App 只读这个）；province/city/district 是拆开的新字段，新页面可直接用
    detail: composeDetail(row),
    province: row.province ?? '',
    city: row.city ?? '',
    district: row.district ?? '',
    streetDetail: row.detail ?? '',
    isDefault: row.isDefault,
  };
}

// 从请求里取地址字段：带省市区时 detail 只存街道段；老 App 只传整段 detail 时原样存、省市区留空
function readAddressParts(body) {
  const province = String(body?.province ?? '').trim();
  const city = String(body?.city ?? '').trim();
  const district = String(body?.district ?? '').trim();
  let detail = String(body?.detail ?? '').trim();
  if (province || city || district) {
    const prefix = province + city + district;
    if (detail.startsWith(prefix)) detail = detail.slice(prefix.length);
    const street = String(body?.streetDetail ?? '').trim();
    if (street) detail = street;
  }
  return { province, city, district, detail };
}

function validateAddressInput(name, phone, detail) {
  if (!name) return '请填写收货人';
  if (!phone) return '请填写手机号';
  if (!detail) return '请填写详细地址';
  return null;
}

router.get('/', authRequired, async (req, res) => {
  const rows = await prisma.address.findMany({
    where: { userId: req.user.sub },
    orderBy: [{ isDefault: 'desc' }, { updatedAt: 'desc' }],
  });
  ok(res, { addresses: rows.map(serializeAddress) });
});

router.post('/', authRequired, async (req, res) => {
  const name = String(req.body?.name ?? '').trim();
  const phone = String(req.body?.phone ?? '').trim();
  const { province, city, district, detail } = readAddressParts(req.body);
  const isDefault = Boolean(req.body?.isDefault);

  const inputError = validateAddressInput(name, phone, detail);
  if (inputError) return fail(res, 400, inputError);

  const row = await prisma.$transaction(async (tx) => {
    if (isDefault) {
      await tx.address.updateMany({
        where: { userId: req.user.sub },
        data: { isDefault: false },
      });
    }
    const count = await tx.address.count({ where: { userId: req.user.sub } });
    return tx.address.create({
      data: {
        userId: req.user.sub,
        name,
        phone,
        detail,
        province,
        city,
        district,
        isDefault: isDefault || count === 0,
      },
    });
  });

  ok(res, { address: serializeAddress(row) });
});

router.put('/:id/default', authRequired, async (req, res) => {
  const id = String(req.params.id ?? '').trim();
  const existing = await prisma.address.findFirst({
    where: { id, userId: req.user.sub },
  });
  if (!existing) return fail(res, 404, '地址不存在');

  const row = await prisma.$transaction(async (tx) => {
    await tx.address.updateMany({
      where: { userId: req.user.sub },
      data: { isDefault: false },
    });
    return tx.address.update({
      where: { id },
      data: { isDefault: true },
    });
  });

  ok(res, { address: serializeAddress(row) });
});

router.put('/:id', authRequired, async (req, res) => {
  const id = String(req.params.id ?? '').trim();
  const name = String(req.body?.name ?? '').trim();
  const phone = String(req.body?.phone ?? '').trim();
  const { province, city, district, detail } = readAddressParts(req.body);
  const isDefault = Boolean(req.body?.isDefault);

  const existing = await prisma.address.findFirst({
    where: { id, userId: req.user.sub },
  });
  if (!existing) return fail(res, 404, '地址不存在');

  const inputError = validateAddressInput(name, phone, detail);
  if (inputError) return fail(res, 400, inputError);

  const row = await prisma.$transaction(async (tx) => {
    if (isDefault) {
      await tx.address.updateMany({
        where: { userId: req.user.sub },
        data: { isDefault: false },
      });
    }
    return tx.address.update({
      where: { id },
      data: { name, phone, detail, province, city, district, isDefault: isDefault || existing.isDefault },
    });
  });

  ok(res, { address: serializeAddress(row) });
});

router.delete('/:id', authRequired, async (req, res) => {
  const id = String(req.params.id ?? '').trim();
  const existing = await prisma.address.findFirst({
    where: { id, userId: req.user.sub },
  });
  if (!existing) return fail(res, 404, '地址不存在');

  await prisma.$transaction(async (tx) => {
    await tx.address.delete({ where: { id } });
    if (existing.isDefault) {
      const next = await tx.address.findFirst({
        where: { userId: req.user.sub },
        orderBy: { updatedAt: 'desc' },
      });
      if (next) {
        await tx.address.update({ where: { id: next.id }, data: { isDefault: true } });
      }
    }
  });

  ok(res, { removed: true });
});

export default router;
