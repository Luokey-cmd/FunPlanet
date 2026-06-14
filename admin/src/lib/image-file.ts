const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"];

export async function readImageFileAsBase64(file: File): Promise<{ imageBase64: string; mimeType: string }> {
  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    throw new Error("仅支持 JPG、PNG、WebP、GIF");
  }

  const dataUrl = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });

  const base64 = dataUrl.split(",")[1];
  if (!base64) {
    throw new Error("图片读取失败");
  }

  return { imageBase64: base64, mimeType: file.type };
}
