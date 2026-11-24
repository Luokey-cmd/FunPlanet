import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { EditIcon, MegaphoneIcon, PlusIcon, TrashIcon, XIcon } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import {
  adminApi,
  ApiError,
  type AdminPromotion,
  type PromotionInput,
} from "../lib/api";

// 营销中心（2026-11-24 新增）：满减 + 限时特价两类活动。
// 计价口径在服务端 utils/promotions.js：满减按小计（含特价）判门槛、
// 多档取最优、与优惠券可叠加；特价在下单组行时直接换单价。
// 这里只管活动的存取，状态（未开始/进行中/已结束/已停用）按时间现算。
interface FormState {
  name: string;
  type: "threshold" | "flash";
  thresholdAmount: string;
  discountAmount: string;
  startsAt: string;
  endsAt: string;
  isActive: boolean;
  items: { productId: string; productName: string; productPrice: number; promoPrice: string }[];
}

const emptyForm: FormState = {
  name: "",
  type: "threshold",
  thresholdAmount: "",
  discountAmount: "",
  startsAt: "",
  endsAt: "",
  isActive: true,
  items: [],
};

function toLocalInput(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function statusOf(p: AdminPromotion): { label: string; cls: string } {
  if (!p.isActive) return { label: "已停用", cls: "bg-red-100 text-red-600" };
  const now = Date.now();
  if (now < new Date(p.startsAt).getTime()) return { label: "未开始", cls: "bg-amber-100 text-amber-600" };
  if (now > new Date(p.endsAt).getTime()) return { label: "已结束", cls: "bg-gray-200 text-gray-500" };
  return { label: "进行中", cls: "bg-emerald-100 text-emerald-600" };
}

function fmtTime(iso: string): string {
  return new Date(iso).toLocaleString("zh-CN", { hour12: false }).replaceAll("-", "/");
}

const inputCls =
  "px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring";

export default function MarketingPage() {
  const queryClient = useQueryClient();
  const [editing, setEditing] = useState<FormState | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [pickProductId, setPickProductId] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["admin-promotions"],
    queryFn: () => adminApi.promotions(),
  });
  const productsQuery = useQuery({
    queryKey: ["admin-products"],
    queryFn: () => adminApi.products(),
    enabled: editing != null,
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["admin-promotions"] });

  const saveMutation = useMutation({
    mutationFn: (payload: { id: string | null; body: PromotionInput }) =>
      payload.id ? adminApi.updatePromotion(payload.id, payload.body) : adminApi.createPromotion(payload.body),
    onSuccess: () => {
      invalidate();
      toast.success(editingId ? "活动已保存" : "活动已创建");
      setEditing(null);
      setEditingId(null);
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "保存失败"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deletePromotion(id),
    onSuccess: () => {
      invalidate();
      toast.success("活动已删除");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "删除失败"),
  });

  const promotions = data?.promotions ?? [];
  const allProducts = productsQuery.data?.products ?? [];

  const openCreate = () => {
    const now = new Date();
    const week = new Date(now.getTime() + 7 * 24 * 3600 * 1000);
    setEditingId(null);
    setEditing({ ...emptyForm, startsAt: toLocalInput(now.toISOString()), endsAt: toLocalInput(week.toISOString()) });
    setPickProductId("");
  };

  const openEdit = (p: AdminPromotion) => {
    setEditingId(p.id);
    setEditing({
      name: p.name,
      type: p.type,
      thresholdAmount: p.thresholdAmount != null ? String(p.thresholdAmount) : "",
      discountAmount: p.discountAmount != null ? String(p.discountAmount) : "",
      startsAt: toLocalInput(p.startsAt),
      endsAt: toLocalInput(p.endsAt),
      isActive: p.isActive,
      items: p.items.map((item) => ({
        productId: item.productId,
        productName: item.productName ?? "",
        productPrice: item.productPrice ?? 0,
        promoPrice: String(item.promoPrice),
      })),
    });
    setPickProductId("");
  };

  const submit = () => {
    if (!editing) return;
    const body: PromotionInput = {
      name: editing.name.trim(),
      type: editing.type,
      startsAt: new Date(editing.startsAt).toISOString(),
      endsAt: new Date(editing.endsAt).toISOString(),
      isActive: editing.isActive,
    };
    if (editing.type === "threshold") {
      body.thresholdAmount = Number(editing.thresholdAmount);
      body.discountAmount = Number(editing.discountAmount);
    } else {
      body.items = editing.items.map((item) => ({
        productId: item.productId,
        promoPrice: Number(item.promoPrice),
      }));
    }
    saveMutation.mutate({ id: editingId, body });
  };

  const addPickedProduct = () => {
    if (!editing || !pickProductId) return;
    const product = allProducts.find((p) => p.id === pickProductId);
    if (!product) return;
    if (editing.items.some((item) => item.productId === product.id)) {
      toast.error("这件商品已经在特价清单里了");
      return;
    }
    setEditing({
      ...editing,
      items: [
        ...editing.items,
        { productId: product.id, productName: product.name, productPrice: product.price, promoPrice: "" },
      ],
    });
    setPickProductId("");
  };

  return (
    <div data-cmp="MarketingPage" className="p-6 flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-foreground">营销中心</h2>
          <p className="text-sm text-muted-foreground">
            满减与限时特价：满减按小计（含特价）判门槛、多档取最优、与优惠券可叠加；特价直接按下单价结算
          </p>
        </div>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:opacity-90 transition-opacity"
        >
          <PlusIcon size={15} />
          新建活动
        </button>
      </div>

      {isLoading ? (
        <p className="text-muted-foreground">加载中…</p>
      ) : promotions.length === 0 ? (
        <p className="text-muted-foreground text-center py-12">暂无营销活动，点击上方按钮新建</p>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {promotions.map((p) => {
            const st = statusOf(p);
            return (
              <div key={p.id} className="bg-card rounded-2xl border border-border shadow-custom p-5 relative overflow-hidden">
                <div className="flex items-start justify-between">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className={`text-xs px-2 py-0.5 rounded-full ${p.type === "flash" ? "bg-primary/10 text-primary" : "bg-orange-100 text-orange-600"}`}>
                        {p.type === "flash" ? "限时特价" : "满减"}
                      </span>
                      <span className={`text-xs px-2 py-0.5 rounded-full ${st.cls}`}>{st.label}</span>
                    </div>
                    <p className="text-base font-semibold text-foreground mt-2">{p.name}</p>
                    {p.type === "threshold" ? (
                      <p className="text-sm text-muted-foreground mt-1">
                        全店满 ¥{p.thresholdAmount} 减 ¥{p.discountAmount}
                      </p>
                    ) : (
                      <p className="text-sm text-muted-foreground mt-1">
                        {p.items.length} 件商品特价中
                        {p.items.length > 0 && `：${p.items.map((i) => i.productName).slice(0, 3).join("、")}${p.items.length > 3 ? "…" : ""}`}
                      </p>
                    )}
                    <p className="text-xs text-muted-foreground mt-2">
                      {fmtTime(p.startsAt)} 至 {fmtTime(p.endsAt)}
                    </p>
                  </div>
                  <div className="flex gap-1">
                    <button
                      onClick={() => openEdit(p)}
                      className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center hover:bg-primary/20 transition-colors"
                      title="编辑"
                    >
                      <EditIcon size={14} className="text-muted-foreground" />
                    </button>
                    <button
                      onClick={() => {
                        if (confirm(`确定删除活动「${p.name}」？`)) deleteMutation.mutate(p.id);
                      }}
                      className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center hover:bg-red-100 transition-colors"
                      title="删除"
                    >
                      <TrashIcon size={14} className="text-muted-foreground" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {editing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
          <div className="bg-card rounded-2xl border border-border shadow-custom w-full max-w-lg p-6 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-semibold text-foreground flex items-center gap-2">
                <MegaphoneIcon size={16} />
                {editingId ? "编辑活动" : "新建活动"}
              </h3>
              <button onClick={() => setEditing(null)}>
                <XIcon size={18} className="text-muted-foreground" />
              </button>
            </div>
            <div className="flex flex-col gap-3">
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">活动名称</span>
                <input
                  value={editing.name}
                  onChange={(e) => setEditing({ ...editing, name: e.target.value })}
                  placeholder="如：双十二满减 / 周末特价"
                  className={inputCls}
                />
              </label>

              <div className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">活动类型</span>
                <div className="flex gap-2">
                  {(
                    [
                      { v: "threshold", label: "满减" },
                      { v: "flash", label: "限时特价" },
                    ] as const
                  ).map((opt) => (
                    <button
                      key={opt.v}
                      type="button"
                      onClick={() => setEditing({ ...editing, type: opt.v })}
                      className={`px-3 py-1.5 rounded-full text-sm border transition-colors ${
                        editing.type === opt.v
                          ? "bg-primary text-primary-foreground border-primary"
                          : "bg-background text-foreground border-input hover:bg-muted"
                      }`}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>

              {editing.type === "threshold" ? (
                <div className="flex gap-3">
                  <label className="flex flex-col gap-1 text-sm flex-1">
                    <span className="text-muted-foreground">满（元）</span>
                    <input
                      type="number"
                      min={0}
                      value={editing.thresholdAmount}
                      onChange={(e) => setEditing({ ...editing, thresholdAmount: e.target.value })}
                      className={inputCls}
                    />
                  </label>
                  <label className="flex flex-col gap-1 text-sm flex-1">
                    <span className="text-muted-foreground">减（元）</span>
                    <input
                      type="number"
                      min={0}
                      value={editing.discountAmount}
                      onChange={(e) => setEditing({ ...editing, discountAmount: e.target.value })}
                      className={inputCls}
                    />
                  </label>
                </div>
              ) : (
                <div className="flex flex-col gap-2 text-sm">
                  <span className="text-muted-foreground">特价商品（特价必须低于原价）</span>
                  <div className="flex gap-2">
                    <select
                      value={pickProductId}
                      onChange={(e) => setPickProductId(e.target.value)}
                      className="flex-1 px-3 py-2 rounded-xl border border-border bg-background focus:outline-none"
                    >
                      <option value="">选择商品…</option>
                      {allProducts.map((prod) => (
                        <option key={prod.id} value={prod.id}>
                          {prod.name}（¥{prod.price}）
                        </option>
                      ))}
                    </select>
                    <button
                      type="button"
                      onClick={addPickedProduct}
                      className="px-3 py-2 rounded-xl bg-accent text-sm hover:bg-primary/20 transition-colors"
                    >
                      添加
                    </button>
                  </div>
                  {editing.items.map((item) => (
                    <div key={item.productId} className="flex items-center gap-2">
                      <span className="flex-1 truncate text-foreground">
                        {item.productName}
                        <span className="text-muted-foreground"> · 原价 ¥{item.productPrice}</span>
                      </span>
                      <input
                        type="number"
                        min={0}
                        value={item.promoPrice}
                        onChange={(e) =>
                          setEditing({
                            ...editing,
                            items: editing.items.map((it) =>
                              it.productId === item.productId ? { ...it, promoPrice: e.target.value } : it,
                            ),
                          })
                        }
                        placeholder="特价"
                        className="w-28 px-3 py-1.5 rounded-lg border border-border bg-background focus:outline-none"
                      />
                      <button
                        type="button"
                        onClick={() =>
                          setEditing({ ...editing, items: editing.items.filter((it) => it.productId !== item.productId) })
                        }
                        className="text-muted-foreground hover:text-red-500"
                      >
                        <TrashIcon size={15} />
                      </button>
                    </div>
                  ))}
                  {editing.items.length === 0 && <p className="text-xs text-muted-foreground">还没有添加商品</p>}
                </div>
              )}

              <div className="flex gap-3">
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">开始时间</span>
                  <input
                    type="datetime-local"
                    value={editing.startsAt}
                    onChange={(e) => setEditing({ ...editing, startsAt: e.target.value })}
                    className={inputCls}
                  />
                </label>
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">结束时间</span>
                  <input
                    type="datetime-local"
                    value={editing.endsAt}
                    onChange={(e) => setEditing({ ...editing, endsAt: e.target.value })}
                    className={inputCls}
                  />
                </label>
              </div>

              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={editing.isActive}
                  onChange={(e) => setEditing({ ...editing, isActive: e.target.checked })}
                />
                <span className="text-foreground">启用（停用后即使在活动时间内也不生效）</span>
              </label>

              <div className="flex gap-2 mt-2">
                <button
                  onClick={submit}
                  disabled={saveMutation.isPending}
                  className="flex-1 py-2 rounded-xl bg-primary text-primary-foreground text-sm font-medium disabled:opacity-50"
                >
                  {saveMutation.isPending ? "保存中…" : "保存"}
                </button>
                <button
                  onClick={() => setEditing(null)}
                  className="flex-1 py-2 rounded-xl bg-accent text-sm font-medium"
                >
                  取消
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
