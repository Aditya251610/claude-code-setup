// Command Toast: quiet by default, loud for what is long-running.
//
//   short commands            nothing at all
//   foreground, over LONG_SECS   a toast when it passes the mark, a live timer in the status line,
//                                and a toast with the result and the last lines when it ends
//                                (Claude Code does not expose a foreground command's output
//                                before it ends)
//   background commands       a toast on start; the status line follows the command's output file
//                                live (its latest line, refreshed every 2 s); a toast with the exit
//                                code and the last lines when it ends
//
// A toast cannot be updated in place, so the live view is the status line, which can.
//
// The host reads on(...) and $.noun.method(...) from source, so they are spelled literally,
// and helpers that take $ are top-level functions.

const LONG_SECS = 10;
const POLL_MS = 2000;
const FOLLOW_LIMIT_MS = 6 * 3600 * 1000;
const TAIL_LINES = 4;
const LINE_WIDTH = 90;
const PATH_RE = /Output is being written to: (\S+\.output)/;
const EXIT_RE = /\[exited with code (-?\d+)\]/;

let background = new Map();   // output path -> { cmd, who, startedAt, last }
let poller = null;
let foreground = null;        // { cmd, who, startedAt } while a long foreground command runs

export function register(on) {
  on("tool.call", { tool: "Bash" }, async ($, e, next) => {
    const cmd = oneLine(String(e.command ?? ""), 70);
    const who = e.agentId ? "[agent] " : "";
    const startedAt = await $.clock.now();
    let isLong = false;
    let liveTimer = null;
    const mark = $.clock.after(LONG_SECS * 1000, () => {
      isLong = true;
      foreground = { cmd, who, startedAt };
      $.ui.toast(`▶ ${who}${cmd}  (running over ${LONG_SECS}s)`, { timeoutMs: 3000 });
      liveTimer = $.clock.every(1000, () => paint($));
      paint($);
    });
    let ran;
    try {
      ran = await next(e);
    } finally {
      mark.cancel();
      if (liveTimer) liveTimer.cancel();
      if (isLong) foreground = null;
    }
    if (ran.deny !== undefined) {
      paint($);
      return ran;
    }
    const path = PATH_RE.exec(String(ran.text ?? ""))?.[1];
    if (path) {
      background.set(path, { cmd, who, startedAt: await $.clock.now(), last: "" });
      $.ui.toast(`⏵ ${who}${cmd}  (background)`, { timeoutMs: 3000 });
      if (!poller) {
        poller = $.clock.every(POLL_MS, () => follow($));
      }
      paint($);
      return ran;
    }
    if (isLong) {
      const secs = (((await $.clock.now()) - startedAt) / 1000).toFixed(1);
      const tail = lastLines(String(ran.text ?? ""));
      const head = `${ran.isError === true ? "✘" : "✔"} ${who}${cmd}  (${secs}s)`;
      $.ui.toast(tail === "" ? head : `${head}\n${tail}`, { timeoutMs: ran.isError === true ? 9000 : 5000 });
    }
    paint($);
    return ran;
  });
}

// Reads each followed output file: keeps its latest line, and on its exit marker says so and stops following.
async function follow($) {
  const now = await $.clock.now();
  for (const [path, task] of [...background.entries()]) {
    let text = "";
    try {
      const run = await $.process.run(["tail", "-n", "30", path], { timeoutMs: 3000 });
      text = run.exitCode === 0 ? run.stdout : "";
    } catch {
      text = "";
    }
    const exit = EXIT_RE.exec(text);
    const body = text.replace(EXIT_RE, "");
    const lines = body.split("\n").map((l) => l.trimEnd()).filter((l) => l !== "");
    task.last = lines.length > 0 ? oneLine(lines[lines.length - 1], 80) : "";
    if (exit || now - task.startedAt > FOLLOW_LIMIT_MS) {
      background.delete(path);
      const secs = Math.round((now - task.startedAt) / 1000);
      const ok = exit && exit[1] === "0";
      const head = `${ok ? "✔" : "✘"} ${task.who}${task.cmd}  (${exit ? `exit ${exit[1]}` : "stopped following"}, ${secs}s)`;
      const tail = lastLines(body);
      $.ui.toast(tail === "" ? head : `${head}\n${tail}`, { timeoutMs: ok ? 6000 : 10000 });
    }
  }
  if (background.size === 0 && poller) {
    poller.cancel();
    poller = null;
  }
  await paint($);
}

// One pinned status line: a long foreground command wins, else the background commands.
async function paint($) {
  const now = await $.clock.now();
  if (foreground) {
    $.ui.status(`▶ ${foreground.who}${foreground.cmd}  ${Math.round((now - foreground.startedAt) / 1000)}s`);
    return;
  }
  const tasks = [...background.values()];
  if (tasks.length === 0) {
    $.ui.status(undefined);
    return;
  }
  const newest = tasks[tasks.length - 1];
  const age = Math.round((now - newest.startedAt) / 1000);
  const label = tasks.length === 1 ? `⏵ ${newest.who}${newest.cmd}  ${clock(age)}` : `⏵ ${tasks.length} background commands  (${newest.cmd}  ${clock(age)})`;
  $.ui.status(newest.last === "" ? label : `${label}  │ ${newest.last}`);
}

function clock(s) {
  return s >= 3600 ? `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, "0")}m` : `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

function oneLine(text, max) {
  const flat = text.replace(/\s+/g, " ").trim();
  return flat.length > max ? `${flat.slice(0, max - 1)}…` : flat;
}

function lastLines(text) {
  const clean = text.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "");
  const lines = clean.split("\n").map((l) => l.trimEnd()).filter((l) => l !== "");
  return lines.slice(-TAIL_LINES).map((l) => (l.length > LINE_WIDTH ? `${l.slice(0, LINE_WIDTH - 1)}…` : l)).join("\n");
}
