// 积分 / 趣币流水记账
//
// 输入：tx（事务对象，必须用调用方的事务，保证余额变动和流水同生共死）、
//       userId、walletType（points 积分 / coins 趣币）、amount（正加负减）、title（给人看的说明）、
//       refType / refId（可选，这笔流水是哪件事产生的，如 order + 订单 id）
// 输出：无返回值，流水行直接落库
// 坑：balanceAfter（变动后余额）在记账这一刻从 UserProfile 现读，所以调用顺序必须是
//     「先改余额、再记流水」，反过来余额快照就会差一笔。
export async function recordWalletLedger(tx, { userId, walletType, amount, title, refType = null, refId = null }) {
  let balanceAfter = null;
  try {
    const profile = await tx.userProfile.findUnique({ where: { userId } });
    if (profile) {
      balanceAfter = walletType === 'points' ? profile.points : profile.funCoins;
    }
  } catch {
    // 读不到余额就只记流水本身，不能因为快照失败把主流程（下单/签到）拖垮
    balanceAfter = null;
  }
  await tx.walletLedger.create({
    data: { userId, walletType, amount, title, refType, refId, balanceAfter },
  });
}

export function serializeLedger(entry) {
  return {
    id: entry.id,
    title: entry.title,
    amount: entry.amount,
    refType: entry.refType ?? null,
    refId: entry.refId ?? null,
    balanceAfter: entry.balanceAfter ?? null,
    createdAt: entry.createdAt.toISOString(),
  };
}
