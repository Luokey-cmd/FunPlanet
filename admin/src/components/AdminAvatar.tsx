import { useState } from "react";
import { resolveAssetUrl } from "../lib/assets";

const SIZE_CLASS = {
  sm: "w-9 h-9 rounded-xl text-lg",
  md: "w-16 h-16 rounded-2xl text-3xl",
  lg: "w-20 h-20 rounded-2xl text-4xl",
};

interface AdminAvatarProps {
  avatarPath?: string | null;
  name?: string;
  size?: keyof typeof SIZE_CLASS;
  uploading?: boolean;
  onClick?: () => void;
  fallback?: string;
}

export default function AdminAvatar({
  avatarPath,
  name,
  size = "md",
  uploading = false,
  onClick,
  fallback = "🪐",
}: AdminAvatarProps) {
  const [broken, setBroken] = useState(false);
  const url = avatarPath && !broken ? resolveAssetUrl(avatarPath) : "";
  const clickable = Boolean(onClick) && Boolean(url);

  return (
    <div className="relative flex-shrink-0">
      <button
        type="button"
        onClick={onClick}
        disabled={!clickable || uploading}
        className={`${SIZE_CLASS[size]} bg-primary/20 flex items-center justify-center overflow-hidden border border-border ${
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
        ) : (
          <span>{fallback}</span>
        )}
      </button>
      {uploading && (
        <div className="absolute inset-0 rounded-2xl bg-background/70 flex items-center justify-center text-xs text-muted-foreground">
          上传中
        </div>
      )}
    </div>
  );
}
