import { useRef, useState } from "react";
import { ImagePlusIcon } from "lucide-react";
import { toast } from "sonner";
import { readImageFileAsBase64 } from "../lib/image-file";
import { resolveAssetUrl } from "../lib/assets";

interface AdminImagePickerProps {
  label: string;
  imagePath: string;
  onImagePathChange: (path: string) => void;
  onUpload: (body: { imageBase64: string; mimeType: string }) => Promise<{ imagePath: string }>;
  previewAlt?: string;
  previewClassName?: string;
}

export default function AdminImagePicker({
  label,
  imagePath,
  onImagePathChange,
  onUpload,
  previewAlt = "图片预览",
  previewClassName = "h-32 w-full object-contain rounded-xl border border-border bg-muted/30",
}: AdminImagePickerProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  const handleSelect = async (file: File) => {
    setUploading(true);
    try {
      const payload = await readImageFileAsBase64(file);
      const res = await onUpload(payload);
      onImagePathChange(res.imagePath);
      toast.success("图片已上传");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "上传失败");
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  };

  const previewSrc = resolveAssetUrl(imagePath);

  return (
    <div className="flex flex-col gap-2 text-sm">
      <span className="text-muted-foreground">{label}</span>
      {previewSrc ? (
        <img src={previewSrc} alt={previewAlt} className={previewClassName} />
      ) : (
        <div className={`flex items-center justify-center text-muted-foreground text-xs ${previewClassName}`}>
          尚未选择图片
        </div>
      )}
      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) void handleSelect(file);
        }}
      />
      <button
        type="button"
        disabled={uploading}
        onClick={() => inputRef.current?.click()}
        className="flex items-center justify-center gap-2 py-2.5 rounded-xl border border-dashed border-primary/40 bg-primary/5 text-primary text-sm font-medium hover:bg-primary/10 transition-colors disabled:opacity-60"
      >
        <ImagePlusIcon size={16} />
        {uploading ? "上传中…" : imagePath ? "重新选择图片" : "选择图片"}
      </button>
    </div>
  );
}
