import { useTheme } from "next-themes";

const TRANSITION_MS = 750;

function prefersReducedMotion() {
  return typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function withCssTransition(apply: () => void) {
  const root = document.documentElement;
  root.classList.add("theme-transition");
  apply();
  window.setTimeout(() => root.classList.remove("theme-transition"), TRANSITION_MS);
}

export function useThemeTransition() {
  const { resolvedTheme, setTheme } = useTheme();

  const applyTheme = (theme: "light" | "dark") => {
    if (prefersReducedMotion()) {
      setTheme(theme);
      return;
    }

    const apply = () => setTheme(theme);

    if (typeof document.startViewTransition === "function") {
      document.startViewTransition(apply);
      return;
    }

    withCssTransition(apply);
  };

  const toggleTheme = () => {
    applyTheme(resolvedTheme === "dark" ? "light" : "dark");
  };

  return { resolvedTheme, toggleTheme, applyTheme };
}
