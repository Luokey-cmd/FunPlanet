import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { PlusIcon, EditIcon, TrashIcon, XIcon, SearchIcon, ZoomInIcon } from "lucide-react";
import { toast } from "sonner";
import AdminImagePicker from "../components/AdminImagePicker";
import BannerImage from "../components/BannerImage";
import { adminApi, type AdminBanner } from "../lib/api";
import { resolveAssetUrl } from "../lib/assets";

const emptyBanner = {
  imagePath: "",
  productId: "",
  sortOrder: 0,
  title: null as string | null,
  linkType: "product",
  linkTarget: null as string | null,
  isActive: true,
};

export default function BannersPage() {
  const queryClient = useQueryClient();
  const [editing, setEditing] = useState<(Partial<AdminBanner> & { imagePath: string; productId: string }) | null>(
    null,
  );
  const [isNew, setIsNew] = useState(false);
  const [search, setSearch] = useState("");
  const [preview, setPreview] = useState<AdminBanner | null>(null);

  // 放大查看时按 Esc 关闭
  useEffect(() => {
    if (!preview) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setPreview(null);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [preview]);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-banners"],
    queryFn: () => adminApi.banners(),
  });

  const saveMutation = useMutation({
    mutationFn: async (form: Partial<AdminBanner> & { imagePath: string; productId: string }) => {
      if (isNew) {
        return adminApi.createBanner({
          imagePath: form.imagePath,
          productId: form.productId,
          sortOrder: form.sortOrder ?? 0,
          title: form.title ?? undefined,
          linkType: form.linkType ?? "product",
          linkTarget: form.linkTarget ?? undefined,
          isActive: form.isActive !== false,
        });
      }
      return adminApi.updateBanner(form.id!, form);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-banners"] });
      toast.success(isNew ? "轮播已创建" : "轮播已更新");
      setEditing(null);
      setIsNew(false);
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteBanner(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-banners"] });
      toast.success("轮播已删除");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const banners = (data?.banners ?? []).filter((b) => {
    if (!search.trim()) return true;
    const q = search.trim().toLowerCase();
    return (
      b.productName.toLowerCase().includes(q) ||
      b.productId.toLowerCase().includes(q) ||
      b.imagePath.toLowerCase().includes(q)
    );
  });

  return (
    <div data-cmp="BannersPage" className="p-6 flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-foreground">轮播图管理</h2>
          <p className="text-sm text-muted-foreground">首页轮播图，共 {banners.length} 条</p>
        </div>
        <button
          onClick={() => {
            setIsNew(true);
            setEditing({ ...emptyBanner });
          }}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:opacity-90"
        >
          <PlusIcon size={16} />
          添加轮播
        </button>
      </div>

      <div className="relative w-56">
        <SearchIcon size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input
          type="text"
          placeholder="搜索轮播图……"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="pl-9 pr-4 py-2 text-sm bg-card border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring w-full"
        />
      </div>

      {isLoading ? (
        <p className="text-muted-foreground">加载中…</p>
      ) : banners.length === 0 ? (
        <p className="text-muted-foreground text-center py-12">暂无轮播，点击上方按钮添加</p>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {banners.map((banner) => (
            <div key={banner.id} className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
              <button
                type="button"
                onClick={() => setPreview(banner)}
                className="relative block w-full cursor-zoom-in group"
                title="点击放大查看"
                aria-label={`放大查看 ${banner.productName}`}
              >
                <BannerImage imagePath={banner.imagePath} alt={banner.productName} className="h-36" />
                <span className="absolute inset-0 flex items-center justify-center gap-1.5 bg-black/45 text-white text-xs font-medium opacity-0 group-hover:opacity-100 transition-opacity">
                  <ZoomInIcon size={14} />
                  点击放大查看
                </span>
              </button>
              <div className="p-4">
                <p className="text-sm font-medium text-foreground truncate">{banner.productName}</p>
                <p className="text-xs text-muted-foreground mt-1 truncate">{banner.imagePath}</p>
                <p className="text-xs text-muted-foreground">
                  排序 {banner.sortOrder} · 商品 {banner.productId}
                  {banner.isActive === false ? " · 已停用（App 不显示）" : ""}
                  {banner.title ? ` · ${banner.title}` : ""}
                </p>
                <div className="flex gap-2 mt-3">
                  <button
                    onClick={() => {
                      setIsNew(false);
                      setEditing({ ...banner });
                    }}
                    className="flex-1 flex items-center justify-center gap-1 py-2 rounded-xl bg-accent text-xs hover:bg-primary/20 transition-colors"
                  >
                    <EditIcon size={13} />
                    编辑
                  </button>
                  <button
                    onClick={() => {
                      if (confirm("确定删除此轮播？")) deleteMutation.mutate(banner.id);
                    }}
                    className="flex-1 flex items-center justify-center gap-1 py-2 rounded-xl bg-accent text-xs hover:bg-destructive/20 transition-colors"
                  >
                    <TrashIcon size={13} />
                    删除
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {preview && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-6"
          onClick={() => setPreview(null)}
          role="dialog"
          aria-modal="true"
          aria-label="轮播图放大查看"
        >
          <button
            type="button"
            onClick={() => setPreview(null)}
            className="absolute top-4 right-4 w-9 h-9 rounded-full bg-white/15 text-white flex items-center justify-center hover:bg-white/30 transition-colors"
            aria-label="关闭放大查看"
          >
            <XIcon size={18} />
          </button>
          <div className="max-w-4xl w-full flex flex-col items-center gap-3" onClick={(e) => e.stopPropagation()}>
            <img
              src={resolveAssetUrl(preview.imagePath)}
              alt={preview.productName}
              className="max-h-[78vh] w-auto max-w-full object-contain rounded-2xl shadow-2xl"
            />
            <div className="text-center">
              <p className="text-sm font-medium text-white">{preview.productName}</p>
              <p className="text-xs text-white/70 mt-0.5">
                {preview.imagePath} · 排序 {preview.sortOrder} · 商品 {preview.productId}
              </p>
            </div>
          </div>
        </div>
      )}

      {editing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
          <div className="bg-card rounded-2xl border border-border shadow-custom w-full max-w-sm p-6">
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-semibold text-foreground">{isNew ? "添加轮播" : "编辑轮播"}</h3>
              <button
                onClick={() => {
                  setEditing(null);
                  setIsNew(false);
                }}
              >
                <XIcon size={18} className="text-muted-foreground" />
              </button>
            </div>
            <form
              className="flex flex-col gap-3"
              onSubmit={(e) => {
                e.preventDefault();
                if (!editing.imagePath?.trim()) {
                  toast.error("请选择轮播图片");
                  return;
                }
                saveMutation.mutate(editing);
              }}
            >
              <AdminImagePicker
                label="轮播图片"
                imagePath={editing.imagePath}
                onImagePathChange={(path) => setEditing({ ...editing, imagePath: path })}
                onUpload={adminApi.uploadBannerImage}
                previewAlt="轮播预览"
                previewClassName="h-28 w-full object-cover rounded-xl border border-border bg-muted/30"
              />
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">关联商品 ID</span>
                <input
                  value={editing.productId}
                  onChange={(e) => setEditing({ ...editing, productId: e.target.value })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">排序</span>
                <input
                  type="number"
                  value={editing.sortOrder ?? 0}
                  onChange={(e) => setEditing({ ...editing, sortOrder: Number(e.target.value) })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">标题（可空）</span>
                <input
                  value={editing.title ?? ""}
                  onChange={(e) => setEditing({ ...editing, title: e.target.value || null })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </label>
              <div className="flex gap-3">
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">跳转类型</span>
                  <select
                    value={editing.linkType ?? "product"}
                    onChange={(e) => setEditing({ ...editing, linkType: e.target.value })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  >
                    <option value="product">跳商品</option>
                    <option value="category">跳分类</option>
                    <option value="url">跳外链</option>
                  </select>
                </label>
                <label className="flex flex-col gap-1 text-sm flex-1">
                  <span className="text-muted-foreground">是否启用</span>
                  <select
                    value={editing.isActive === false ? "off" : "on"}
                    onChange={(e) => setEditing({ ...editing, isActive: e.target.value === "on" })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  >
                    <option value="on">启用（App 显示）</option>
                    <option value="off">停用</option>
                  </select>
                </label>
              </div>
              {(editing.linkType ?? "product") !== "product" && (
                <label className="flex flex-col gap-1 text-sm">
                  <span className="text-muted-foreground">跳转目标（分类名或链接）</span>
                  <input
                    value={editing.linkTarget ?? ""}
                    onChange={(e) => setEditing({ ...editing, linkTarget: e.target.value || null })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  />
                </label>
              )}
              <button
                type="submit"
                disabled={saveMutation.isPending}
                className="mt-2 py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-medium disabled:opacity-60"
              >
                {saveMutation.isPending ? "保存中…" : "保存"}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
