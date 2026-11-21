// Big Read Guard: refuse a whole-file Read of a huge or generated file, and tell
// the model how to read what it needs instead. A Read that names an offset, a
// limit or pages passes untouched. It fails open: if the size cannot be read, the Read goes ahead.

const MAX_BYTES = 150_000; // about 35k tokens of text
const GENERATED = [
  /(^|\/)node_modules\//,
  /(^|\/)\.venv\//,
  /(^|\/)venv\//,
  /(^|\/)__pycache__\//,
  /(^|\/)target\/(debug|release)\//,
  /\.min\.(js|css)$/,
  /\.map$/,
  /(^|\/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|uv\.lock|Cargo\.lock|go\.sum)$/,
];
const BINARY_OK = /\.(png|jpe?g|gif|webp|pdf|ipynb)$/i; // read by their own tools, not by byte size

export function register(on) {
  on("tool.call", { tool: "Read" }, async ($, e, next) => {
    if (e.offset !== undefined || e.limit !== undefined || e.pages !== undefined) {
      return next(e);
    }
    const path = String(e.file_path ?? "");
    if (GENERATED.some((re) => re.test(path))) {
      return { deny: `Big Read Guard: ${path} is generated or vendored, so reading it whole would waste context. Use Grep for the name or line you need, or Read with offset and limit.` };
    }
    if (BINARY_OK.test(path)) {
      return next(e);
    }
    try {
      const stat = await $.fs.stat(path);
      if (stat.kind === "file" && stat.size > MAX_BYTES) {
        const kb = Math.round(stat.size / 1000);
        return { deny: `Big Read Guard: ${path} is ${kb} KB, too large to read whole. Use Grep to find the part you need, then Read it with offset and limit.` };
      }
    } catch {
      // Size unknown: let the read through.
    }
    return next(e);
  });
}
