#!/usr/bin/env bash
# Two-process persistence check + negative control. Usage: GODOT=/path/to/godot tools/restart_check.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
run() { timeout 90 "$GODOT" --headless --path . -s tests/restart_persistence.gd -- "$1" 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR"; return "${PIPESTATUS[0]}"; }
echo "== process 1: write settings, key binding, save"; run write; w=$?
echo "== process 2: brand-new process reads them back"; run verify; v=$?
echo "== process 3 (negative control): data was cleaned up, so this MUST fail"; run verify >/dev/null; n=$?
echo "exit codes: write=$w verify=$v negative_control=$n"
if [ $w -eq 0 ] && [ $v -eq 0 ] && [ $n -eq 1 ]; then echo "RESTART CHECK: OK"; else echo "RESTART CHECK: FAILED"; exit 1; fi
