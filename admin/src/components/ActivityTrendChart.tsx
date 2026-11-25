// 活跃趋势：近 30 天四条线（新增用户 / 订单 / 社区发帖 / 小豆咨询），
// 数据来自服务端 /dashboard 的 dailyActivity 字段，全部真实计数、没数据就是 0。
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";

interface ActivityDay {
  day: string;
  newUsers: number;
  orders: number;
  posts: number;
  chats: number;
}

interface ActivityTrendChartProps {
  data?: ActivityDay[];
}

export default function ActivityTrendChart({ data = [] }: ActivityTrendChartProps) {
  const chartData = data.map((d) => ({ ...d, label: d.day.slice(5) || d.day }));

  return (
    <div data-cmp="ActivityTrendChart" className="bg-card rounded-2xl p-5 border border-border shadow-custom">
      <div className="mb-5">
        <h3 className="font-semibold text-foreground">活跃趋势</h3>
        <p className="text-xs text-muted-foreground mt-0.5">近30天 · 新增用户 / 订单 / 社区发帖 / 小豆咨询</p>
      </div>
      <ResponsiveContainer width="100%" height={240}>
        <LineChart data={chartData} margin={{ top: 5, right: 5, left: -10, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
          <XAxis dataKey="label" tick={{ fontSize: 11, fill: "var(--muted-foreground)" }} axisLine={false} tickLine={false} />
          <YAxis tick={{ fontSize: 11, fill: "var(--muted-foreground)" }} axisLine={false} tickLine={false} allowDecimals={false} />
          <Tooltip
            contentStyle={{
              backgroundColor: "var(--card)",
              border: "1px solid var(--border)",
              borderRadius: 12,
              fontSize: 12,
              color: "var(--foreground)",
            }}
          />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          <Line type="monotone" dataKey="newUsers" name="新增用户" stroke="#a389f4" strokeWidth={2} dot={false} />
          <Line type="monotone" dataKey="orders" name="订单" stroke="#4cb9d6" strokeWidth={2} dot={false} />
          <Line type="monotone" dataKey="posts" name="社区发帖" stroke="#fa86a9" strokeWidth={2} dot={false} />
          <Line type="monotone" dataKey="chats" name="小豆咨询" stroke="#fcc351" strokeWidth={2} dot={false} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
