import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { EditIcon, PlusIcon, SearchIcon, Trash2Icon, XIcon } from "lucide-react";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { adminApi, ApiError, type ChangelogEntry, type ChangelogInput, type ChangelogTag } from "../lib/api";

const TAG_LABEL: Record<ChangelogTag, string> = {
  feature: "新功能",
  fix: "修复",
  improve: "优化",
};

const TAG_STYLE: Record<ChangelogTag, string> = {
  feature: "bg-primary/15 text-primary",
  fix: "bg-destructive/15 text-destructive",
  improve: "bg-secondary text-secondary-foreground",
};

const emptyForm = (): ChangelogInput => ({
  version: "",
  title: "",
  date: new Date().toISOString().slice(0, 10),
  tag: "feature",
  items: "",
});

function itemsToText(items: string[] | string) {
  return Array.isArray(items) ? items.join("\n") : items;
}

export default function ChangelogPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [tagFilter, setTagFilter] = useState<ChangelogTag | "all">("all");
  const [editing, setEditing] = useState<ChangelogEntry | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [form, setForm] = useState<ChangelogInput>(emptyForm());

  const { data, isLoading } = useQuery({
    queryKey: ["admin-changelog"],
    queryFn: () => adminApi.changelog(),
  });

  const saveMutation = useMutation({
    mutationFn: (payload: { id?: string; body: ChangelogInput }) =>
      payload.id
        ? adminApi.updateChangelog(payload.id, payload.body)
        : adminApi.createChangelog(payload.body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-changelog"] });
      toast.success(isNew ? "更新日志已发布" : "更新日志已保存");
      closeModal();
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "保存失败"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteChangelog(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-changelog"] });
      toast.success("已删除");
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "删除失败"),
  });

  const entries = useMemo(() => {
    const list = data?.entries ?? [];
    const q = search.trim().toLowerCase();
    return list.filter((e) => {
      if (tagFilter !== "all" && e.tag !== tagFilter) return false;
      if (!q) return true;
      return (
        e.version.toLowerCase().includes(q) ||
        e.title.toLowerCase().includes(q) ||
        e.items.some((item) => item.toLowerCase().includes(q))
      );
    });
  }, [data?.entries, search, tagFilter]);

  const openCreate = () => {
    setIsNew(true);
    setEditing(null);
    setForm(emptyForm());
  };

  const openEdit = (entry: ChangelogEntry) => {
    setIsNew(false);
    setEditing(entry);
    setForm({
      version: entry.version,
      title: entry.title,
      date: entry.date,
      tag: entry.tag,
      items: entry.items.join("\n"),
    });
  };

  const closeModal = () => {
    setEditing(null);
    setIsNew(false);
    setForm(emptyForm());
  };

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    saveMutation.mutate({
      id: editing?.id,
      body: form,
    });
  };

  const showModal = isNew || editing;

  return (
    <div data-cmp="ChangelogPage" className="p-6 flex flex-col gap-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-lg font-semibold text-foreground">更新日志</h2>
          <p className="text-sm text-muted-foreground">记录版本发布与功能变更，App 端可通过 /api/changelog 拉取</p>
        </div>
        <button
          type="button"
          onClick={openCreate}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:opacity-90"
        >
          <PlusIcon size={16} />
          发布更新
        </button>
      </div>

      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative w-56">
          <SearchIcon size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="搜索版本、标题、内容……"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 pr-4 py-2 text-sm bg-card border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring w-full"
          />
        </div>
        <div className="flex gap-2 flex-wrap">
          {(
            [
              { value: "all" as const, label: "全部" },
              { value: "feature" as const, label: "新功能" },
              { value: "improve" as const, label: "优化" },
              { value: "fix" as const, label: "修复" },
            ] as const
          ).map((f) => (
            <button
              key={f.value}
              type="button"
              onClick={() => setTagFilter(f.value)}
              className={`text-xs px-3 py-2 rounded-xl transition-colors font-medium ${
                tagFilter === f.value
                  ? "bg-primary text-primary-foreground"
                  : "bg-card border border-border text-muted-foreground hover:bg-accent"
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <p className="text-muted-foreground text-sm">加载中…</p>
      ) : entries.length === 0 ? (
        <div className="bg-card rounded-2xl border border-border shadow-custom p-12 text-center">
          <p className="text-muted-foreground">暂无更新日志</p>
          <button
            type="button"
            onClick={openCreate}
            className="mt-4 text-sm text-primary font-medium hover:underline"
          >
            发布第一条更新
          </button>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {entries.map((entry, idx) => (
            <div
              key={entry.id}
              className="bg-card rounded-2xl border border-border shadow-custom p-5 relative"
            >
              <div className="absolute left-0 top-5 bottom-5 w-1 rounded-r-full bg-primary/30" aria-hidden />
              <div className="flex items-start justify-between gap-4 pl-3">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap mb-1">
                    <span className="text-xs font-mono px-2 py-0.5 rounded-lg bg-muted text-muted-foreground">
                      v{entry.version}
                    </span>
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${TAG_STYLE[entry.tag]}`}>
                      {TAG_LABEL[entry.tag]}
                    </span>
                    <span className="text-xs text-muted-foreground">{entry.date}</span>
                  </div>
                  <h3 className="font-semibold text-foreground">{entry.title}</h3>
                  <ul className="mt-3 flex flex-col gap-1.5">
                    {entry.items.map((item, i) => (
                      <li key={i} className="text-sm text-muted-foreground flex gap-2">
                        <span className="text-primary mt-1.5 w-1.5 h-1.5 rounded-full bg-primary flex-shrink-0" />
                        <span>{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
                <div className="flex gap-2 flex-shrink-0">
                  <button
                    type="button"
                    onClick={() => openEdit(entry)}
                    className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center hover:bg-primary/20 transition-colors"
                    title="编辑"
                  >
                    <EditIcon size={14} className="text-muted-foreground" />
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      if (window.confirm(`确定删除 v${entry.version}「${entry.title}」？`)) {
                        deleteMutation.mutate(entry.id);
                      }
                    }}
                    className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center hover:bg-destructive/20 transition-colors"
                    title="删除"
                  >
                    <Trash2Icon size={14} className="text-destructive" />
                  </button>
                </div>
              </div>
              {idx < entries.length - 1 && (
                <div className="mt-4 ml-3 border-b border-border/60" />
              )}
            </div>
          ))}
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
          <div className="bg-card rounded-2xl border border-border shadow-custom w-full max-w-lg p-6 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-semibold text-foreground">{isNew ? "发布更新" : "编辑更新日志"}</h3>
              <button type="button" onClick={closeModal}>
                <XIcon size={18} className="text-muted-foreground" />
              </button>
            </div>
            <form className="flex flex-col gap-3" onSubmit={onSubmit}>
              <div className="grid grid-cols-2 gap-3">
                <label className="flex flex-col gap-1 text-sm">
                  <span className="text-muted-foreground">版本号</span>
                  <input
                    value={form.version}
                    onChange={(e) => setForm({ ...form, version: e.target.value })}
                    placeholder="如 1.2.0"
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                    required
                  />
                </label>
                <label className="flex flex-col gap-1 text-sm">
                  <span className="text-muted-foreground">发布日期</span>
                  <input
                    type="date"
                    value={form.date ?? ""}
                    onChange={(e) => setForm({ ...form, date: e.target.value })}
                    className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                    required
                  />
                </label>
              </div>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">标题</span>
                <input
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  placeholder="本次更新摘要"
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                  required
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">类型</span>
                <select
                  value={form.tag ?? "feature"}
                  onChange={(e) => setForm({ ...form, tag: e.target.value as ChangelogTag })}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring"
                >
                  <option value="feature">新功能</option>
                  <option value="improve">优化</option>
                  <option value="fix">修复</option>
                </select>
              </label>
              <label className="flex flex-col gap-1 text-sm">
                <span className="text-muted-foreground">更新内容（每行一条）</span>
                <textarea
                  value={itemsToText(form.items)}
                  onChange={(e) => setForm({ ...form, items: e.target.value })}
                  rows={6}
                  placeholder={"新增更新日志模块\n支持管理员注册\n……"}
                  className="px-3 py-2 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring resize-y"
                  required
                />
              </label>
              <button
                type="submit"
                disabled={saveMutation.isPending}
                className="mt-2 py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-medium disabled:opacity-60"
              >
                {saveMutation.isPending ? "保存中…" : isNew ? "发布" : "保存"}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
