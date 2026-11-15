import { useThemeTransition } from "../hooks/useThemeTransition";
import { useEffect, useState } from "react";
import "./SunMoonToggle.css";

const STARS = [
  { size: 1.5, top: "13%", left: "20%" },
  { size: 0.5, top: "28%", left: "10%" },
  { size: 0.7, top: "43%", left: "22%" },
  { size: 0.4, top: "20%", left: "42%" },
  { size: 0.8, top: "73%", left: "46%" },
];

const CLOUDS_NEAR = [
  { size: 1.2, top: "15%", right: "-13%" },
  { size: 1.3, top: "39%", right: "-5%" },
  { size: 1.0, top: "66%", right: "5%" },
];

const CLOUDS_FAR = [
  { size: 1.2, top: "2%", right: "-5%" },
  { size: 1.4, top: "25%", right: "5%" },
  { size: 1.0, top: "37%", right: "10%" },
];

const CRATERS = [
  { size: 0.18, top: "15%", left: "38%" },
  { size: 0.32, top: "46%", left: "13%" },
  { size: 0.22, top: "61%", left: "61%" },
];

export default function SunMoonToggle() {
  const { resolvedTheme, toggleTheme } = useThemeTransition();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  if (!mounted) {
    return <div className="w-[90px] h-9 rounded-full bg-muted" aria-hidden />;
  }

  const isDark = resolvedTheme === "dark";

  return (
    <button
      type="button"
      className={`sun-moon-toggle ${isDark ? "is-night" : "is-day"}`}
      onClick={toggleTheme}
      aria-label={isDark ? "切换为白天模式" : "切换为黑夜模式"}
      title={isDark ? "白天模式" : "黑夜模式"}
    >
      <div className="sky">
        <div className="inner-shadow" />
        <div className={isDark ? "sky-night" : "sky-day"} />
      </div>

      <div className="star-cloud-box">
        <div className="star-box">
          {STARS.map((star, i) => (
            <span
              key={i}
              className="star"
              style={{
                height: `calc(var(--star-size) * ${star.size})`,
                width: `calc(var(--star-size) * ${star.size})`,
                top: star.top,
                left: star.left,
              }}
            />
          ))}
        </div>
        <div className="cloud-box">
          <div className="cloud-near">
            {CLOUDS_NEAR.map((cloud, i) => (
              <span
                key={i}
                className="cloud"
                style={{
                  height: `calc(var(--near-cloud-size) / ${cloud.size})`,
                  width: `calc(var(--near-cloud-size) / ${cloud.size})`,
                  top: cloud.top,
                  right: cloud.right,
                }}
              />
            ))}
          </div>
          <div className="cloud-far">
            {CLOUDS_FAR.map((cloud, i) => (
              <span
                key={i}
                className="cloud"
                style={{
                  height: `calc(var(--far-cloud-size) / ${cloud.size})`,
                  width: `calc(var(--far-cloud-size) / ${cloud.size})`,
                  top: cloud.top,
                  right: cloud.right,
                }}
              />
            ))}
          </div>
        </div>
      </div>

      <div className="halo-box">
        <div className={`halo-inner ${isDark ? "halo-right" : "halo-left"}`} />
        <div className={`halo-middle ${isDark ? "halo-right" : "halo-left"}`} />
        <div className={`halo-outer ${isDark ? "halo-right" : "halo-left"}`} />
      </div>

      <div className="ball-box">
        <div className="ball-cut-in">
          <div className="sun" />
          <div className="moon">
            <div className="moon-body">
              {CRATERS.map((crater, i) => (
                <span
                  key={i}
                  className="moon-crater"
                  style={{
                    height: `calc(var(--ball-size) * ${crater.size})`,
                    width: `calc(var(--ball-size) * ${crater.size})`,
                    top: crater.top,
                    left: crater.left,
                  }}
                />
              ))}
            </div>
            <div className="moon-shadow" />
          </div>
        </div>
      </div>
    </button>
  );
}
