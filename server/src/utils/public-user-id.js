/** 对外展示的 4 位用户 ID（1000–9999）。 */
export async function allocatePublicUserId(prisma, { reserved = new Set() } = {}) {
  const rows = await prisma.user.findMany({ select: { userId: true } });
  const used = new Set([...reserved, ...rows.map((row) => row.userId)]);
  for (let n = 1000; n <= 9999; n += 1) {
    const id = String(n);
    if (!used.has(id)) return id;
  }
  throw new Error('四位用户 ID 已用尽');
}
