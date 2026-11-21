// Command Toast: shows what shell command is running.
// start: a short toast with the command. While it runs: a status entry with a live timer.
// end: a toast with success or failure, the time, and the last lines of output.
// Claude Code does not stream a Bash command's output to mods, so the output
// appears when the command ends, not line by line while it runs.

const TAIL_LINES = 4;
const LINE_WIDTH = 90;

export function register(on) {
  on("tool.call", { tool: "Bash" }, async ($, e, next) => {
    const cmd = oneLine(String(e.command ?? ""), 70);
    const who = e.agentId ? "[agent] " : "";
    const startedAt = await $.clock.now();
    $.ui.toast(`▶ ${who}${cmd}`, { timeoutMs: 2500 });
    const timer = $.clock.every(1000, async () => {
      const secs = Math.round(((await $.clock.now()) - startedAt) / 1000);
      $.ui.status(`▶ ${who}${cmd}  ${secs}s`);
    });
    let ran;
    try {
      ran = await next(e);
    } finally {
      timer.cancel();
      $.ui.status(undefined);
    }
    if (ran.deny !== undefined) {
      return ran;
    }
    const secs = (((await $.clock.now()) - startedAt) / 1000).toFixed(1);
    if (e.run_in_background) {
      $.ui.toast(`⏵ ${who}${cmd}  (running in the background)`, { timeoutMs: 3500 });
      return ran;
    }
    const failed = ran.isError === true;
    const tail = lastLines(String(ran.text ?? ""));
    const head = `${failed ? "✘" : "✔"} ${who}${cmd}  (${secs}s)`;
    $.ui.toast(tail === "" ? head : `${head}\n${tail}`, { timeoutMs: failed ? 9000 : 5000 });
    return ran;
  });
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
