import { PlusIcon, XIcon } from "lucide-react";
import { useState } from "react";
import type { SavedAdminAccount } from "../lib/account-store";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "./ui/alert-dialog";
import AdminAvatar from "./AdminAvatar";

type AccountSwitchListProps = {
  accounts: SavedAdminAccount[];
  currentUsername?: string;
  onSwitch: (username: string) => void;
  onAdd?: () => void;
  onRemove?: (username: string) => void;
  compact?: boolean;
};

export default function AccountSwitchList({
  accounts,
  currentUsername,
  onSwitch,
  onAdd,
  onRemove,
  compact = false,
}: AccountSwitchListProps) {
  const [pendingRemove, setPendingRemove] = useState<SavedAdminAccount | null>(null);

  return (
    <>
      <div className="flex flex-col">
        {accounts.map((account) => {
          const current = account.username === currentUsername;
          const needsLogin = !account.token;
          return (
            <div
              key={account.username}
              className={`flex items-center gap-1 ${compact ? "" : "rounded-xl"} ${
                current ? "bg-muted/50" : ""
              }`}
            >
              <button
                type="button"
                disabled={current}
                onClick={() => onSwitch(account.username)}
                className={`min-w-0 flex-1 flex items-center gap-3 text-left transition-colors ${
                  compact ? "px-4 py-2.5" : "px-3 py-2.5 rounded-xl"
                } ${current ? "cursor-default" : "hover:bg-muted"}`}
              >
                <AdminAvatar avatarPath={account.avatarPath} name={account.name} size="sm" />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-foreground truncate">{account.name}</p>
                  <p className="text-xs text-muted-foreground truncate">
                    账号 {account.username}
                    {needsLogin ? " · 需重新登录" : ""}
                  </p>
                </div>
                {current ? (
                  <span className="text-[11px] text-primary flex-shrink-0">当前</span>
                ) : null}
              </button>
              {onRemove && !current ? (
                <button
                  type="button"
                  aria-label={`移除账号 ${account.username}`}
                  onClick={() => setPendingRemove(account)}
                  className="p-2 mr-1 rounded-lg text-muted-foreground hover:text-destructive hover:bg-destructive/10 flex-shrink-0"
                >
                  <XIcon size={14} />
                </button>
              ) : null}
            </div>
          );
        })}
        {onAdd ? (
          <button
            type="button"
            onClick={onAdd}
            className={`w-full flex items-center gap-3 text-left text-sm font-medium text-foreground hover:bg-muted transition-colors ${
              compact ? "px-4 py-2.5" : "px-3 py-2.5 rounded-xl"
            }`}
          >
            <span className="w-9 h-9 rounded-full border border-dashed border-border flex items-center justify-center text-muted-foreground flex-shrink-0">
              <PlusIcon size={16} />
            </span>
            添加账号
          </button>
        ) : null}
      </div>

      <AlertDialog
        open={Boolean(pendingRemove)}
        onOpenChange={(open) => {
          if (!open) setPendingRemove(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>确认移除账号？</AlertDialogTitle>
            <AlertDialogDescription>
              确定从本机列表中移除「{pendingRemove?.name ?? ""}」（账号{" "}
              {pendingRemove?.username ?? ""}）？移除后切换该账号需重新登录。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                if (pendingRemove) onRemove?.(pendingRemove.username);
                setPendingRemove(null);
              }}
            >
              确认移除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
