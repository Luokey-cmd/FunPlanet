import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { SearchIcon, PlusIcon, EditIcon, TrashIcon, HeartIcon, XIcon } from "lucide-react";
import { toast } from "sonner";
import AdminImagePicker from "../components/AdminImagePicker";
import ProductImageThumb from "../components/ProductImageThumb";
import { adminApi, type AdminProduct } from "../lib/api";

// 分类改从「分类管理」接口读；接口不可用时用这组默认值兜底
const FALLBACK_CATEGORY_NAMES = ["玩具", "公仔", "手办", "谷子", "小卡", "文具", "实用类周边"];

const emptyForm: Partial<AdminProduct> & { id: string; name: string } = {
  id: "",
  name: "",
  nameEn: "",
  price: 0,
  originalPrice: null,
  majorCategory: "玩具",
  subCategory: "",
  category: "toy",
  tag: null,
  tagColor: null,
  spec: null,
  stock: 100,
  isOnShelf: true,
  description: "",
  purchaseNotes: "",
  rating: 5,
  imagePath: "",
  imagePaths: [],
  videoPath: null,
  brand: null,
  series: null,
  rarity: null,
  suitableFor: null,
  sellingPoints: [],
};

export default function ProductsPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("全部");
  const [editing, setEditing] = useState<(Partial<AdminProduct> & { id: string; name: string }) | null>(null);
  const [isNew, setIsNew] = useState(false);

  const { data: categoriesData } = useQuery({
    queryKey: ["admin-categories"],
    queryFn: () => adminApi.categories(),
  });
  const categoryNames = categoriesData?.categories.map((c) => c.name) ?? FALLBACK_CATEGORY_NAMES;
  const filterCategories = ["全部", ...categoryNames];

  const { data, isLoading } = useQuery({
    queryKey: ["admin-products", search, category],
    queryFn: () =>
      adminApi.products({
        keyword: search || undefined,
        category: category === "全部" ? undefined : category,
      }),
  });

  const saveMutation = useMutation({
    mutationFn: async (form: Partial<AdminProduct> & { id: string; name: string }) => {
      if (isNew) return adminApi.createProduct(form);
      return adminApi.updateProduct(form.id, form);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-products"] });
      toast.success(isNew ? "商品已创建" : "商品已更新");
      setEditing(null);
      setIsNew(false);
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const shelfMutation = useMutation({
    mutationFn: ({ id, isOnShelf }: { id: string; isOnShelf: boolean }) =>
      adminApi.toggleProductShelf(id, isOnShelf),
    onSuccess: (_data, vars) => {
      queryClient.invalidateQueries({ queryKey: ["admin-products"] });
      toast.success(vars.isOnShelf ? "商品已上架" : "商品已下架，App 商城里将不再显示");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteProduct(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-products"] });
      toast.success("商品已删除");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  // 商品列表按编号数字从大到小排：越晚添加（P 数字越大）越靠前。
  // 只在后台这一层排序，不影响 App 商城里的商品顺序。
  const products = [...(data?.products ?? [])].sort((a, b) => {
    const numOf = (id: string) => {
      const m = id.match(/\d+/);
      return m ? parseInt(m[0], 10) : Number.NaN;
    };
    const na = numOf(a.id);
    const nb = numOf(b.id);
    if (!Number.isNaN(na) && !Number.isNaN(nb) && na !== nb) return nb - na;
    if (!Number.isNaN(na) && Number.isNaN(nb)) return -1;
    if (Number.isNaN(na) && !Number.isNaN(nb)) return 1;
    return b.id.localeCompare(a.id);
  });

  const openEdit = (p: AdminProduct) => {
    setIsNew(false);
    setEditing({ ...p });
  };

  const openCreate = () => {
    setIsNew(true);
    setEditing({ ...emptyForm });
  };

  return (
    <div data-cmp="ProductsPage" className="p-6 flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-foreground">商品列表</h2>
          <p className="text-sm text-muted-foreground">共 {products.length} 件商品</p>
        </div>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:opacity-90 transition-opacity"
        >
          <PlusIcon size={16} />
          添加商品
        </button>
      </div>

      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative">
          <SearchIcon size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="搜索商品……"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 pr-4 py-2 text-sm bg-card border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring w-56"
          />
        </div>
        <div className="flex gap-2 flex-wrap">
          {filterCategories.map((cat) => (
            <button
              key={cat}
              onClick={() => setCategory(cat)}
              className={`text-xs px-3 py-2 rounded-xl transition-colors font-medium ${
                category === cat
                  ? "bg-primary text-primary-foreground"
                  : "bg-card border border-border text-muted-foreground hover:bg-accent"
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
        {isLoading ? (
          <p className="p-8 text-center text-muted-foreground">加载中…</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border bg-muted/50">
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">商品</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">分类</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">价格</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">销量</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">库存</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">状态</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">收藏数</th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground">操作</th>
                </tr>
              </thead>
              <tbody>
                {products.map((product, idx) => (
                  <tr
                    key={product.id}
                    className={`border-b border-border last:border-0 hover:bg-muted/30 transition-colors ${
                      idx % 2 === 0 ? "" : "bg-muted/10"
                    }`}
                  >
                    <td className="px-5 py-4">
                      <div className={`flex items-center gap-3 ${product.isOnShelf ? "" : "opacity-50"}`}>
                        <ProductImageThumb imagePath={product.imagePath} alt={product.name} size={40} />
                        <div>
                          <p className="text-sm font-medium text-foreground">{product.name}</p>
                          <p className="text-xs text-muted-foreground">{product.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      <span className="text-xs px-2.5 py-1 rounded-lg bg-secondary text-secondary-foreground font-medium">
                        {product.majorCategory}
                      </span>
                    </td>
                    <td className="px-5 py-4 text-sm font-semibold text-foreground">¥{product.price}</td>
                    <td className="px-5 py-4 text-sm text-foreground">{product.sales}</td>
                    <td className="px-5 py-4">
                      <span className={`text-sm ${product.stock <= 0 ? "text-destructive font-semibold" : "text-foreground"}`}>
                        {product.stock}
                      </span>
                      {product.stock <= 0 && <span className="ml-1.5 text-xs text-destructive">缺货</span>}
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => shelfMutation.mutate({ id: product.id, isOnShelf: !product.isOnShelf })}
                          disabled={shelfMutation.isPending}
                          title={product.isOnShelf ? "点击下架" : "点击上架"}
                          className={`relative w-11 h-6 rounded-full transition-colors flex-shrink-0 ${
                            product.isOnShelf ? "bg-primary" : "bg-muted-foreground/30"
                          }`}
                        >
                          <span
                            className={`absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-all ${
                              product.isOnShelf ? "left-[22px]" : "left-0.5"
                            }`}
                          />
                        </button>
                        <span className="text-xs text-muted-foreground whitespace-nowrap">{product.isOnShelf ? "上架" : "下架"}</span>
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-1">
                        <HeartIcon size={13} fill="#f48fb1" stroke="#f48fb1" />
                        <span className="text-sm text-foreground">{product.favoriteCount ?? 0}</span>
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => openEdit(product)}
                          className="w-7 h-7 rounded-lg bg-accent flex items-center justify-center hover:bg-primary/20 transition-colors"
                        >
                          <EditIcon size={13} className="text-muted-foreground" />
                        </button>
                        <button
                          onClick={() => {
                            if (confirm(`确定删除「${product.name}」？`)) deleteMutation.mutate(product.id);
                          }}
                          className="w-7 h-7 rounded-lg bg-accent flex items-center justify-center hover:bg-destructive/20 transition-colors"
                        >
                          <TrashIcon size={13} className="text-muted-foreground" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {editing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
          <div className="bg-card rounded-2xl border border-border shadow-custom w-full max-w-lg max-h-[90vh] overflow-y-auto p-6">
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-semibold text-foreground">{isNew ? "添加商品" : "编辑商品"}</h3>
              <button onClick={() => { setEditing(null); setIsNew(false); }}>
                <XIcon size={18} className="text-muted-foreground" />
              </button>
            </div>
            <form
              className="flex flex-col gap-3"
              onSubmit={(e) => {
                e.preventDefault();
                if (!editing.imagePath?.trim()) {
                  toast.error("请选择商品图片");
                  return;
                }
                saveMutation.mutate(editing);
              }}
            >
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">商品 ID</span>
                <input
                  disabled={!isNew}
                  value={editing.id}
                  onChange={(e) => setEditing({ ...editing, id: e.target.value })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring disabled:opacity-50"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">名称</span>
                <input
                  value={editing.name}
                  onChange={(e) => setEditing({ ...editing, name: e.target.value })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">大类</span>
                <select
                  value={editing.majorCategory ?? ""}
                  onChange={(e) => setEditing({ ...editing, majorCategory: e.target.value })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                >
                  {categoryNames.map((name) => (
                    <option key={name} value={name}>
                      {name}
                    </option>
                  ))}
                  {editing.majorCategory && !categoryNames.includes(editing.majorCategory) && (
                    <option value={editing.majorCategory}>{editing.majorCategory}</option>
                  )}
                </select>
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">子类</span>
                <input
                  value={editing.subCategory ?? ""}
                  onChange={(e) => setEditing({ ...editing, subCategory: e.target.value })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">价格</span>
                <input
                  type="number"
                  value={editing.price ?? 0}
                  onChange={(e) => setEditing({ ...editing, price: Number(e.target.value) })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <div className="flex gap-3">
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">库存</span>
                  <input
                    type="number"
                    min={0}
                    value={editing.stock ?? 0}
                    onChange={(e) => setEditing({ ...editing, stock: Number(e.target.value) })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </label>
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">上架状态</span>
                  <select
                    value={editing.isOnShelf === false ? "off" : "on"}
                    onChange={(e) => setEditing({ ...editing, isOnShelf: e.target.value === "on" })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  >
                    <option value="on">上架（App 可见）</option>
                    <option value="off">下架（App 隐藏）</option>
                  </select>
                </label>
              </div>
              <AdminImagePicker
                label="商品图片（主图）"
                imagePath={editing.imagePath ?? ""}
                onImagePathChange={(path) => setEditing({ ...editing, imagePath: path })}
                onUpload={adminApi.uploadProductImage}
                previewAlt={editing.name || "商品预览"}
                previewClassName="h-36 w-full object-contain rounded-xl border border-border bg-muted/30"
              />
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">多图路径（一行一张，第一张应与主图一致；详情页轮播用）</span>
                <textarea
                  rows={3}
                  value={(editing.imagePaths ?? []).join("\n")}
                  onChange={(e) =>
                    setEditing({
                      ...editing,
                      imagePaths: e.target.value.split("\n").map((x) => x.trim()).filter(Boolean),
                    })
                  }
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <div className="flex gap-3">
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">品牌</span>
                  <input
                    value={editing.brand ?? ""}
                    onChange={(e) => setEditing({ ...editing, brand: e.target.value || null })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </label>
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">IP / 系列</span>
                  <input
                    value={editing.series ?? ""}
                    onChange={(e) => setEditing({ ...editing, series: e.target.value || null })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </label>
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">稀有度</span>
                  <input
                    placeholder="如 普通 / 稀有 / 限量"
                    value={editing.rarity ?? ""}
                    onChange={(e) => setEditing({ ...editing, rarity: e.target.value || null })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </label>
              </div>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">适合谁 / 什么场景（小豆导购优先读这里写推荐理由）</span>
                <textarea
                  rows={2}
                  value={editing.suitableFor ?? ""}
                  onChange={(e) => setEditing({ ...editing, suitableFor: e.target.value || null })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">结构化卖点（一行一条，如「亚克力高透」）</span>
                <textarea
                  rows={3}
                  value={(editing.sellingPoints ?? []).join("\n")}
                  onChange={(e) =>
                    setEditing({
                      ...editing,
                      sellingPoints: e.target.value.split("\n").map((x) => x.trim()).filter(Boolean),
                    })
                  }
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">商品视频路径（可空）</span>
                <input
                  value={editing.videoPath ?? ""}
                  onChange={(e) => setEditing({ ...editing, videoPath: e.target.value || null })}
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
                  onClick={() => { setEditing(null); setIsNew(false); }}
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
