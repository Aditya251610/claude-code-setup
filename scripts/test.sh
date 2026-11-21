#!/usr/bin/env bash
# Runs every mod's tests, then validates each plugin and the marketplace. Exit status is non-zero on any failure.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
fail=0
for dir in mods/*/; do
  name="$(basename "$dir")"
  if ls "$dir"*.test.ts >/dev/null 2>&1; then
    printf '%-16s tests     ' "$name"
    out="$(cd "$dir" && claude plugin test . 2>&1)" && echo "ok" || { echo "FAILED"; echo "$out" | tail -15; fail=1; }
  fi
  printf '%-16s validate  ' "$name"
  claude plugin validate "$dir" >/dev/null 2>&1 && echo "ok" || { echo "FAILED"; fail=1; }
done
printf '%-16s validate  ' marketplace
claude plugin validate . >/dev/null 2>&1 && echo "ok" || { echo "FAILED"; fail=1; }
bash -n install.sh && bash -n uninstall.sh && echo "shell scripts parse" || fail=1
exit $fail
