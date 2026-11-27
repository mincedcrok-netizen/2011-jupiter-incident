#!/usr/bin/env bash
# Real-window, real-rendering end-to-end runs (Xvfb + software GL on a headless box; on a desktop
# just run the game). Usage: GODOT=/path/to/godot tools/run_e2e.sh [screenshot_dir] [room|ship|all]
#   room = Phase 1/2 harness room    ship = Phase 3 ship walkthrough    all = both (default)
set -uo pipefail
GODOT="${GODOT:-godot}"
OUT="${1:-/tmp/jupiter_e2e}"
WHICH="${2:-all}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
# Software rendering is slow; the ship has far more to draw than the test room, so it runs smaller.
run() {
	local script="$1" dir="$2" res="${3:-1280x720}"
	local LOG
	LOG="$(timeout ${E2E_TIMEOUT:-900} xvfb-run -a -s "-screen 0 ${res}x24" "$GODOT" --path . --resolution "$res" \
		--rendering-driver opengl3 --rendering-method gl_compatibility -s "$script" -- "$dir" 2>&1)"
	local CODE=$?
	echo "$LOG" | grep -E "^(PASS|FAIL|STATS)|checks,|SCRIPT ERROR|Renderer"
	[ $CODE -eq 0 ] && echo "E2E $script: OK (screenshots in $dir)" || { echo "E2E $script: FAILED (exit $CODE)"; return 1; }
}
rc=0
[ "$WHICH" = "room" ] || [ "$WHICH" = "all" ] && { run tests/e2e_rendered.gd "$OUT/room" || rc=1; }
[ "$WHICH" = "ship" ] || [ "$WHICH" = "all" ] && { run tests/e2e_ship.gd "$OUT/ship" 800x450 || rc=1; }
exit $rc
