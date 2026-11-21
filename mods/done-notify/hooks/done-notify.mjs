// Done Notify: when the main loop finishes a turn that took at least MIN_SECONDS,
// send a desktop notification, so you can look away while Claude works.
// Linux and WSL: notify-send. macOS: osascript. Windows: a PowerShell toast. A missing tool: nothing happens.
// (The Windows and macOS paths are written to the platform's documented APIs but are not tested on those systems.)

const MIN_SECONDS = 45;

// Windows toast: the text arrives in an environment-free, argument-free way by being limited to a safe
// character set first, so it can never carry script syntax.
const WINDOWS_TOAST =
  "$t=[Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime]::GetTemplateContent('ToastText02');" +
  "$x=$t.GetElementsByTagName('text');" +
  "[void]$x.Item(0).AppendChild($t.CreateTextNode('Claude Code'));" +
  "[void]$x.Item(1).AppendChild($t.CreateTextNode('BODY'));" +
  "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show([Windows.UI.Notifications.ToastNotification]::new($t))";

let platform = null;

// "linux", "macos", "windows" or "wsl", as Claude Code itself reports it (no `uname`, which Windows lacks).
async function detectPlatform($) {
  const info = await $.session.info();
  return info.platform ?? "unknown";
}

export function register(on) {
  on("turn.complete", async ($, e, next) => {
    const result = await next(e);
    if (e.agentId || e.isAborted || e.durationMs < MIN_SECONDS * 1000) {
      return result;
    }
    try {
      if (platform === null) {
        platform = await detectPlatform($);
      }
      const secs = Math.round(e.durationMs / 1000);
      const raw = e.reason === "answer" ? `Finished after ${secs}s` : `Stopped (${e.reason}) after ${secs}s`;
      const body = raw.replace(/[^A-Za-z0-9 ().,:_-]/g, "");   // plain text only, on every platform
      if (platform === "linux" || platform === "wsl") {
        await $.process.run(["notify-send", "-a", "Claude Code", "Claude Code", body], { timeoutMs: 5000 });
      } else if (platform === "macos") {
        // The text goes in as an argument, never spliced into the AppleScript source, so it cannot inject code.
        await $.process.run(["osascript", "-e", "on run argv", "-e", 'display notification (item 1 of argv) with title "Claude Code"', "-e", "end run", body], { timeoutMs: 5000 });
      } else if (platform === "windows") {
        await $.process.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", WINDOWS_TOAST.replace("BODY", body)], { timeoutMs: 8000 });
      }
    } catch {
      // No notifier available: stay quiet.
    }
    return result;
  });
}
