// 转化漏斗：数据由服务端 /dashboard 的 funnel 字段提供（真实用户数、按人去重），
// 本组件只负责画。旧版吃 mockData 假数据且从未挂上页面，2026-11-25 改为接真数据。
// 画法：每层一条横条，宽度 = 本层人数 / 第一层人数；右侧标注相对上一层的转化率。
interface FunnelStep {
  name: string;
  value: number;
}

interface ConversionFunnelProps {
  data?: FunnelStep[];
}

const COLORS = ["#a389f4", "#7ec8de", "#4cb9d6", "#fcc351", "#fa86a9"];

export default function ConversionFunnel({ data = [] }: ConversionFunnelProps) {
  const top = data[0]?.value ?? 0;
  const allZero = data.length === 0 || data.every((d) => d.value === 0);

  return (
    <div data-cmp="ConversionFunnel" className="bg-card rounded-2xl p-5 border border-border shadow-custom h-full">
      <div className="mb-4">
        <h3 className="font-semibold text-foreground">转化漏斗</h3>
        <p className="text-xs text-muted-foreground mt-0.5">浏览 → 收藏 → 加购 → 下单 → 支付（按用户数去重）</p>
      </div>
      {allZero ? (
        <p className="text-sm text-muted-foreground py-8 text-center">暂无数据</p>
      ) : (
        <div className="flex flex-col gap-3">
          {data.map((step, index) => {
            const prev = index === 0 ? null : data[index - 1].value;
            const rate = prev && prev > 0 ? Math.round((step.value / prev) * 100) : null;
            return (
              <div key={step.name}>
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm font-medium text-foreground">{step.name}</span>
                  <span className="text-xs text-muted-foreground">
                    <span className="text-sm font-semibold text-foreground">{step.value}</span> 人
                    {rate !== null && <span className="ml-2">转化 {rate}%</span>}
                  </span>
                </div>
                <div className="w-full h-3 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-500"
                    style={{
                      width: `${top > 0 ? Math.max((step.value / top) * 100, step.value > 0 ? 2 : 0) : 0}%`,
                      backgroundColor: COLORS[index % COLORS.length],
                    }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
