import { useState } from "react";
import { ImageIcon } from "lucide-react";
import { resolveAssetUrl } from "../lib/assets";

interface BannerImageProps {
  imagePath?: string | null;
  alt?: string;
  className?: string;
}

export default function BannerImage({ imagePath, alt = "", className = "" }: BannerImageProps) {
  const [failed, setFailed] = useState(false);
  const src = resolveAssetUrl(imagePath);
  const showImage = Boolean(src) && !failed;

  return (
    <div className={`bg-secondary overflow-hidden ${className}`}>
      {showImage ? (
        <img
          src={src}
          alt={alt}
          className="w-full h-full object-cover"
          loading="lazy"
          onError={() => setFailed(true)}
        />
      ) : (
        <div className="w-full h-full flex items-center justify-center text-muted-foreground">
          <ImageIcon size={32} />
        </div>
      )}
    </div>
  );
}
