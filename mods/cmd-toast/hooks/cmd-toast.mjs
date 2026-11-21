// Command Toast: quiet by default, loud for what is long-running.
//
//   short commands               nothing at all
//   foreground, over LONG_SECS   a toast when it passes the mark and a toast with the result when it ends
//   background commands          a toast on start and a toast with the exit code when it ends
//
// A native toast is plain text that cannot change once shown, so the live part is a small card in the
// band above the prompt (one per running command, no status line):
//
//   ▶ npm run dev  1:42                      [Expand] [×]
//
// Expand shows the full command and the last lines of its output (refreshed every 2 s for background
// commands; Claude Code does not expose a foreground command's output until it ends). The × only hides
// the card: it never stops the command. A finished card disappears after a short while unless expanded.
//
// The host reads on(...) and $.noun.method(...) from source, so they are spelled literally,
// and helpers that take $ are top-level functions.

const LONG_SECS = 10;
const POLL_MS = 2000;
const FOLLOW_LIMIT_MS = 6 * 3600 * 1000;
const DONE_LINGER_MS = 20_000;     // a finished card stays this long (unless expanded)
const MAX_CARDS = 3;
const CARD_LINES = 8;              // output lines shown when expanded
const TAIL_LINES = 4;              // output lines in the result toast
const LINE_WIDTH = 90;
const PATH_RE = /Output is being written to: (\S+\.output)/;
const EXIT_RE = /\[exited with code (-?\d+)\]/;

let cards = new Map();             // id -> card
let nextId = 1;
let background = new Map();        // output path -> card
let poller = null;
let ticker = null;

export function register(on) {
  on("tool.call", { tool: "Bash" }, async ($, e, next) => {
    const full = String(e.command ?? "");
    const cmd = oneLine(full, 70);
    const who = e.agentId ? "[agent] " : "";
    const startedAt = await $.clock.now();
    let card = null;
    let over = false;              // set once the command has returned, so a late mark never makes a card
    const mark = $.clock.after(LONG_SECS * 1000, () => {
      if (over) return;
      card = addCard($, { cmd, full, who, startedAt, kind: "foreground" });
      $.ui.toast(`▶ ${who}${cmd}  (running over ${LONG_SECS}s)`, { timeoutMs: 3000 });
    });
    let ran;
    try {
      ran = await next(e);
    } catch (err) {
      over = true;
      mark.cancel();
      if (card) finish($, card, "failed", "", await $.clock.now());
      throw err;
    }
    over = true;
    mark.cancel();
    if (ran.deny !== undefined) {
      if (card) finish($, card, "failed", "", await $.clock.now());
      return ran;
    }
    const path = PATH_RE.exec(String(ran.text ?? ""))?.[1];
    if (path) {
      const bg = addCard($, { cmd, full, who, startedAt, kind: "background", path });
      background.set(path, bg);
      $.ui.toast(`⏵ ${who}${cmd}  (background)`, { timeoutMs: 3000 });
      if (!poller) {
        poller = $.clock.every(POLL_MS, () => follow($));
      }
      return ran;
    }
    if (card) {
      const now = await $.clock.now();
      const failed = ran.isError === true;
      const tail = lastLines(String(ran.text ?? ""));
      finish($, card, failed ? "failed" : "ok", tail, now);
      const head = `${failed ? "✘" : "✔"} ${who}${cmd}  (${((now - card.startedAt) / 1000).toFixed(1)}s)`;
      $.ui.toast(tail === "" ? head : `${head}\n${tail}`, { timeoutMs: failed ? 9000 : 5000 });
    }
    return ran;
  });

  on("ui.render", { component: "AbovePrompt" }, async ($, e, next) => {
    const shown = [...cards.values()].filter((c) => !c.hidden);
    if (e.hasSurvey || shown.length === 0) {
      return next(e);
    }
    const { Box, Text, Button } = $.ui.resolve(e);
    const now = await $.clock.now();
    const columns = e.bodyColumns ?? 80;
    const list = shown.slice(-MAX_CARDS);
    const rows = list.map((c) => renderCard(Box, Text, Button, $, c, now, columns));
    if (shown.length > list.length) {
      rows.unshift(Text({ dimColor: true, children: `+${shown.length - list.length} more` }));
    }
    return Box({ flexDirection: "column", children: rows });
  });
}

// ── cards ────────────────────────────────────────────────────────────────

function addCard($, c) {
  const made = { id: nextId++, state: "running", last: [], expanded: false, hidden: false, misses: 0, ...c };
  cards.set(made.id, made);
  if (!ticker) {
    ticker = $.clock.every(1000, () => tick($));
  }
  $.ui.invalidate("ui.render");
  return made;
}

function finish($, c, state, tail, now) {
  c.state = state;
  c.endedAt = now;
  if (tail !== "") c.last = tail.split("\n");
  $.ui.invalidate("ui.render");
}

// Once a second: drop finished cards that have lingered, redraw while any card shows, stop when none is left.
async function tick($) {
  const now = await $.clock.now();
  for (const [id, c] of [...cards.entries()]) {
    // A finished card goes when it is hidden, or after the linger unless the person expanded it
    // (an expanded one stays until they press ×).
    if (c.endedAt !== undefined && (c.hidden || (!c.expanded && now - c.endedAt > DONE_LINGER_MS))) {
      cards.delete(id);
    }
  }
  if (cards.size === 0 && ticker) {
    ticker.cancel();
    ticker = null;
  }
  if ([...cards.values()].some((c) => !c.hidden)) {
    $.ui.invalidate("ui.render");
  }
}

