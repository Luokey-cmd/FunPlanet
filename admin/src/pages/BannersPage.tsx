import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { PlusIcon, EditIcon, TrashIcon, XIcon, SearchIcon } from "lucide-react";
import { toast } from "sonner";
import AdminImagePicker from "../components/AdminImagePicker";
import BannerImage from "../components/BannerImage";
import { adminApi, type AdminBanner } from "../lib/api";

const emptyBanner = { imagePath: "", productId: "", sortOrder: 0 };

export default function BannersPage() {
  const queryClient = useQueryClient();
  const [editing, setEditing] = useState<(Partial<AdminBanner> & { imagePath: string; productId: string }) | null>(
    null,
  );
  const [isNew, setIsNew] = useState(false);
  const [search, setSearch] = useState("");

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
              <BannerImage imagePath={banner.imagePath} alt={banner.productName} className="h-36" />
              <div className="p-4">
                <p className="text-sm font-medium text-foreground truncate">{banner.productName}</p>
                <p className="text-xs text-muted-foreground mt-1 truncate">{banner.imagePath}</p>
                <p className="text-xs text-muted-foreground">排序 {banner.sortOrder} · 商品 {banner.productId}</p>
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
