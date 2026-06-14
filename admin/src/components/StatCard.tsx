import { TrendingUpIcon, TrendingDownIcon } from "lucide-react";

interface StatCardProps {
  title?: string;
  value?: string | number;
  growth?: number;
  icon?: string;
  color?: string;
  prefix?: string;
}

export default function StatCard({
  title = "统计项",
  value = 0,
  growth = 0,
  icon = "📊",
  color = "#f48fb1",
  prefix = "",
}: StatCardProps) {
  const isPositive = growth >= 0;

  return (
    <div
      data-cmp="StatCard"
      className="bg-card rounded-2xl p-5 border border-border shadow-custom flex flex-col gap-4"
    >
      <div className="flex items-center justify-between">
        <span className="text-sm text-muted-foreground font-medium">{title}</span>
        <div
          className="w-10 h-10 rounded-xl flex items-center justify-center text-xl"
          style={{ backgroundColor: color + "30" }}
        >
          {icon}
        </div>
      </div>
      <div>
        <p className="text-2xl font-bold text-foreground">
          {prefix}
          {typeof value === "number" ? value.toLocaleString() : value}
        </p>
        <div className="flex items-center gap-1 mt-1">
          {isPositive ? (
            <TrendingUpIcon size={13} style={{ color: "#a5d6a7" }} />
          ) : (
            <TrendingDownIcon size={13} style={{ color: "#f48fb1" }} />
          )}
          <span
            className="text-xs font-medium"
            style={{ color: isPositive ? "#6abf69" : "#e57373" }}
          >
            {isPositive ? "+" : ""}
            {growth}%
          </span>
          <span className="text-xs text-muted-foreground">较上月</span>
        </div>
      </div>
    </div>
  );
}
