// Agent Board: one docked pane with two parts.
//   TOKENS  context fill, the 5-hour and 7-day limit windows, the session's estimated cost,
//           and tokens per model (counted from when the mod loaded).
//   AGENTS  one tile per running subagent, laid out like a tiling window manager:
//           one agent fills the area, two split it, more keep splitting the remainder.
//
// The pane opens with a transparent background, so a glassy or blurred terminal shows through
// (nothing is painted), whatever terminal the person uses.
//
// Colours are theme keys (claude, success, warning, error, suggestion), so the board follows the
// person's Claude Code theme instead of fixed colour names.
//
// All figures come from the engine: $.session.usage() and $.agent.list(). The cost is an
// estimate at API rates; on a subscription it is not a charge. The pane needs room beside the
// transcript (about 110 columns); where there is none it is simply not shown, `/board` says so.
//
// The host reads on(...) and $.noun.method(...) from source, so they are spelled literally,
// and helpers that take $ are top-level functions.

const PANE = "agent-board";
const LINGER_MS = 30_000;     // how long a finished agent's tile stays
const SLOW_EVERY = 5;         // redraw every N seconds when nothing is running
const BUSY = new Set(["running", "pending", "waiting"]);

let tally = {};               // model -> { input, cached, output, turns }
let sessionStart = 0;
let ended = {};               // agent id -> ms it was first seen finished
let ticks = 0;

export function register(on) {
  on("session.start", async ($, e, next) => {
    const result = await next(e);
    try {
      sessionStart = (await $.session.usage()).startedAt;
      const saved = await $.store.get("tally");
      tally = saved && saved.sessionStart === sessionStart ? saved.tally : {};
    } catch {
      tally = {};
    }
    await $.command.register({ name: "board", description: "Show the agent and token board" });
    void $.ui.open({ id: PANE, title: "Board", backgroundColor: "transparent" });
    $.clock.every(1000, () => tick($));
    return result;
  });

  on("command.run", { command: "board" }, async ($) => {
    const opened = await $.ui.open({ id: PANE, title: "Board", backgroundColor: "transparent" });
    return { text: opened.isPlaced ? "Board opened." : "No room for the board here: it needs a wider window (about 110 columns)." };
  });

  on("turn.complete", async ($, e, next) => {
    const result = await next(e);
    if (e.usage) {
      addUsage(e.usage);
      try {
        await $.store.set("tally", { sessionStart, tally });
      } catch {
        // Not persisted; the tally still lives in memory.
      }
    }
    $.ui.invalidate("ui.render");
    return result;
  });

  on("ui.render", { component: "Pane", requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e);
    const columns = e.viewport?.columns ?? e.bodyColumns ?? 44;
    let usage = null;
    let agents = [];
    try { usage = await $.session.usage(); } catch { /* no figures yet */ }
    try { agents = await $.agent.list(); } catch { /* no agents */ }
    const now = await $.clock.now();
    return Box({
      flexDirection: "column",
      flexGrow: 1,
      overflow: "hidden",
      children: [tokenBox(Box, Text, usage, now, columns), agentArea(Box, Text, agents, now, columns)],
    });
  });
}

async function tick($) {
  ticks += 1;
  try {
    const list = await $.agent.list();
    if (list.some((a) => BUSY.has(a.status)) || ticks % SLOW_EVERY === 0) {
      $.ui.invalidate("ui.render");
    }
  } catch {
    // Try again next second.
  }
}

function addUsage(u) {
  const key = u.model || "unknown";
  const t = tally[key] ?? { input: 0, cached: 0, output: 0, turns: 0 };
  t.input += (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0);
  t.cached += u.cache_read_input_tokens ?? 0;
  t.output += u.output_tokens ?? 0;
  t.turns += 1;
  tally[key] = t;
}

// ── TOKENS ───────────────────────────────────────────────────────────────

function tokenBox(Box, Text, usage, now, columns) {
  const barW = Math.max(8, Math.min(22, columns - 26));
  const rows = [Text({ bold: true, color: "claude", children: "TOKENS" })];
  const ctx = usage?.context;
  if (ctx && ctx.window) {
    const pct = Math.round(ctx.percent ?? ((ctx.tokens ?? 0) / ctx.window) * 100);
    rows.push(meter(Text, "context", pct, barW, `${short(ctx.tokens ?? 0)}/${short(ctx.window)}`));
  }
  for (const [kind, label] of [["five_hour", "5 hour"], ["seven_day", "7 day"]]) {
    const w = (usage?.rateLimits ?? []).find((r) => r.kind === kind);
    if (w) {
      rows.push(meter(Text, label, Math.round(w.percentUsed), barW, w.resetsAt ? `resets ${until(w.resetsAt, now)}` : ""));
    }
  }
  if (usage?.cost && typeof usage.cost.usd === "number") {
    rows.push(Text({ dimColor: true, children: `session  est $${usage.cost.usd.toFixed(2)}  (API rates, not a charge)` }));
  }
  const models = Object.entries(tally).sort((a, b) => b[1].output - a[1].output).slice(0, 4);
  if (models.length > 0) {
    rows.push(Text({ dimColor: true, children: "per model since the mod loaded" }));
    for (const [id, t] of models) {
      rows.push(Text({ children: [Text({ color: "suggestion", children: `${modelName(id)} ` }), Text({ dimColor: true, children: `in ${short(t.input)} · cached ${short(t.cached)} · out ${short(t.output)}` })] }));
    }
  }
  return Box({ flexDirection: "column", borderStyle: "round", borderColor: "claude", paddingX: 1, children: rows });
}

