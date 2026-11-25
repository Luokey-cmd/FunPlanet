// 系列销量排行：已支付订单按商品所属系列聚合的销售额排行（服务端 seriesRanking 字段）。
// 与「热销商品排行」的区别：那个是单品榜，这个是系列榜，看哪个系列整体卖得动。
interface SeriesRankItem {
  name: string;
  revenue: number;
  quantity: number;
}

interface SeriesRankingProps {
  data?: SeriesRankItem[];
}

const barColors = ["#a389f4", "#7ec8de", "#4cb9d6", "#fcc351", "#fa86a9", "#9adbc5", "#fd8d6e", "#c4b5fd"];

export default function SeriesRanking({ data = [] }: SeriesRankingProps) {
  const maxRevenue = data[0]?.revenue ?? 0;

  return (
    <div data-cmp="SeriesRanking" className="bg-card rounded-2xl p-5 border border-border shadow-custom h-full">
      <div className="mb-4">
        <h3 className="font-semibold text-foreground">系列销量排行</h3>
        <p className="text-xs text-muted-foreground mt-0.5">按已支付销售额 · 系列维度</p>
      </div>
      {data.length === 0 ? (
        <p className="text-sm text-muted-foreground py-8 text-center">暂无数据</p>
      ) : (
        <div className="flex flex-col gap-4">
          {data.map((item, index) => (
            <div key={item.name} className="flex items-center gap-3">
              <span
                className="w-6 h-6 rounded-lg flex items-center justify-center text-xs font-bold flex-shrink-0"
                style={{
                  backgroundColor: `${barColors[index % barColors.length]}30`,
                  color: barColors[index % barColors.length],
                }}
              >
                {index + 1}
              </span>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm font-medium text-foreground truncate pr-2">{item.name}</span>
                  <span className="text-xs font-semibold text-foreground flex-shrink-0">
                    ¥{item.revenue.toLocaleString()}
                    <span className="text-muted-foreground font-normal ml-2">{item.quantity} 件</span>
                  </span>
                </div>
                <div className="w-full h-1.5 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-500"
                    style={{
                      width: `${maxRevenue > 0 ? (item.revenue / maxRevenue) * 100 : 0}%`,
                      backgroundColor: barColors[index % barColors.length],
                    }}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
