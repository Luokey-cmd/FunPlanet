import { useEffect, useMemo, useState } from "react";
import ReactECharts from "echarts-for-react";
import * as echarts from "echarts/core";
import { MapChart } from "echarts/charts";
import { TooltipComponent, VisualMapComponent, GeoComponent } from "echarts/components";
import { CanvasRenderer } from "echarts/renderers";

echarts.use([MapChart, TooltipComponent, VisualMapComponent, GeoComponent, CanvasRenderer]);

type RegionHeatItem = { name: string; value: number };

interface ProvinceHeatMapProps {
  data?: RegionHeatItem[];
}

export default function ProvinceHeatMap({ data = [] }: ProvinceHeatMapProps) {
  const [mapReady, setMapReady] = useState(false);
  const [mapError, setMapError] = useState(false);
  const [selectedName, setSelectedName] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch("/geo/china.json");
        if (!res.ok) throw new Error("map load failed");
        const geoJson = await res.json();
        if (cancelled) return;
        echarts.registerMap("china", geoJson);
        setMapReady(true);
      } catch {
        if (!cancelled) setMapError(true);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const maxValue = useMemo(() => {
    const max = Math.max(0, ...data.map((d) => d.value));
    return Math.max(max, 1);
  }, [data]);

  const seriesData = useMemo(() => {
    const byName = new Map(data.map((d) => [d.name, d.value]));
    if (selectedName && !byName.has(selectedName)) {
      byName.set(selectedName, 0);
    }
    return [...byName.entries()].map(([name, value]) => ({
      name,
      value,
      selected: name === selectedName,
    }));
  }, [data, selectedName]);

  const option = useMemo(
    () => ({
      tooltip: {
        trigger: "item" as const,
        backgroundColor: "rgba(255,255,255,0.96)",
        borderColor: "rgba(76,185,214,0.35)",
        borderWidth: 1,
        textStyle: { color: "#334155", fontSize: 12 },
        formatter: (params: { name?: string; value?: number | null }) => {
          const value = typeof params.value === "number" ? params.value : 0;
          return `<div style="font-weight:600;margin-bottom:4px">${params.name ?? ""}</div>
            <div>订单数量：${Number.isFinite(value) ? value : 0}</div>`;
        },
      },
      visualMap: {
        min: 0,
        max: maxValue,
        left: 12,
        bottom: 24,
        calculable: true,
        orient: "vertical" as const,
        inRange: {
          color: ["#e8f7fb", "#a8dff0", "#4cb9d6", "#2e9bb8", "#1f7a91"],
        },
        text: [String(maxValue), "0"],
        textStyle: { color: "#64748b", fontSize: 11 },
        itemWidth: 12,
        itemHeight: 100,
      },
      series: [
        {
          name: "订单数量",
          type: "map" as const,
          map: "china",
          roam: false,
          selectedMode: "single" as const,
          // 半宽卡片内尽量铺满；略下移并缩小，避免北部省份被裁切
          layoutCenter: ["55%", "56%"],
          layoutSize: "98%",
          label: {
            show: false,
            color: "#1e293b",
            fontSize: 11,
            fontWeight: 600 as const,
            formatter: "{b}",
          },
          itemStyle: {
            areaColor: "#eef6f9",
            borderColor: "#c5dbe3",
            borderWidth: 0.8,
          },
          // 悬停：鲜亮珊瑚橙 + 省名
          emphasis: {
            label: {
              show: true,
              color: "#0f172a",
              fontSize: 12,
              fontWeight: 700 as const,
              textBorderColor: "#ffffff",
              textBorderWidth: 2,
            },
            itemStyle: {
              areaColor: "#ff6b35",
              borderColor: "#ff3d00",
              borderWidth: 1.4,
              shadowBlur: 12,
              shadowColor: "rgba(255, 107, 53, 0.45)",
            },
          },
          // 点击选中：鲜亮金黄 + 省名
          select: {
            label: {
              show: true,
              color: "#0f172a",
              fontSize: 12,
              fontWeight: 700 as const,
              textBorderColor: "#ffffff",
              textBorderWidth: 2,
            },
            itemStyle: {
              areaColor: "#ffd60a",
              borderColor: "#ffaa00",
              borderWidth: 1.6,
              shadowBlur: 14,
              shadowColor: "rgba(255, 214, 10, 0.5)",
            },
          },
          data: seriesData,
        },
      ],
    }),
    [maxValue, seriesData],
  );

  const onEvents = useMemo(
    () => ({
      click: (params: { name?: string; componentType?: string }) => {
        if (params.componentType !== "series" || !params.name) return;
        setSelectedName((prev) => (prev === params.name ? prev : params.name ?? null));
      },
    }),
    [],
  );

  return (
    <div
      data-cmp="ProvinceHeatMap"
      className="bg-card rounded-2xl p-5 border border-border shadow-custom h-full flex flex-col"
    >
      <div className="mb-2">
        <h3 className="font-semibold text-foreground">地区热力分布</h3>
        <p className="text-xs text-muted-foreground mt-0.5">
          悬停显示省名，点击省份可黄色高亮（单选）
        </p>
      </div>
      {mapError ? (
        <div className="flex-1 min-h-[360px] flex items-center justify-center text-sm text-muted-foreground">
          地图资源加载失败
        </div>
      ) : !mapReady ? (
        <div className="flex-1 min-h-[360px] flex items-center justify-center text-sm text-muted-foreground">
          地图加载中…
        </div>
      ) : (
        <ReactECharts
          echarts={echarts}
          option={option}
          className="flex-1 min-h-[360px] w-full"
          style={{ height: 400, width: "100%" }}
          opts={{ renderer: "canvas" }}
          onEvents={onEvents}
          notMerge
        />
      )}
    </div>
  );
}
