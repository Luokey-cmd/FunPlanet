import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";
import { mockWeeklyData } from "../data/mockData";

export default function WeeklyBarChart() {
  return (
    <div data-cmp="WeeklyBarChart" className="bg-card rounded-2xl p-5 border border-border shadow-custom">
      <div className="mb-5">
        <h3 className="font-semibold text-foreground">本周访问与销售</h3>
        <p className="text-xs text-muted-foreground mt-0.5">每日访问量与销售额对比</p>
      </div>
      <ResponsiveContainer width="100%" height={220}>
        <BarChart data={mockWeeklyData} margin={{ top: 5, right: 5, left: -10, bottom: 0 }} barGap={4}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e8dff5" />
          <XAxis dataKey="day" tick={{ fontSize: 11, fill: "#8b7aaa" }} axisLine={false} tickLine={false} />
          <YAxis tick={{ fontSize: 11, fill: "#8b7aaa" }} axisLine={false} tickLine={false} />
          <Tooltip
            contentStyle={{
              backgroundColor: "#fff",
              border: "1px solid #e8dff5",
              borderRadius: 12,
              fontSize: 12,
            }}
          />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          <Bar dataKey="visits" name="访问量" fill="#f8bbd0" radius={[6, 6, 0, 0]} />
          <Bar dataKey="sales" name="销售额" fill="#90caf9" radius={[6, 6, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
