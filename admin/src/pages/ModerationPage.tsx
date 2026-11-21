import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { SearchIcon } from "lucide-react";
import { toast } from "sonner";
import { adminApi } from "../lib/api";

// 内容审核页：管 App 里三处用户能发内容的地方——AI 社区（动态+评论）、
// AI 绘画、商品评价。带审核状态的内容可以「隐藏/恢复」（隐藏后 App 端
// 不再展示，数据还在）；评论没有状态字段，只能删除。删除是硬删除，
// 不可恢复，点之前会二次确认。

type TabKey = "posts" | "comments" | "artworks" | "reviews";

const tabs: { key: TabKey; label: string }[] = [
  { key: "posts", label: "社区动态" },
  { key: "comments", label: "社区评论" },
  { key: "artworks", label: "AI 绘画" },
  { key: "reviews", label: "商品评价" },
];

const statusFilters = [
  { label: "全部", value: "" },
  { label: "可见", value: "visible" },
  { label: "已隐藏", value: "hidden" },
];

function StatusBadge({ status }: { status: string }) {
  return status === "hidden" ? (
    <span className="text-xs px-2.5 py-1 rounded-lg bg-red-100 text-red-600 font-medium">已隐藏</span>
  ) : (
    <span className="text-xs px-2.5 py-1 rounded-lg bg-secondary text-secondary-foreground font-medium">可见</span>
  );
}

function AuthorCell({ name, isAi }: { name: string; isAi?: boolean }) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <span className="text-sm font-medium text-foreground">{name}</span>
      {isAi && (
        <span className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary font-medium">AI</span>
      )}
    </span>
  );
}

function Thumbs({ images }: { images: string[] }) {
  if (!images.length) return <span className="text-xs text-muted-foreground">无图</span>;
  return (
    <div className="flex gap-1.5">
      {images.slice(0, 3).map((src, i) => (
        <img
          key={i}
          src={src}
          alt=""
          className="w-10 h-10 rounded-lg object-cover border border-border"
          loading="lazy"
        />
      ))}
      {images.length > 3 && (
        <span className="text-xs text-muted-foreground self-center">+{images.length - 3}</span>
      )}
    </div>
  );
}

