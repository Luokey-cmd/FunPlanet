import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from "recharts";

interface CategoryPieChartProps {
  data?: { name: string; value: number; color: string }[];
}

/** 各商品大分类固定配色（马卡龙色系） */
const CATEGORY_COLORS: Record<string, string> = {
  玩具: "#9adbc5",
  文具: "#a1dee0",
  公仔: "#dfde6c",
  手办: "#fcc351",
  谷子: "#fd8d6e",
  小卡: "#fa86a9",
  其他: "#a1dee0",
};

const FALLBACK_COLORS = ["#9adbc5", "#a1dee0", "#dfde6c", "#fcc351", "#fd8d6e", "#fa86a9"];

function colorForCategory(name: string, index: number): string {
  return CATEGORY_COLORS[name] ?? FALLBACK_COLORS[index % FALLBACK_COLORS.length];
}

function CategoryTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: { name?: string; value?: number }[];
}) {
  if (!active || !payload?.length) return null;
  const name = payload[0].name ?? "";
  const value = Number(payload[0].value ?? 0);
  const amount = value.toLocaleString(undefined, { minimumFractionDigits: 1, maximumFractionDigits: 1 });
  return (
    <div
      className="rounded-xl border border-border bg-card px-3 py-2 text-xs text-foreground shadow-custom"
      style={{ fontSize: 12 }}
    >
      {name}营收：{amount}元
    </div>
  );
}

export default function CategoryPieChart({ data = [] }: CategoryPieChartProps) {
  const chartData = data.length
    ? data.map((item, index) => ({
        ...item,
        color: colorForCategory(item.name, index),
      }))
    : [{ name: "暂无", value: 1, color: "#c0e3f0" }];

  return (
    <div data-cmp="CategoryPieChart" className="bg-card rounded-2xl p-5 border border-border shadow-custom">
      <div className="mb-4">
        <h3 className="font-semibold text-foreground">各商品分类营收占比</h3>
        <p className="text-xs text-muted-foreground mt-0.5">按已付款订单营收统计</p>
      </div>
      <ResponsiveContainer width="100%" height={220}>
        <PieChart>
          <Pie
            data={chartData}
            cx="50%"
            cy="50%"
            innerRadius={55}
            outerRadius={85}
            paddingAngle={3}
            dataKey="value"
          >
            {chartData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.color} stroke="none" />
            ))}
          </Pie>
          <Tooltip content={<CategoryTooltip />} />
          <Legend
            wrapperStyle={{ fontSize: 11 }}
            formatter={(value) => <span style={{ color: "var(--muted-foreground)" }}>{value}</span>}
          />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
}
