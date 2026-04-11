import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

type LimitItem = {
  key: "primary" | "weekly";
  label: "5H" | "WEEK";
  remaining?: number;
};

type State = {
  lastUpdatedAt?: string;
  models: LimitItem[];
};

const AUTH_FILE = join(homedir(), ".pi", "agent", "auth.json");
const POLL_MS = Number(process.env.OPENAI_LIMIT_PI_AUTH_INTERVAL || 60000);

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}

function readCreds(): { access: string; accountId?: string } | null {
  try {
    if (!existsSync(AUTH_FILE)) return null;
    const raw = JSON.parse(readFileSync(AUTH_FILE, "utf8"));
    const codex = raw?.["openai-codex"];
    if (!codex?.access) return null;
    return { access: codex.access, accountId: codex.accountId };
  } catch {
    return null;
  }
}

function toRemainingPercent(win: any): number | undefined {
  if (!win) return undefined;
  const used = Number(win.used_percent ?? win.usedPercent);
  if (!Number.isFinite(used)) return undefined;
  return clamp(100 - used, 0, 100);
}

function parseWham(data: any): LimitItem[] {
  const rate = data?.rate_limit ?? data?.rateLimit;
  if (!rate) return [];

  return [
    { key: "primary", label: "5H", remaining: toRemainingPercent(rate.primary_window ?? rate.primaryWindow) },
    { key: "weekly", label: "WEEK", remaining: toRemainingPercent(rate.secondary_window ?? rate.secondaryWindow) },
  ];
}

function getLevel(remaining: number | undefined): "good" | "warn" | "bad" | "na" {
  if (remaining === undefined) return "na";
  if (remaining >= 50) return "good";
  if (remaining >= 20) return "warn";
  return "bad";
}

function unicodeBar(percent: number | undefined, width = 8) {
  if (percent === undefined) return { filled: "", empty: "▱".repeat(width) };
  const filled = clamp(Math.round((percent / 100) * width), 0, width);
  return {
    filled: "▰".repeat(filled),
    empty: "▱".repeat(width - filled),
  };
}

function row(theme: any, label: string, remaining: number | undefined) {
  const level = getLevel(remaining);
  const labelStyled = theme.fg("accent", label.padEnd(4));

  if (remaining === undefined) {
    return `${labelStyled} ${theme.fg("dim", "N/A")} ${theme.fg("dim", "▱▱▱▱▱▱▱▱")}`;
  }

  const { filled, empty } = unicodeBar(remaining);
  const color = level === "good" ? "success" : level === "warn" ? "warning" : "error";
  const pct = theme.fg(color, `${Math.round(remaining)}%`.padStart(3));
  const bar = `${theme.fg(color, filled)}${theme.fg("dim", empty)}`;
  return `${labelStyled} ${pct} ${bar}`;
}

function formatStatus(state: State, theme: any) {
  if (!state.models.length) return theme.fg("dim", "OA no data");

  const byKey = new Map(state.models.map((m) => [m.key, m]));
  const p = byKey.get("primary");
  const w = byKey.get("weekly");
  const sep = theme.fg("dim", "  │  ");
  const title = theme.fg("accent", "OA");
  return `${title} ${row(theme, "5H", p?.remaining)}${sep}${row(theme, "WEEK", w?.remaining)}`;
}

export default function (pi: ExtensionAPI) {
  let state: State = { models: [] };
  let timer: NodeJS.Timeout | undefined;

  const render = (ctx: any) => {
    const theme = ctx.ui.theme;
    const stale =
      state.lastUpdatedAt && Date.now() - new Date(state.lastUpdatedAt).getTime() > 3 * 60 * 1000;
    const text = stale ? `${formatStatus(state, theme)} ${theme.fg("dim", "(stale)")}` : formatStatus(state, theme);
    ctx.ui.setStatus("openai-limit", text);
  };

  const pull = async (ctx: any) => {
    try {
      const creds = readCreds();
      if (!creds?.access) return;

      const headers: Record<string, string> = {
        authorization: `Bearer ${creds.access}`,
        accept: "*/*",
        "user-agent": "codex-tui/pi-openai-limit",
      };
      if (creds.accountId) headers["chatgpt-account-id"] = creds.accountId;

      const res = await fetch("https://chatgpt.com/backend-api/wham/usage", { headers });
      if (!res.ok) return;

      const data = await res.json();
      const models = parseWham(data);
      if (!models.length) return;

      state = { lastUpdatedAt: new Date().toISOString(), models };
      render(ctx);
    } catch {
      // keep last good state
    }
  };

  pi.registerCommand("oalimit", {
    description: "Show OpenAI limit status",
    handler: async (_args, ctx) => {
      ctx.ui.notify(`status: ${formatStatus(state, ctx.ui.theme)}`, "info");
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setStatus("openai-limit", "OA syncing...");
    await pull(ctx);
    timer = setInterval(() => pull(ctx), Math.max(5000, POLL_MS));
  });

  pi.on("session_shutdown", async () => {
    if (timer) clearInterval(timer);
    timer = undefined;
  });
}
