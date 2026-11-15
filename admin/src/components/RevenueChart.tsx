import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

interface RevenueChartProps {
  data?: { day: string; revenue: number }[];
}

export default function RevenueChart({ data = [] }: RevenueChartProps) {
  const chartData = data.length
    ? data.map((d) => ({ ...d, label: d.day.slice(5) || d.day }))
    : [{ day: "-", label: "-", revenue: 0 }];

  return (
    <div data-cmp="RevenueChart" className="bg-card rounded-2xl p-5 border border-border shadow-custom">
      <div className="flex items-center justify-between mb-5">
        <div>
          <h3 className="font-semibold text-foreground">营收趋势</h3>
          <p className="text-xs text-muted-foreground mt-0.5">近30天已付款订单</p>
        </div>
      </div>
      <ResponsiveContainer width="100%" height={260}>
        <AreaChart data={chartData} margin={{ top: 5, right: 5, left: -10, bottom: 0 }}>
          <defs>
            <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#4cb9d6" stopOpacity={0.35} />
              <stop offset="95%" stopColor="#4cb9d6" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
          <XAxis dataKey="label" tick={{ fontSize: 11, fill: "var(--muted-foreground)" }} axisLine={false} tickLine={false} />
          <YAxis tick={{ fontSize: 11, fill: "var(--muted-foreground)" }} axisLine={false} tickLine={false} />
          <Tooltip
            contentStyle={{
              backgroundColor: "var(--card)",
              border: "1px solid var(--border)",
              borderRadius: 12,
              fontSize: 12,
              color: "var(--foreground)",
            }}
            formatter={(value: number) => [`¥${value.toLocaleString()}`, "营收"]}
          />
          <Area
            type="monotone"
            dataKey="revenue"
            stroke="#4cb9d6"
            strokeWidth={2.5}
            fill="url(#colorRevenue)"
            dot={false}
            activeDot={{ r: 5, fill: "#2e9bb8" }}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
