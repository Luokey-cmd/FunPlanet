import {
  FunnelChart,
  Funnel,
  LabelList,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from "recharts";
import { mockConversionData } from "../data/mockData";

const COLORS = ["#ce93d8", "#90caf9", "#a5d6a7", "#ffcc80"];

export default function ConversionFunnel() {
  return (
    <div data-cmp="ConversionFunnel" className="bg-card rounded-2xl p-5 border border-border shadow-custom">
      <div className="mb-4">
        <h3 className="font-semibold text-foreground">转化漏斗</h3>
        <p className="text-xs text-muted-foreground mt-0.5">用户购买转化率</p>
      </div>
      <ResponsiveContainer width="100%" height={220}>
        <FunnelChart>
          <Tooltip
            contentStyle={{
              backgroundColor: "#fff",
              border: "1px solid #e8dff5",
              borderRadius: 12,
              fontSize: 12,
            }}
          />
          <Funnel dataKey="value" data={mockConversionData} isAnimationActive>
            {mockConversionData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
            ))}
            <LabelList position="right" fill="#8b7aaa" stroke="none" dataKey="name" style={{ fontSize: 12 }} />
            <LabelList position="left" fill="#8b7aaa" stroke="none" dataKey="value" style={{ fontSize: 12 }} formatter={(v: number) => `${v}%`} />
          </Funnel>
        </FunnelChart>
      </ResponsiveContainer>
    </div>
  );
}
