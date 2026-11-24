#!/usr/bin/env bash
# Real-window, real-rendering end-to-end run (uses Xvfb + software GL on a headless box;
# on a desktop just run the game). Usage: GODOT=/path/to/godot tools/run_e2e.sh [screenshot_dir]
set -uo pipefail
GODOT="${GODOT:-godot}"
OUT="${1:-/tmp/jupiter_e2e}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
LOG="$(timeout 240 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
	--rendering-driver opengl3 --rendering-method gl_compatibility \
	-s tests/e2e_rendered.gd -- "$OUT" 2>&1)"
CODE=$?
echo "$LOG" | grep -E "^(PASS|FAIL)|checks,|SCRIPT ERROR|Renderer"
[ $CODE -eq 0 ] && echo "E2E: OK (screenshots in $OUT)" || { echo "E2E: FAILED (exit $CODE)"; exit 1; }
