#!/usr/bin/env bash
# Usage: GODOT=/path/to/godot tools/run_tests.sh
# Fails if any check fails OR the engine reports a SCRIPT ERROR (a test that
# crashed mid-way would otherwise look like a pass).
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
OUT="$("$GODOT" --headless --path . -s tests/run_tests.gd 2>&1)"
CODE=$?
echo "$OUT"
if echo "$OUT" | grep -q "SCRIPT ERROR"; then
	echo "RESULT: FAILED (script errors above)"; exit 1
fi
[ $CODE -eq 0 ] && echo "RESULT: OK" || echo "RESULT: FAILED"
exit $CODE
