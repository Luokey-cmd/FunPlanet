import { useState } from "react";
import { UserRoundIcon } from "lucide-react";
import { resolveAssetUrl } from "../lib/assets";

const SIZE_CLASS = {
  sm: "w-9 h-9 text-lg",
  md: "w-16 h-16 text-3xl",
  lg: "w-20 h-20 text-4xl",
};

const ICON_SIZE = {
  sm: 20,
  md: 34,
  lg: 42,
};

interface AdminAvatarProps {
  avatarPath?: string | null;
  name?: string;
  size?: keyof typeof SIZE_CLASS;
  uploading?: boolean;
  onClick?: () => void;
  fallback?: string;
  silhouette?: boolean;
  circle?: boolean;
}

export default function AdminAvatar({
  avatarPath,
  name,
  size = "md",
  uploading = false,
  onClick,
  fallback = "🪐",
  silhouette = false,
  circle = false,
}: AdminAvatarProps) {
  const [broken, setBroken] = useState(false);
  const url = avatarPath && !broken ? resolveAssetUrl(avatarPath) : "";
  const clickable = Boolean(onClick) && Boolean(url);
  const radius = circle ? "rounded-full" : size === "sm" ? "rounded-xl" : "rounded-2xl";

  return (
    <div className="relative flex-shrink-0">
      <button
        type="button"
        onClick={onClick}
        disabled={!clickable || uploading}
        className={`${SIZE_CLASS[size]} ${radius} bg-primary/20 flex items-center justify-center overflow-hidden border border-border ${
          clickable ? "cursor-pointer hover:ring-2 hover:ring-ring transition-shadow" : "cursor-default"
        }`}
        title={clickable ? "查看大图" : undefined}
      >
        {url ? (
          <img
            key={avatarPath ?? "default"}
            src={url}
            alt={name ?? "管理员头像"}
            className="w-full h-full object-cover"
            onError={() => setBroken(true)}
          />
        ) : silhouette ? (
          <UserRoundIcon size={ICON_SIZE[size]} className="text-primary" strokeWidth={2} />
        ) : (
          <span>{fallback}</span>
        )}
      </button>
      {uploading && (
        <div className={`absolute inset-0 ${radius} bg-background/70 flex items-center justify-center text-xs text-muted-foreground`}>
          上传中
        </div>
      )}
    </div>
  );
}
