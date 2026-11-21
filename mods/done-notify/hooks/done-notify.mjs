// Done Notify: when the main loop finishes a turn that took at least MIN_SECONDS,
// send a desktop notification, so you can look away while Claude works.
// Linux: notify-send. macOS: osascript. Anything else, or a missing tool: nothing happens.

const MIN_SECONDS = 45;

let platform = null;

export function register(on) {
  on("turn.complete", async ($, e, next) => {
    const result = await next(e);
    if (e.agentId || e.isAborted || e.durationMs < MIN_SECONDS * 1000) {
      return result;
    }
    try {
      if (platform === null) {
        const uname = await $.process.run(["uname", "-s"], { timeoutMs: 3000 });
        platform = uname.stdout.trim();
      }
      const secs = Math.round(e.durationMs / 1000);
      const body = e.reason === "answer" ? `Finished after ${secs}s` : `Stopped (${e.reason}) after ${secs}s`;
      if (platform === "Linux") {
        await $.process.run(["notify-send", "-a", "Claude Code", "Claude Code", body], { timeoutMs: 5000 });
      } else if (platform === "Darwin") {
        // The text goes in as an argument, never spliced into the AppleScript source, so it cannot inject code.
        await $.process.run(["osascript", "-e", "on run argv", "-e", 'display notification (item 1 of argv) with title "Claude Code"', "-e", "end run", body], { timeoutMs: 5000 });
      }
    } catch {
      // No notifier available: stay quiet.
    }
    return result;
  });
}
