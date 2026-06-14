interface TopProductItem {
  id: string;
  name: string;
  sales: number;
  price: number;
  majorCategory: string;
}

interface TopProductsProps {
  products?: TopProductItem[];
  limit?: number;
}

const barColors = ["#4cb9d6", "#7ec8de", "#2e9bb8", "#c0e3f0", "#5bc0de"];

export default function TopProducts({ products = [], limit = 5 }: TopProductsProps) {
  const sorted = [...products].sort((a, b) => b.sales - a.sales).slice(0, limit);
  const maxSales = sorted[0]?.sales ?? 1;

  return (
    <div data-cmp="TopProducts" className="bg-card rounded-2xl p-5 border border-border shadow-custom">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="font-semibold text-foreground">热销商品排行</h3>
          <p className="text-xs text-muted-foreground mt-0.5">按销量排序</p>
        </div>
      </div>
      {sorted.length === 0 ? (
        <p className="text-sm text-muted-foreground py-8 text-center">暂无数据</p>
      ) : (
        <div className="flex flex-col gap-4">
          {sorted.map((product, index) => (
            <div key={product.id} className="flex items-center gap-3">
              <span
                className="w-6 h-6 rounded-lg flex items-center justify-center text-xs font-bold flex-shrink-0"
                style={{
                  backgroundColor: `${barColors[index]}30`,
                  color: barColors[index],
                }}
              >
                {index + 1}
              </span>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm font-medium text-foreground truncate pr-2">{product.name}</span>
                  <span className="text-xs font-semibold text-foreground flex-shrink-0">{product.sales}</span>
                </div>
                <div className="w-full h-1.5 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-500"
                    style={{
                      width: `${(product.sales / maxSales) * 100}%`,
                      backgroundColor: barColors[index],
                    }}
                  />
                </div>
              </div>
              <span className="text-xs text-muted-foreground flex-shrink-0">¥{product.price}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
