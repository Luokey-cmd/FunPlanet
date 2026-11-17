import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { EditIcon, PlusIcon, Trash2Icon, XIcon } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { adminApi, ApiError, type AdminCategory, type CategoryInput } from "../lib/api";

const emptyForm: CategoryInput = { name: "", sortOrder: undefined };

export default function CategoriesPage() {
  const queryClient = useQueryClient();
  const [editing, setEditing] = useState<AdminCategory | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [form, setForm] = useState<CategoryInput>(emptyForm);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-categories"],
    queryFn: () => adminApi.categories(),
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["admin-categories"] });
    queryClient.invalidateQueries({ queryKey: ["admin-products"] });
  };

  const saveMutation = useMutation({
    mutationFn: (payload: { id?: string; body: CategoryInput }) =>
      payload.id ? adminApi.updateCategory(payload.id, payload.body) : adminApi.createCategory(payload.body),
    onSuccess: () => {
      invalidate();
      toast.success(isNew ? "分类已添加" : "分类已保存");
      closeModal();
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "保存失败"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteCategory(id),
    onSuccess: () => {
      invalidate();
      toast.success("分类已删除");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "删除失败"),
  });

  const categories = data?.categories ?? [];

  const openCreate = () => {
    setIsNew(true);
    setEditing(null);
    setForm({ name: "", sortOrder: categories.length + 1 });
  };

  const openEdit = (c: AdminCategory) => {
    setIsNew(false);
    setEditing(c);
    setForm({ name: c.name, sortOrder: c.sortOrder });
  };

  const closeModal = () => {
    setEditing(null);
    setIsNew(false);
    setForm(emptyForm);
  };

  const submit = () => {
    if (!form.name.trim()) {
      toast.error("分类名称不能为空");
      return;
    }
    saveMutation.mutate({ id: isNew ? undefined : editing?.id, body: form });
  };

  return (
    <div data-cmp="CategoriesPage" className="p-6 flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-foreground">分类管理</h2>
          <p className="text-sm text-muted-foreground">
            共 {categories.length} 个大分类。改名会自动同步到该分类下的商品；分类下还有商品时不能删除。
          </p>
        </div>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:opacity-90 transition-opacity"
        >
          <PlusIcon size={16} />
          添加分类
        </button>
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
        {isLoading ? (
          <p className="p-8 text-center text-muted-foreground">加载中…</p>
        ) : categories.length === 0 ? (
          <p className="p-8 text-center text-muted-foreground">暂无分类，点右上角添加第一个分类。</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground">
                <th className="px-5 py-3 font-medium">排序</th>
                <th className="px-5 py-3 font-medium">分类名称</th>
                <th className="px-5 py-3 font-medium">商品数量</th>
                <th className="px-5 py-3 font-medium text-right">操作</th>
              </tr>
            </thead>
            <tbody>
              {categories.map((c) => (
                <tr key={c.id} className="border-b border-border/60 last:border-0 hover:bg-accent/40 transition-colors">
                  <td className="px-5 py-3 text-muted-foreground">{c.sortOrder}</td>
                  <td className="px-5 py-3 font-medium text-foreground">{c.name}</td>
                  <td className="px-5 py-3 text-muted-foreground">{c.productCount} 件</td>
                  <td className="px-5 py-3">
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => openEdit(c)}
                        className="flex items-center gap-1 px-3 py-1.5 rounded-lg border border-border text-xs font-medium hover:bg-accent transition-colors"
                      >
                        <EditIcon size={13} />
                        编辑
                      </button>
                      <button
                        onClick={() => {
                          if (confirm(`确定删除分类「${c.name}」？`)) deleteMutation.mutate(c.id);
                        }}
                        className="flex items-center gap-1 px-3 py-1.5 rounded-lg border border-border text-xs font-medium text-destructive hover:bg-destructive/10 transition-colors"
                      >
                        <Trash2Icon size={13} />
                        删除
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {(isNew || editing) && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={closeModal}>
          <div
            className="bg-card rounded-2xl border border-border shadow-custom w-full max-w-md p-6 flex flex-col gap-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-foreground">{isNew ? "添加分类" : "编辑分类"}</h3>
              <button onClick={closeModal} className="text-muted-foreground hover:text-foreground transition-colors">
                <XIcon size={18} />
              </button>
            </div>
            <label className="flex flex-col gap-1.5">
              <span className="text-sm text-muted-foreground">分类名称</span>
              <input
                type="text"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="例如：盲盒"
                className="px-3 py-2 text-sm bg-background border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring"
              />
            </label>
            <label className="flex flex-col gap-1.5">
              <span className="text-sm text-muted-foreground">排序（数字越小越靠前）</span>
              <input
                type="number"
                value={form.sortOrder ?? ""}
                onChange={(e) =>
                  setForm({ ...form, sortOrder: e.target.value === "" ? undefined : Number(e.target.value) })
                }
                className="px-3 py-2 text-sm bg-background border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring"
              />
            </label>
            {!isNew && editing && editing.productCount > 0 && (
              <p className="text-xs text-muted-foreground">
                该分类下有 {editing.productCount} 件商品，改名会把这些商品的大分类一起改过来。
              </p>
            )}
            <div className="flex justify-end gap-2 pt-1">
              <button
                onClick={closeModal}
                className="px-4 py-2 rounded-xl border border-border text-sm font-medium hover:bg-accent transition-colors"
              >
                取消
              </button>
              <button
                onClick={submit}
                disabled={saveMutation.isPending}
                className="px-4 py-2 rounded-xl bg-primary text-primary-foreground text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-60"
              >
                {saveMutation.isPending ? "保存中…" : "保存"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
