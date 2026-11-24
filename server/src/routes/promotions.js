import { Router } from 'express';
import { ok } from '../utils/response.js';
import { listActiveThresholdPromotions } from '../utils/promotions.js';

const router = Router();

// 当前生效的满减档（公开只读）：结算页拿去展示「已享满减/还差多少」，
// 真正的减额在下单时由服务端复算，这里给的只是展示口径。
router.get('/active', async (req, res) => {
  const thresholds = await listActiveThresholdPromotions();
  ok(res, { thresholds });
});

export default router;