function renderCard(Box, Text, Button, $, c, now, columns) {
  const running = c.state === "running";
  const lost = c.state === "lost";
  const color = running || lost ? "warning" : c.state === "ok" ? "success" : "error";
  const icon = running ? "▶" : lost ? "?" : c.state === "ok" ? "✔" : "✘";
  const secs = Math.max(0, Math.round(((c.endedAt ?? now) - c.startedAt) / 1000));
  const room = Math.max(20, columns - 34);
  const status = running ? clock(secs) : `${c.state === "lost" ? "lost track" : c.state === "ok" ? (c.exit !== undefined ? `exit ${c.exit}` : "done") : c.exit !== undefined ? `exit ${c.exit}` : "failed"}, ${clock(secs)}`;
  const head = Box({
    flexDirection: "row",
    justifyContent: "space-between",
    children: [
      Text({ bold: true, color, children: `${icon} ${c.who}${clip(c.cmd, room)}  ${status}` }),
      Box({
        flexDirection: "row",
        gap: 1,
        children: [
          Button({ key: `exp-${c.id}`, label: c.expanded ? "Collapse" : "Expand", onPress: () => { c.expanded = !c.expanded; $.ui.invalidate("ui.render"); } }),
          Button({ key: `x-${c.id}`, label: "×", onPress: () => { c.hidden = true; $.ui.invalidate("ui.render"); } }),
        ],
      }),
    ],
  });
  if (!c.expanded) {
    return Box({ flexDirection: "column", paddingX: 1, children: [head] });
  }
  const body = [Text({ dimColor: true, children: `$ ${clip(oneLine(c.full, 400), columns * 2)}` })];
  if (c.last.length > 0) {
    for (const l of c.last.slice(-CARD_LINES)) body.push(Text({ children: clip(l, Math.max(20, columns - 6)) }));
  } else if (c.kind === "foreground" && running) {
    body.push(Text({ dimColor: true, children: "Output appears when the command ends (Claude Code does not expose it earlier)." }));
  } else {
    body.push(Text({ dimColor: true, children: "No output yet." }));
  }
  if (running) body.push(Text({ dimColor: true, children: "× only hides this card; the command keeps running." }));
  return Box({ flexDirection: "column", paddingX: 1, borderStyle: "round", borderColor: color, children: [head, ...body] });
}

// ── following background output ──────────────────────────────────────────

// Reads each followed output file: keeps its latest lines, and on its exit marker says so and stops following.
async function follow($) {
  const now = await $.clock.now();
  for (const [path, c] of [...background.entries()]) {
    let text = "";
    let readOk = false;
    try {
      const run = await $.process.run(["tail", "-n", "30", path], { timeoutMs: 3000 });
      readOk = run.exitCode === 0;
      text = readOk ? run.stdout : "";
    } catch {
      text = "";
    }
    // An output file that cannot be read (deleted, or never written) will never show an exit marker.
    // Give up after a few misses instead of leaving a card running for hours.
    c.misses = readOk ? 0 : c.misses + 1;
    if (c.misses >= 3) {
      background.delete(path);
      finish($, c, "lost", "", now);
      continue;
    }
    const exit = EXIT_RE.exec(text);
    const body = text.replace(EXIT_RE, "");
    c.last = cleanLines(body).slice(-CARD_LINES).map((l) => oneLine(l, LINE_WIDTH));
    if (exit || now - c.startedAt > FOLLOW_LIMIT_MS) {
      background.delete(path);
      const ok = exit && exit[1] === "0";
      c.exit = exit ? exit[1] : undefined;
      finish($, c, ok ? "ok" : "failed", "", now);
      const secs = Math.round((now - c.startedAt) / 1000);
      const head = `${ok ? "✔" : "✘"} ${c.who}${c.cmd}  (${exit ? `exit ${exit[1]}` : "stopped following"}, ${secs}s)`;
      const tail = lastLines(body);
      $.ui.toast(tail === "" ? head : `${head}\n${tail}`, { timeoutMs: ok ? 6000 : 10000 });
    }
  }
  if (background.size === 0 && poller) {
    poller.cancel();
    poller = null;
  }
  $.ui.invalidate("ui.render");
}

// ── helpers ──────────────────────────────────────────────────────────────

function clock(s) {
  return s >= 3600 ? `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, "0")}m` : `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

function oneLine(text, max) {
  const flat = text.replace(/\s+/g, " ").trim();
  return flat.length > max ? `${flat.slice(0, max - 1)}…` : flat;
}

function clip(text, max) {
  return text.length > max ? `${text.slice(0, Math.max(1, max - 1))}…` : text;
}

function cleanLines(text) {
  const clean = text.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "");
  return clean.split("\n").map((l) => l.trimEnd()).filter((l) => l !== "");
}

function lastLines(text) {
  return cleanLines(text).slice(-TAIL_LINES).map((l) => (l.length > LINE_WIDTH ? `${l.slice(0, LINE_WIDTH - 1)}…` : l)).join("\n");
}