export default function ModerationPage() {
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<TabKey>("posts");
  const [statusFilter, setStatusFilter] = useState("");
  const [keyword, setKeyword] = useState("");

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["admin-moderation"] });

  const statusMutation = useMutation({
    mutationFn: ({ kind, id, status }: { kind: "posts" | "artworks" | "reviews"; id: string; status: "visible" | "hidden" }) =>
      adminApi.setModerationStatus(kind, id, status),
    onSuccess: (_d, vars) => {
      invalidate();
      toast.success(vars.status === "hidden" ? "已隐藏，App 里将不再显示" : "已恢复可见");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const deleteMutation = useMutation({
    mutationFn: ({ kind, id }: { kind: TabKey; id: string }) => adminApi.deleteModeration(kind, id),
    onSuccess: () => {
      invalidate();
      toast.success("已删除");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const handleDelete = (kind: TabKey, id: string) => {
    if (!window.confirm("确定要删除吗？删除后不可恢复。")) return;
    deleteMutation.mutate({ kind, id });
  };

  const postsQuery = useQuery({
    queryKey: ["admin-moderation", "posts", statusFilter, keyword],
    queryFn: () => adminApi.moderationPosts({ status: statusFilter || undefined, keyword: keyword || undefined }),
    enabled: tab === "posts",
  });
  const commentsQuery = useQuery({
    queryKey: ["admin-moderation", "comments", keyword],
    queryFn: () => adminApi.moderationComments(keyword || undefined),
    enabled: tab === "comments",
  });
  const artworksQuery = useQuery({
    queryKey: ["admin-moderation", "artworks", statusFilter, keyword],
    queryFn: () => adminApi.moderationArtworks({ status: statusFilter || undefined, keyword: keyword || undefined }),
    enabled: tab === "artworks",
  });
  const reviewsQuery = useQuery({
    queryKey: ["admin-moderation", "reviews", statusFilter, keyword],
    queryFn: () => adminApi.moderationReviews({ status: statusFilter || undefined, keyword: keyword || undefined }),
    enabled: tab === "reviews",
  });

  const actionCell = (kind: "posts" | "artworks" | "reviews", id: string, status: string) => (
    <div className="flex gap-2">
      <button
        onClick={() =>
          statusMutation.mutate({ kind, id, status: status === "hidden" ? "visible" : "hidden" })
        }
        disabled={statusMutation.isPending}
        className="text-xs px-3 py-1.5 rounded-lg border border-border text-foreground font-medium hover:bg-accent disabled:opacity-60"
      >
        {status === "hidden" ? "恢复" : "隐藏"}
      </button>
      <button
        onClick={() => handleDelete(kind, id)}
        disabled={deleteMutation.isPending}
        className="text-xs px-3 py-1.5 rounded-lg bg-red-50 text-red-600 font-medium hover:bg-red-100 disabled:opacity-60"
      >
        删除
      </button>
    </div>
  );

  const th = "text-left px-5 py-3.5 text-xs font-semibold text-muted-foreground";
  const td = "px-5 py-4";

  return (
    <div data-cmp="ModerationPage" className="p-6 flex flex-col gap-5">
      <div>
        <h2 className="text-lg font-semibold text-foreground">内容审核</h2>
        <p className="text-sm text-muted-foreground">
          社区动态、评论、AI 绘画与商品评价都在这里管：隐藏后 App 里不再显示，删除不可恢复
        </p>
      </div>

      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex gap-2 flex-wrap">
          {tabs.map((t) => (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              className={`text-xs px-3.5 py-2 rounded-xl transition-colors font-medium ${
                tab === t.key
                  ? "bg-primary text-primary-foreground"
                  : "bg-card border border-border text-muted-foreground hover:bg-accent"
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
        <div className="relative">
          <SearchIcon size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="搜索内容…"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            className="pl-9 pr-4 py-2 text-sm bg-card border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-ring w-52"
          />
        </div>
        {tab !== "comments" && (
          <div className="flex gap-2">
            {statusFilters.map((s) => (
              <button
                key={s.value}
                onClick={() => setStatusFilter(s.value)}
                className={`text-xs px-3 py-2 rounded-xl transition-colors font-medium ${
                  statusFilter === s.value
                    ? "bg-primary text-primary-foreground"
                    : "bg-card border border-border text-muted-foreground hover:bg-accent"
                }`}
              >
                {s.label}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom overflow-hidden">
        {tab === "posts" && (
          postsQuery.isLoading ? (
            <p className="p-8 text-center text-muted-foreground">加载中…</p>
          ) : (postsQuery.data?.posts ?? []).length === 0 ? (
            <p className="p-8 text-center text-muted-foreground">暂无动态</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border bg-muted/50">
                    <th className={th}>作者</th>
                    <th className={th}>内容</th>
                    <th className={th}>图片</th>
                    <th className={th}>互动</th>
                    <th className={th}>状态</th>
                    <th className={th}>时间</th>
                    <th className={th}>操作</th>
                  </tr>
                </thead>
                <tbody>
                  {(postsQuery.data?.posts ?? []).map((p) => (
                    <tr key={p.id} className={`border-b border-border last:border-0 hover:bg-muted/30 ${p.status === "hidden" ? "opacity-60" : ""}`}>
                      <td className={td}><AuthorCell name={p.author} isAi={p.isAi} /></td>
                      <td className={td}>
                        <p className="text-sm text-foreground max-w-[300px] line-clamp-2" title={p.content}>{p.content}</p>
                      </td>
                      <td className={td}><Thumbs images={p.images} /></td>
                      <td className={td}>
                        <span className="text-xs text-muted-foreground">评论 {p.commentCount} · 赞 {p.likeCount}</span>
                      </td>
                      <td className={td}><StatusBadge status={p.status} /></td>
                      <td className={`${td} text-sm text-muted-foreground whitespace-nowrap`}>{p.date}</td>
                      <td className={td}>{actionCell("posts", p.id, p.status)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        )}

        {tab === "comments" && (
          commentsQuery.isLoading ? (
            <p className="p-8 text-center text-muted-foreground">加载中…</p>
          ) : (commentsQuery.data?.comments ?? []).length === 0 ? (
            <p className="p-8 text-center text-muted-foreground">暂无评论</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border bg-muted/50">
                    <th className={th}>作者</th>
                    <th className={th}>评论</th>
                    <th className={th}>所属动态</th>
                    <th className={th}>时间</th>
                    <th className={th}>操作</th>
                  </tr>
                </thead>
                <tbody>
                  {(commentsQuery.data?.comments ?? []).map((c) => (
                    <tr key={c.id} className="border-b border-border last:border-0 hover:bg-muted/30">
                      <td className={td}><AuthorCell name={c.author} isAi={c.isAi} /></td>
                      <td className={td}>
                        <p className="text-sm text-foreground max-w-[300px] line-clamp-2" title={c.content}>
                          {c.replyToUserName ? <span className="text-muted-foreground">回复 {c.replyToUserName}：</span> : null}
                          {c.content}
                        </p>
                      </td>
                      <td className={td}>
                        <p className="text-xs text-muted-foreground max-w-[220px] truncate" title={c.postContent}>{c.postContent}</p>
                      </td>
                      <td className={`${td} text-sm text-muted-foreground whitespace-nowrap`}>{c.date}</td>
                      <td className={td}>
                        <button
                          onClick={() => handleDelete("comments", c.id)}
                          disabled={deleteMutation.isPending}
                          className="text-xs px-3 py-1.5 rounded-lg bg-red-50 text-red-600 font-medium hover:bg-red-100 disabled:opacity-60"
                        >
                          删除
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        )}

        {tab === "artworks" && (
          artworksQuery.isLoading ? (
            <p className="p-8 text-center text-muted-foreground">加载中…</p>
          ) : (artworksQuery.data?.artworks ?? []).length === 0 ? (
            <p className="p-8 text-center text-muted-foreground">暂无作品</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border bg-muted/50">
                    <th className={th}>作品</th>
                    <th className={th}>作者</th>
                    <th className={th}>提示词</th>
                    <th className={th}>状态</th>
                    <th className={th}>时间</th>
                    <th className={th}>操作</th>
                  </tr>
                </thead>
                <tbody>
                  {(artworksQuery.data?.artworks ?? []).map((a) => (
                    <tr key={a.id} className={`border-b border-border last:border-0 hover:bg-muted/30 ${a.status === "hidden" ? "opacity-60" : ""}`}>
                      <td className={td}><Thumbs images={a.image ? [a.image] : []} /></td>
                      <td className={td}><AuthorCell name={a.author} /></td>
                      <td className={td}>
                        <p className="text-sm text-foreground max-w-[280px] line-clamp-2" title={a.prompt}>{a.prompt}</p>
                        {a.style && <p className="text-xs text-muted-foreground mt-0.5">风格：{a.style}</p>}
                      </td>
                      <td className={td}><StatusBadge status={a.status} /></td>
                      <td className={`${td} text-sm text-muted-foreground whitespace-nowrap`}>{a.date}</td>
                      <td className={td}>{actionCell("artworks", a.id, a.status)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        )}

        {tab === "reviews" && (
          reviewsQuery.isLoading ? (
            <p className="p-8 text-center text-muted-foreground">加载中…</p>
          ) : (reviewsQuery.data?.reviews ?? []).length === 0 ? (
            <p className="p-8 text-center text-muted-foreground">暂无评价</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border bg-muted/50">
                    <th className={th}>用户</th>
                    <th className={th}>商品</th>
                    <th className={th}>评价</th>
                    <th className={th}>图片</th>
                    <th className={th}>状态</th>
                    <th className={th}>时间</th>
                    <th className={th}>操作</th>
                  </tr>
                </thead>
                <tbody>
                  {(reviewsQuery.data?.reviews ?? []).map((r) => (
                    <tr key={r.id} className={`border-b border-border last:border-0 hover:bg-muted/30 ${r.status === "hidden" ? "opacity-60" : ""}`}>
                      <td className={td}><AuthorCell name={r.author} /></td>
                      <td className={td}>
                        <p className="text-sm text-foreground max-w-[160px] truncate" title={r.productName}>{r.productName}</p>
                      </td>
                      <td className={td}>
                        <p className="text-xs text-amber-500 font-medium">{"★".repeat(r.rating)}{"☆".repeat(Math.max(0, 5 - r.rating))}</p>
                        <p className="text-sm text-foreground max-w-[260px] line-clamp-2" title={r.content}>{r.content}</p>
                      </td>
                      <td className={td}><Thumbs images={r.images} /></td>
                      <td className={td}><StatusBadge status={r.status} /></td>
                      <td className={`${td} text-sm text-muted-foreground whitespace-nowrap`}>{r.date}</td>
                      <td className={td}>{actionCell("reviews", r.id, r.status)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        )}
      </div>
    </div>
  );
}
