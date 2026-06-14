import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { EditIcon, PlusIcon, XIcon, SearchIcon } from "lucide-react";
import { toast } from "sonner";
import { adminApi, type AdminCoupon, type AdminCouponCreate } from "../lib/api";

const emptyCoupon: AdminCouponCreate = {
  title: "",
  discount: 0,
  condition: "",
  expireAt: "",
};

function nextCouponId(coupons: AdminCoupon[]): string {
  let max = 0;
  for (const coupon of coupons) {
    const match = /^c(\d+)$/i.exec(coupon.id);
    if (match) max = Math.max(max, Number(match[1]));
  }
  return `c${max + 1}`;
}

export default function CouponsPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<AdminCouponCreate | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isNew, setIsNew] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-coupons"],
    queryFn: () => adminApi.coupons(),
  });

  const saveMutation = useMutation({
    mutationFn: async (coupon: AdminCouponCreate) => {
      if (isNew) return adminApi.createCoupon(coupon);
      return adminApi.updateCoupon(editingId!, coupon);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-coupons"] });
      toast.success(isNew ? "优惠券已创建" : "优惠券已更新");
      setEditing(null);
      setEditingId(null);
      setIsNew(false);
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const allCoupons = data?.coupons ?? [];
  const coupons = allCoupons.filter((c) => {
    if (!search.trim()) return true;
    const q = search.trim().toLowerCase();
    return (
      c.title.toLowerCase().includes(q) ||
      c.condition.toLowerCase().includes(q) ||
      c.id.toLowerCase().includes(q)
    );
  });

  const openCreate = () => {
    setIsNew(true);
    setEditingId(null);
    setEditing({ ...emptyCoupon });
  };

  const openEdit = (coupon: AdminCoupon) => {
    setIsNew(false);
    setEditingId(coupon.id);
    setEditing({
      title: coupon.title,
      discount: coupon.discount,
      condition: coupon.condition,
      expireAt: coupon.expireAt,
    });
  };

  const closeModal = () => {
    setEditing(null);
    setEditingId(null);
    setIsNew(false);
  };

  return (
    <div data-cmp="CouponsPage" className="p-6 flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-foreground">优惠券管理</h2>
          <p className="text-sm text-muted-foreground">共 {allCoupons.length} 张券模板，与 App 端同步</p>
        </div>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:opacity-90 transition-opacity"
        >
          <PlusIcon size={16} />
          添加优惠券
        </button>
      </div>

      <div className="relative w-56">
        <SearchIcon size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input
          type="text"
          placeholder="搜索优惠券……"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="pl-9 pr-4 py-2 text-sm bg-card border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring w-full"
        />
      </div>

      {isLoading ? (
        <p className="text-muted-foreground">加载中…</p>
      ) : coupons.length === 0 ? (
        <p className="text-muted-foreground text-center py-12">暂无优惠券，点击上方按钮添加</p>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {coupons.map((coupon) => (
            <div
              key={coupon.id}
              className="bg-card rounded-2xl border border-border shadow-custom p-5 relative overflow-hidden"
            >
              <div className="absolute top-0 right-0 w-24 h-24 rounded-full bg-primary/10 -translate-y-1/2 translate-x-1/2" />
              <div className="flex items-start justify-between relative">
                <div>
                  <p className="text-3xl font-bold text-primary">¥{coupon.discount}</p>
                  <p className="text-sm font-medium text-foreground mt-1">{coupon.title}</p>
                  <p className="text-xs text-muted-foreground mt-1">{coupon.condition}</p>
                </div>
                <button
                  onClick={() => openEdit(coupon)}
                  className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center hover:bg-primary/20 transition-colors"
                >
                  <EditIcon size={14} className="text-muted-foreground" />
                </button>
              </div>
              <div className="mt-4 pt-4 border-t border-border flex justify-between text-xs text-muted-foreground">
                <span>到期 {coupon.expireAt}</span>
                <span>{coupon.id}</span>
              </div>
            </div>
          ))}
        </div>
      )}

      {editing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
          <div className="bg-card rounded-2xl border border-border shadow-custom w-full max-w-sm p-6">
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-semibold text-foreground">{isNew ? "添加优惠券" : "编辑优惠券"}</h3>
              <button onClick={closeModal}>
                <XIcon size={18} className="text-muted-foreground" />
              </button>
            </div>
            <form
              className="flex flex-col gap-3"
              onSubmit={(e) => {
                e.preventDefault();
                if (!editing.title.trim() || !editing.condition.trim() || !editing.expireAt) {
                  toast.error("请填写完整信息");
                  return;
                }
                if (editing.discount <= 0) {
                  toast.error("减免金额须大于 0");
                  return;
                }
                saveMutation.mutate(editing);
              }}
            >
              {!isNew && editingId && (
                <p className="text-sm text-muted-foreground">
                  券 ID：<span className="text-foreground font-medium">{editingId}</span>
                </p>
              )}
              {isNew && (
                <p className="text-xs text-muted-foreground">
                  券 ID 将在保存时自动生成（{nextCouponId(allCoupons)}）
                </p>
              )}
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">标题</span>
                <input
                  value={editing.title}
                  onChange={(e) => setEditing({ ...editing, title: e.target.value })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">使用条件</span>
                <input
                  value={editing.condition}
                  onChange={(e) => setEditing({ ...editing, condition: e.target.value })}
                  placeholder="满99可用"
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">到期日 (YYYY-MM-DD)</span>
                <input
                  value={editing.expireAt}
                  onChange={(e) => setEditing({ ...editing, expireAt: e.target.value })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">减免金额</span>
                <input
                  type="number"
                  min={1}
                  value={editing.discount}
                  onChange={(e) => setEditing({ ...editing, discount: Number(e.target.value) })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <div className="flex gap-3 mt-2">
                <button
                  type="submit"
                  disabled={saveMutation.isPending}
                  className="flex-1 py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-medium disabled:opacity-60"
                >
                  {saveMutation.isPending ? "保存中…" : "保存"}
                </button>
                <button
                  type="button"
                  onClick={closeModal}
                  className="flex-1 py-2.5 rounded-xl border border-border text-sm text-muted-foreground"
                >
                  取消
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
