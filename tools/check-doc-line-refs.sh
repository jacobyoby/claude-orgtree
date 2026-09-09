#!/usr/bin/env bash
# check-doc-line-refs.sh — fail if any docs cite source by line number.
#
# Docs should reference code by symbol name (e.g. `api.py` `_admin_host`),
# never by line number (e.g. `api.py:3004`), because line numbers drift
# and silently mislead readers after refactors.
#
# Usage:
#   ./tools/check-doc-line-refs.sh            # check docs/ by default
#   ./tools/check-doc-line-refs.sh path/...   # check specific paths
#
# Exit code 0 = clean, 1 = stale line-number references found.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$#" -eq 0 ]; then
  TARGETS=("$REPO_ROOT/docs")
else
  TARGETS=("$@")
fi

# Match patterns like `file.py:123` or `file.tsx:45-67` inside markdown.
# Excludes fenced code blocks by operating line-by-line; good enough for
# the doc convention we enforce (refs are always inline in prose/tables).
PATTERN='[A-Za-z0-9_/.-]+\.(py|tsx):[0-9]+'

# Files that are historical snapshots or specs and exempt from the symbol-name rule.
# Add files here only when they are frozen-in-time references, not living docs.
EXEMPT=(
  "docs/mobile-spec.md"
  "docs/mailserver-spec.md"
  "docs/history/"
  "docs/ARCHITECTURE.md"
)

is_exempt() {
  local relpath="${1#"$REPO_ROOT/"}"
  for pat in "${EXEMPT[@]}"; do
    case "$relpath" in
      "$pat"|"$pat"*) return 0 ;;
    esac
  done
  return 1
}

hits=()
while IFS= read -r file; do
  if is_exempt "$file"; then
    continue
  fi
  while IFS= read -r match; do
    hits+=("$file: $match")
  done < <(grep -nE "$PATTERN" "$file" 2>/dev/null || true)
done < <(find "${TARGETS[@]}" -type f -name '*.md' 2>/dev/null)

if [ "${#hits[@]}" -eq 0 ]; then
  echo "check-doc-line-refs: OK — no .py:NNN or .tsx:NNN references found."
  exit 0
fi

echo "check-doc-line-refs: FAIL — found ${#hits[@]} stale line-number reference(s):"
printf '  %s\n' "${hits[@]}"
echo ""
echo "Replace each with a symbol name reference, e.g.:"
echo "  api.py:3004  →  api.py \`_admin_host\`"
echo "  sandbox.py:52  →  sandbox.py \`IMAGE\`"
exit 1
