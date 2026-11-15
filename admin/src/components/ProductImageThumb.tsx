import { useState } from "react";
import { resolveAssetUrl } from "../lib/assets";

interface ProductImageThumbProps {
  imagePath?: string | null;
  alt?: string;
  size?: number;
  className?: string;
}

export default function ProductImageThumb({
  imagePath,
  alt = "",
  size = 40,
  className = "",
}: ProductImageThumbProps) {
  const [failed, setFailed] = useState(false);
  const src = resolveAssetUrl(imagePath);
  const showImage = Boolean(src) && !failed;

  return (
    <div
      className={`rounded-xl bg-card border border-border overflow-hidden flex items-center justify-center flex-shrink-0 ${className}`}
      style={{ width: size, height: size }}
    >
      {showImage ? (
        <img
          src={src}
          alt={alt}
          className="w-full h-full object-contain"
          loading="lazy"
          onError={() => setFailed(true)}
        />
      ) : (
        <span className="text-lg" style={{ fontSize: size * 0.45 }}>
          🎁
        </span>
      )}
    </div>
  );
}
