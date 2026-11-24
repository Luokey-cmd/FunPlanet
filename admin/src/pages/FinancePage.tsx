import { useQuery } from "@tanstack/react-query";
import { DownloadIcon, WalletIcon } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { adminApi, ApiError } from "../lib/api";

// 财务账单（2026-11-24 新增）：流水只认支付交易——收款看付款时刻、
// 退款看退款生效时刻，同一笔先收后退会出现两行（对账口径）。
// 实收 = 收款 - 退款，与服务端汇总同一算法。
function todayStr(offsetDays = 0): string {
  const d = new Date(Date.now() + offsetDays * 24 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function monthStartStr(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-01`;
}

const methodLabel: Record<string, string> = {
  mock: "模拟支付",
  wechat: "微信支付",
  alipay: "支付宝",
};

export default function FinancePage() {
  const [from, setFrom] = useState(monthStartStr());
  const [to, setTo] = useState(todayStr());
  const [type, setType] = useState<"all" | "payment" | "refund">("all");
  const [page, setPage] = useState(1);
  const pageSize = 20;

  const summaryQuery = useQuery({
    queryKey: ["admin-finance-summary", from, to],
    queryFn: () => adminApi.financeSummary({ from, to }),
  });
  const txQuery = useQuery({
    queryKey: ["admin-finance-tx", from, to, type, page],
    queryFn: () => adminApi.financeTransactions({ from, to, type, page, pageSize }),
  });

  const summary = summaryQuery.data?.summary;
  const rows = txQuery.data?.transactions ?? [];
  const total = txQuery.data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  const applyRange = (f: string, t: string) => {
    setFrom(f);
    setTo(t);
    setPage(1);
  };

  const exportCsv = async () => {
    try {
      await adminApi.exportFinance({ from, to });
      toast.success("已导出 CSV");
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : "导出失败");
    }
  };

  const cards = [
    { label: "总收入", value: summary?.income ?? 0, cls: "text-foreground", sub: `${summary?.paidCount ?? 0} 笔收款` },
    { label: "总退款", value: summary?.refunds ?? 0, cls: "text-red-500", sub: `${summary?.refundCount ?? 0} 笔退款` },
    { label: "实际收入", value: summary?.net ?? 0, cls: "text-emerald-600", sub: "收入 - 退款" },
  ];

  return (
    <div data-cmp="FinancePage" className="p-6 flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-foreground">财务账单</h2>
          <p className="text-sm text-muted-foreground">按支付流水对账：收款看付款时刻，退款看退款生效时刻</p>
        </div>
        <button
          onClick={exportCsv}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:opacity-90 transition-opacity"
        >
          <DownloadIcon size={15} />
          导出 CSV
        </button>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <input
          type="date"
          value={from}
          onChange={(e) => applyRange(e.target.value, to)}
          className="px-3 py-2 rounded-xl border border-border bg-card text-sm focus:outline-none focus:ring-2 focus:ring-ring"
        />
        <span className="text-muted-foreground text-sm">至</span>
        <input
          type="date"
          value={to}
          onChange={(e) => applyRange(from, e.target.value)}
          className="px-3 py-2 rounded-xl border border-border bg-card text-sm focus:outline-none focus:ring-2 focus:ring-ring"
        />
        <div className="flex gap-2 ml-2">
          <button
            onClick={() => applyRange(monthStartStr(), todayStr())}
            className="px-3 py-1.5 rounded-full text-sm border border-input bg-background hover:bg-muted"
          >
            本月
          </button>
          <button
            onClick={() => applyRange(todayStr(-29), todayStr())}
            className="px-3 py-1.5 rounded-full text-sm border border-input bg-background hover:bg-muted"
          >
            近 30 天
          </button>
          <button
            onClick={() => applyRange("2020-01-01", todayStr())}
            className="px-3 py-1.5 rounded-full text-sm border border-input bg-background hover:bg-muted"
          >
            全部
          </button>
        </div>
        <div className="flex gap-2 ml-auto">
          {(
            [
              { v: "all", label: "全部" },
              { v: "payment", label: "只看收款" },
              { v: "refund", label: "只看退款" },
            ] as const
          ).map((opt) => (
            <button
              key={opt.v}
              onClick={() => {
                setType(opt.v);
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-full text-sm border transition-colors ${
                type === opt.v
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-background text-foreground border-input hover:bg-muted"
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        {cards.map((c) => (
          <div key={c.label} className="bg-card rounded-2xl border border-border shadow-custom p-5">
            <p className="text-sm text-muted-foreground flex items-center gap-2">
              <WalletIcon size={15} />
              {c.label}
            </p>
            <p className={`text-3xl font-bold mt-2 ${c.cls}`}>¥{(c.value ?? 0).toFixed(2)}</p>
            <p className="text-xs text-muted-foreground mt-1">{c.sub}</p>
          </div>
        ))}
      </div>

      <div className="bg-card rounded-2xl border border-border shadow-custom p-5">
        {txQuery.isLoading ? (
          <p className="text-muted-foreground text-sm">加载中…</p>
        ) : rows.length === 0 ? (
          <p className="text-muted-foreground text-sm text-center py-8">这个时间段里没有流水</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-muted-foreground border-b border-border">
                  <th className="py-2 pr-4 font-medium">时间</th>
                  <th className="py-2 pr-4 font-medium">类型</th>
                  <th className="py-2 pr-4 font-medium">订单号</th>
                  <th className="py-2 pr-4 font-medium">用户</th>
                  <th className="py-2 pr-4 font-medium">支付方式</th>
                  <th className="py-2 font-medium text-right">金额</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b border-border last:border-0">
                    <td className="py-2 pr-4 whitespace-nowrap text-muted-foreground">
                      {new Date(row.at).toLocaleString("zh-CN", { hour12: false }).replaceAll("-", "/")}
                    </td>
                    <td className="py-2 pr-4 whitespace-nowrap">
                      {row.kind === "payment" ? (
                        <span className="text-xs px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-600">收款</span>
                      ) : (
                        <span className="text-xs px-2 py-0.5 rounded-full bg-red-100 text-red-600">退款</span>
                      )}
                    </td>
                    <td className="py-2 pr-4 whitespace-nowrap text-foreground">{row.orderNo}</td>
                    <td className="py-2 pr-4 whitespace-nowrap">
                      {row.userName || "（未设昵称）"}
                      <span className="text-muted-foreground"> · {row.userPhone}</span>
                    </td>
                    <td className="py-2 pr-4 whitespace-nowrap text-muted-foreground">{methodLabel[row.method] ?? row.method}</td>
                    <td className={`py-2 whitespace-nowrap text-right font-medium ${row.amount >= 0 ? "text-emerald-600" : "text-red-500"}`}>
                      {row.amount >= 0 ? "+" : ""}
                      ¥{row.amount.toFixed(2)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {total > 0 && (
          <div className="flex items-center justify-between mt-4 text-sm text-muted-foreground">
            <span>
              共 {total} 条 · 第 {page}/{totalPages} 页
            </span>
            <div className="flex gap-2">
              <button
                disabled={page <= 1}
                onClick={() => setPage(page - 1)}
                className="px-3 py-1.5 rounded-lg border border-input bg-background disabled:opacity-40"
              >
                上一页
              </button>
              <button
                disabled={page >= totalPages}
                onClick={() => setPage(page + 1)}
                className="px-3 py-1.5 rounded-lg border border-input bg-background disabled:opacity-40"
              >
                下一页
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
