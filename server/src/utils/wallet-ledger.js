export async function recordWalletLedger(tx, { userId, walletType, amount, title }) {
  await tx.walletLedger.create({
    data: { userId, walletType, amount, title },
  });
}

export function serializeLedger(entry) {
  return {
    id: entry.id,
    title: entry.title,
    amount: entry.amount,
    createdAt: entry.createdAt.toISOString(),
  };
}
