interface RecentOrderItem {
  id: string;
  user: string;
  products: string;
  amount: number;
  status: string;
  statusLabel: string;
}

const statusConfig: Record<string, { color: string }> = {
  pending: { color: "#ffb74d" },
  paid: { color: "#4cb9d6" },
  shipping: { color: "#2e9bb8" },
  completed: { color: "#66bb6a" },
  returned: { color: "#e57373" },
  cancelled: { color: "#e57373" },
};

interface RecentOrdersProps {
  orders?: RecentOrderItem[];
  limit?: number;
}

export default function RecentOrders({ orders = [], limit = 6 }: RecentOrdersProps) {
  const list = orders.slice(0, limit);

  return (
    <div data-cmp="RecentOrders" className="bg-card rounded-2xl p-5 border border-border shadow-custom">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="font-semibold text-foreground">最新订单</h3>
          <p className="text-xs text-muted-foreground mt-0.5">实时订单动态</p>
        </div>
      </div>
      {list.length === 0 ? (
        <p className="text-sm text-muted-foreground py-8 text-center">暂无订单</p>
      ) : (
        <div className="flex flex-col gap-3">
          {list.map((order) => {
            const cfg = statusConfig[order.status] ?? { color: "#8bb4c4" };
            return (
              <div
                key={order.id}
                className="flex items-center gap-3 p-3 rounded-xl hover:bg-muted transition-colors"
              >
                <div className="w-9 h-9 rounded-xl bg-secondary flex items-center justify-center text-lg flex-shrink-0">
                  📦
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-foreground">{order.user}</span>
                    <span className="text-xs text-muted-foreground">{order.id}</span>
                  </div>
                  <p className="text-xs text-muted-foreground truncate mt-0.5">{order.products}</p>
                </div>
                <div className="flex flex-col items-end gap-1">
                  <span className="text-sm font-semibold text-foreground">¥{order.amount}</span>
                  <span
                    className="text-xs px-2 py-0.5 rounded-full font-medium"
                    style={{ color: cfg.color, backgroundColor: `${cfg.color}22` }}
                  >
                    {order.statusLabel}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