function meter(Text, label, pct, width, note) {
  const p = Math.max(0, Math.min(100, pct));
  const filled = Math.round((p / 100) * width);
  const color = p >= 85 ? "error" : p >= 60 ? "warning" : "success";
  return Text({
    children: [
      Text({ dimColor: true, children: `${label.padEnd(8)}` }),
      Text({ color, children: "━".repeat(filled) }),
      Text({ dimColor: true, children: "━".repeat(width - filled) }),
      Text({ color, bold: true, children: ` ${String(p).padStart(3)}%` }),
      Text({ dimColor: true, children: note ? ` ${note}` : "" }),
    ],
  });
}

// ── AGENTS ───────────────────────────────────────────────────────────────

function agentArea(Box, Text, agents, now, columns) {
  const shown = agents.filter((a) => {
    if (BUSY.has(a.status) || a.status === "idle") {
      delete ended[a.id];
      return true;
    }
    ended[a.id] = ended[a.id] ?? now;
    return now - ended[a.id] < LINGER_MS;
  });
  const head = Text({ bold: true, color: "suggestion", children: `AGENTS  ${shown.filter((a) => BUSY.has(a.status)).length} running` });
  if (shown.length === 0) {
    return Box({ flexDirection: "column", flexGrow: 1, paddingX: 1, children: [head, Text({ dimColor: true, children: "No subagents running." })] });
  }
  return Box({ flexDirection: "column", flexGrow: 1, overflow: "hidden", children: [Box({ paddingX: 1, children: [head] }), tiles(Box, Text, shown, now, columns, true)] });
}

// Dwindle layout: the first agent takes half, the rest split the other half, alternating direction.
function tiles(Box, Text, list, now, columns, vertical) {
  if (list.length === 1) {
    return tile(Box, Text, list[0], now, columns);
  }
  const [head, ...rest] = list;
  return Box({
    flexDirection: vertical ? "column" : "row",
    flexGrow: 1,
    children: [tile(Box, Text, head, now, columns), tiles(Box, Text, rest, now, columns, !vertical)],
  });
}

function tile(Box, Text, a, now, columns) {
  const busy = BUSY.has(a.status);
  const color = busy ? "claude" : a.status === "failed" || a.status === "killed" ? "error" : "success";
  const endAt = busy || a.status === "idle" ? now : ended[a.id] ?? now;
  const elapsed = clock(Math.max(0, endAt - a.startTime));
  const outTokens = (a.usage ?? []).reduce((n, u) => n + (u.output_tokens ?? 0), 0);
  const ctx = a.contextWindowSize ? `${short(a.tokenCount ?? 0)}/${short(a.contextWindowSize)}` : short(a.tokenCount ?? 0);
  const cost = a.cost && typeof a.cost.usd === "number" ? `  est $${a.cost.usd.toFixed(2)}` : "";
  const room = Math.max(10, Math.floor(columns / 2) - 6);
  const task = clip(String(a.label || a.description || "").replace(/\s+/g, " "), room * 2);
  return Box({
    flexDirection: "column",
    flexGrow: 1,
    borderStyle: "round",
    borderColor: color,
    paddingX: 1,
    overflow: "hidden",
    children: [
      Text({ bold: true, color, children: `${busy ? "●" : a.status === "idle" ? "○" : a.status === "completed" ? "✔" : "✘"} ${clip(a.name || a.type, room)}` }),
      Text({ dimColor: true, children: `${modelName(a.model || "")}  ${elapsed}` }),
      Text({ children: `ctx ${ctx}  out ${short(outTokens)}${cost}` }),
      Text({ dimColor: true, children: task }),
    ],
  });
}

// ── small helpers ────────────────────────────────────────────────────────

function modelName(id) {
  return String(id).replace(/^claude-/, "").replace(/-\d{8}$/, "") || "model?";
}

function clock(ms) {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  return m >= 60 ? `${Math.floor(m / 60)}h${String(m % 60).padStart(2, "0")}m` : `${m}:${String(s % 60).padStart(2, "0")}`;
}

function until(iso, now) {
  const ms = Date.parse(iso) - now;
  if (!(ms > 0)) return "now";
  const m = Math.round(ms / 60000);
  if (m < 60) return `in ${m}m`;
  const h = Math.floor(m / 60);
  return h < 48 ? `in ${h}h${String(m % 60).padStart(2, "0")}m` : `in ${Math.floor(h / 24)}d ${h % 24}h`;
}

function clip(text, max) {
  return text.length > max ? `${text.slice(0, Math.max(1, max - 1))}…` : text;
}

function short(n) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(n >= 10_000 ? 0 : 1)}k`;
  return String(n);
}
