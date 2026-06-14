import { useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ImageIcon, KeyboardIcon, SendIcon, SmileIcon, XIcon } from "lucide-react";
import { toast } from "sonner";
import AdminAvatar from "../components/AdminAvatar";
import { adminApi, ApiError, type SupportConversation, type SupportMessage } from "../lib/api";
import { resolveAssetUrl } from "../lib/assets";
import { readImageFileAsBase64 } from "../lib/image-file";
import { getSupportStickerEmoji, SUPPORT_STICKER_LIST } from "../lib/support-stickers";

function formatTime(iso: string) {
  const d = new Date(iso);
  const now = new Date();
  const sameDay =
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();
  if (sameDay) {
    return d.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
  }
  return d.toLocaleString("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

interface SupportPageProps {
  initialConversationId?: string | null;
  onInitialConversationHandled?: () => void;
}

export default function SupportPage({
  initialConversationId = null,
  onInitialConversationHandled,
}: SupportPageProps) {
  const queryClient = useQueryClient();
  const [selectedId, setSelectedId] = useState<string | null>(initialConversationId);
  const [draft, setDraft] = useState("");
  const [showStickers, setShowStickers] = useState(false);
  const listRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const [uploadingImage, setUploadingImage] = useState(false);
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  const conversationsQuery = useQuery({
    queryKey: ["admin-support-conversations"],
    queryFn: () => adminApi.supportConversations(),
    refetchInterval: 4000,
  });

  const conversations = conversationsQuery.data?.conversations ?? [];

  useEffect(() => {
    if (initialConversationId) {
      setSelectedId(initialConversationId);
      onInitialConversationHandled?.();
    }
  }, [initialConversationId, onInitialConversationHandled]);

  useEffect(() => {
    if (!selectedId && conversations.length > 0) {
      setSelectedId(conversations[0].id);
    }
  }, [conversations, selectedId]);

  useEffect(() => {
    setShowStickers(false);
  }, [selectedId]);

  useEffect(() => {
    if (!previewImage) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setPreviewImage(null);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [previewImage]);

  const messagesQuery = useQuery({
    queryKey: ["admin-support-messages", selectedId],
    queryFn: () => adminApi.supportMessages(selectedId!),
    enabled: Boolean(selectedId),
    refetchInterval: 3000,
  });

  const markReadMutation = useMutation({
    mutationFn: (id: string) => adminApi.markSupportRead(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-support-conversations"] });
      queryClient.invalidateQueries({ queryKey: ["admin-support-notifications"] });
    },
  });

  useEffect(() => {
    if (selectedId && messagesQuery.data?.conversation?.unreadAdmin) {
      markReadMutation.mutate(selectedId);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId, messagesQuery.data?.conversation?.unreadAdmin]);

  const sendMutation = useMutation({
    mutationFn: ({ id, content }: { id: string; content: string }) =>
      adminApi.sendSupportMessage(id, { content, messageType: "text" }),
    onSuccess: () => {
      setDraft("");
      queryClient.invalidateQueries({ queryKey: ["admin-support-messages", selectedId] });
      queryClient.invalidateQueries({ queryKey: ["admin-support-conversations"] });
    },
    onError: (e: Error) => toast.error(e instanceof ApiError ? e.message : "发送失败"),
  });

  const messages = messagesQuery.data?.messages ?? [];
  const active = conversations.find((c) => c.id === selectedId) ?? messagesQuery.data?.conversation;

  useEffect(() => {
    if (!listRef.current) return;
    listRef.current.scrollTop = listRef.current.scrollHeight;
  }, [messages.length, selectedId]);

  const handleSend = (e: React.FormEvent) => {
    e.preventDefault();
    const text = draft.trim();
    if (!text || !selectedId || sendMutation.isPending) return;
    sendMutation.mutate({ id: selectedId, content: text });
    setShowStickers(false);
  };

  const insertEmoji = (emoji: string) => {
    const input = inputRef.current;
    if (!input) {
      setDraft((prev) => prev + emoji);
      return;
    }
    const start = input.selectionStart ?? draft.length;
    const end = input.selectionEnd ?? draft.length;
    const next = draft.slice(0, start) + emoji + draft.slice(end);
    setDraft(next);
    requestAnimationFrame(() => {
      input.focus();
      const pos = start + emoji.length;
      input.setSelectionRange(pos, pos);
    });
  };

  const inputDisabled = sendMutation.isPending || uploadingImage;

  const handlePickImage = async (file: File) => {
    if (!selectedId || inputDisabled) return;
    setUploadingImage(true);
    setShowStickers(false);
    try {
      const payload = await readImageFileAsBase64(file);
      const { mediaUrl } = await adminApi.uploadSupportImage(payload.imageBase64, payload.mimeType);
      await adminApi.sendSupportMessage(selectedId, {
        messageType: "image",
        mediaUrl,
        content: "[图片]",
      });
      queryClient.invalidateQueries({ queryKey: ["admin-support-messages", selectedId] });
      queryClient.invalidateQueries({ queryKey: ["admin-support-conversations"] });
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : error instanceof Error ? error.message : "图片发送失败");
    } finally {
      setUploadingImage(false);
      if (imageInputRef.current) imageInputRef.current.value = "";
    }
  };

  return (
    <div data-cmp="SupportPage" className="p-6 flex flex-col gap-4 h-full min-h-[calc(100vh-4rem)]">
      <div>
        <h2 className="text-lg font-semibold text-foreground">客服中心</h2>
        <p className="text-sm text-muted-foreground">查看 App 用户咨询并实时回复</p>
      </div>

      <div className="flex flex-1 min-h-0 gap-4 flex-col lg:flex-row">
        <div className="w-full lg:w-80 flex-shrink-0 bg-card border border-border rounded-2xl shadow-custom overflow-hidden flex flex-col max-h-64 lg:max-h-none">
          <div className="px-4 py-3 border-b border-border font-medium text-sm">会话列表</div>
          <div className="flex-1 overflow-y-auto">
            {conversationsQuery.isLoading ? (
              <p className="p-4 text-sm text-muted-foreground">加载中…</p>
            ) : conversations.length === 0 ? (
              <p className="p-8 text-sm text-muted-foreground text-center">暂无用户咨询</p>
            ) : (
              conversations.map((conv) => (
                <ConversationItem
                  key={conv.id}
                  conversation={conv}
                  active={conv.id === selectedId}
                  onClick={() => setSelectedId(conv.id)}
                />
              ))
            )}
          </div>
        </div>

        <div className="flex-1 min-w-0 bg-card border border-border rounded-2xl shadow-custom flex flex-col min-h-[420px]">
          {!selectedId || !active ? (
            <div className="flex-1 flex items-center justify-center text-muted-foreground text-sm">
              选择左侧会话开始回复
            </div>
          ) : (
            <>
              <div className="px-5 py-4 border-b border-border">
                <div className="min-w-0">
                  <p className="font-semibold text-foreground truncate">
                    {active.userNickname ?? "用户"}
                    {active.productName ? ` · ${active.productName}` : ""}
                  </p>
                  <p className="text-xs text-muted-foreground mt-0.5 truncate">
                    {active.subject ?? "在线客服"}
                    {active.userPhone ? ` · ${active.userPhone}` : ""}
                  </p>
                </div>
              </div>

              <div ref={listRef} className="flex-1 overflow-y-auto p-4 space-y-3">
                {messagesQuery.isLoading ? (
                  <p className="text-sm text-muted-foreground text-center py-8">加载消息…</p>
                ) : (
                  messages.map((msg) => (
                    <MessageBubble key={msg.id} message={msg} onPreviewImage={setPreviewImage} />
                  ))
                )}
              </div>

              {showStickers && (
                <StickerPanel onPick={insertEmoji} />
              )}

              <form onSubmit={handleSend} className="p-4 border-t border-border flex gap-2 items-center">
                <input
                  ref={imageInputRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp,image/gif"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) void handlePickImage(file);
                  }}
                />
                <button
                  type="button"
                  onClick={() => imageInputRef.current?.click()}
                  disabled={inputDisabled}
                  title="发送图片"
                  className="w-10 h-10 rounded-xl border border-border bg-background hover:bg-muted disabled:opacity-50 flex items-center justify-center flex-shrink-0 transition-colors"
                >
                  <ImageIcon size={18} className="text-primary" />
                </button>
                <button
                  type="button"
                  onClick={() => setShowStickers((v) => !v)}
                  disabled={inputDisabled}
                  title={showStickers ? "键盘" : "表情"}
                  className="w-10 h-10 rounded-xl border border-border bg-background hover:bg-muted disabled:opacity-50 flex items-center justify-center flex-shrink-0 transition-colors"
                >
                  {showStickers ? (
                    <KeyboardIcon size={18} className="text-foreground" />
                  ) : (
                    <SmileIcon size={18} className="text-primary" />
                  )}
                </button>
                <input
                  ref={inputRef}
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  placeholder="输入回复内容…"
                  disabled={inputDisabled}
                  className="flex-1 px-4 py-2.5 rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-ring text-sm"
                />
                <button
                  type="submit"
                  disabled={!draft.trim() || inputDisabled}
                  className="px-4 py-2.5 rounded-xl bg-primary text-primary-foreground disabled:opacity-50 flex items-center gap-2 text-sm font-medium flex-shrink-0"
                >
                  <SendIcon size={16} />
                  发送
                </button>
              </form>
            </>
          )}
        </div>
      </div>

      {previewImage && <ImagePreviewOverlay src={previewImage} onClose={() => setPreviewImage(null)} />}
    </div>
  );
}

function ConversationItem({
  conversation,
  active,
  onClick,
}: {
  conversation: SupportConversation;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`w-full text-left px-4 py-3 border-b border-border last:border-0 hover:bg-muted/60 transition-colors ${
        active ? "bg-primary/10" : ""
      }`}
    >
      <div className="flex items-start gap-2">
        <AdminAvatar
          avatarPath={conversation.userAvatarPath}
          name={conversation.userNickname ?? "用户"}
          size="sm"
          fallback="👤"
        />
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2">
            <span className="text-sm font-medium truncate">{conversation.userNickname ?? "用户"}</span>
            <span className="text-[10px] text-muted-foreground flex-shrink-0">
              {formatTime(conversation.lastMessageAt)}
            </span>
          </div>
          <p className="text-xs text-muted-foreground truncate mt-0.5" translate="no">
            {conversation.productName ? `[${conversation.productName}] ` : ""}
            {conversation.lastMessagePreview ?? "暂无消息"}
          </p>
        </div>
        {conversation.unreadAdmin > 0 && (
          <span className="w-5 h-5 rounded-full bg-destructive text-destructive-foreground text-[10px] flex items-center justify-center flex-shrink-0">
            {conversation.unreadAdmin > 9 ? "9+" : conversation.unreadAdmin}
          </span>
        )}
      </div>
    </button>
  );
}

function StickerPanel({ onPick }: { onPick: (emoji: string) => void }) {
  return (
    <div className="border-t border-border bg-muted/30 px-4 py-3">
      <div className="grid grid-cols-6 gap-2">
        {SUPPORT_STICKER_LIST.map((sticker) => (
          <button
            key={sticker.id}
            type="button"
            title={sticker.label}
            onClick={() => onPick(sticker.emoji)}
            className="aspect-square rounded-xl bg-background border border-border hover:bg-muted transition-colors flex items-center justify-center text-2xl"
          >
            {sticker.emoji}
          </button>
        ))}
      </div>
    </div>
  );
}

function MessageBubble({
  message,
  onPreviewImage,
}: {
  message: SupportMessage;
  onPreviewImage: (src: string) => void;
}) {
  const isAdmin = message.senderRole === "admin";
  const isSticker = message.messageType === "sticker";
  const isImage = message.messageType === "image";
  const stickerEmoji = getSupportStickerEmoji(message.stickerId) ?? message.content;
  const imageSrc = isImage && message.mediaUrl ? resolveAssetUrl(message.mediaUrl) : "";

  return (
    <div className={`flex ${isAdmin ? "justify-end" : "justify-start"}`}>
      <div
        className={`max-w-[75%] ${
          isSticker ? "px-1 py-1 bg-transparent" : "px-3.5 py-2.5 rounded-2xl text-sm leading-relaxed"
        } ${
          isSticker
            ? ""
            : isAdmin
              ? "bg-primary text-primary-foreground rounded-br-md"
              : "bg-muted text-foreground rounded-bl-md"
        }`}
      >
        {!isAdmin && !isSticker && message.senderName && (
          <p className="text-[10px] opacity-70 mb-1">{message.senderName}</p>
        )}
        {isImage && imageSrc ? (
          <button
            type="button"
            onClick={() => onPreviewImage(imageSrc)}
            className="block p-0 border-0 bg-transparent cursor-zoom-in"
            title="点击查看大图"
          >
            <img
              src={imageSrc}
              alt={isAdmin ? "客服发送的图片" : "用户发送的图片"}
              className="max-w-[220px] rounded-xl border border-border/50"
            />
          </button>
        ) : isSticker ? (
          <p className="text-4xl leading-none" translate="no" lang="und">
            {stickerEmoji}
          </p>
        ) : (
          <p className="whitespace-pre-wrap break-words" translate="no" lang="und">
            {message.content}
          </p>
        )}
        {!isSticker && (
          <p className={`text-[10px] mt-1 ${isAdmin ? "text-primary-foreground/70" : "text-muted-foreground"}`}>
            {formatTime(message.createdAt)}
          </p>
        )}
      </div>
    </div>
  );
}

function ImagePreviewOverlay({ src, onClose }: { src: string; onClose: () => void }) {
  return (
    <div
      className="fixed inset-0 z-[100] bg-black/85 flex items-center justify-center p-6"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label="图片预览"
    >
      <button
        type="button"
        onClick={onClose}
        className="absolute top-4 right-4 w-10 h-10 rounded-full bg-black/50 text-white flex items-center justify-center hover:bg-black/70 transition-colors"
        aria-label="关闭预览"
      >
        <XIcon size={20} />
      </button>
      <img
        src={src}
        alt="大图预览"
        className="max-w-full max-h-full object-contain rounded-lg shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      />
    </div>
  );
}
