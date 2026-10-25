#!/usr/bin/env bash
# Compatible with the stock Bash in macOS and Linux. GODOT_BIN may contain spaces.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORT_RUN_GAMEPLAY=false
for fort_argument in "$@"; do
  case "$fort_argument" in
    --gameplay) FORT_RUN_GAMEPLAY=true ;;
    --help|-h)
      echo 'Uso: bash scripts/run_tests.sh [--gameplay]'
      echo '--gameplay añade tres partidas con combate real para verificar el balance.'
      exit 0
      ;;
    *) echo "Argumento desconocido: $fort_argument" >&2; exit 2 ;;
  esac
done
if [[ -n "${GODOT_BIN:-}" ]]; then
  FORT_GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  FORT_GODOT="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  FORT_GODOT="$(command -v godot4)"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  FORT_GODOT=/Applications/Godot.app/Contents/MacOS/Godot
else
  echo 'Godot no encontrado. Define GODOT_BIN=/ruta/al/ejecutable/Godot.' >&2
  exit 127
fi
# Godot can print a script error yet exit zero, so validate both the status and log.
FORT_TEST_LOG="$(mktemp -t fort-control-tests.XXXXXX)"
trap 'rm -f "$FORT_TEST_LOG"' EXIT
run_godot() {
  local fort_status=0
  "$FORT_GODOT" "$@" 2>&1 | tee "$FORT_TEST_LOG" || fort_status=$?
  if [[ "$fort_status" -ne 0 ]]; then
    return "$fort_status"
  fi
  if grep -Eq 'SCRIPT ERROR:|ERROR:' "$FORT_TEST_LOG"; then
    echo 'Godot informó un error; la verificación falla aunque devolviera código 0.' >&2
    return 1
  fi
}
run_godot --headless --path "$PROJECT_DIR" --editor --import --quit
run_godot --headless --path "$PROJECT_DIR" --script res://tests/test_runner.gd
run_godot --headless --path "$PROJECT_DIR" --script res://tests/test_input.gd
run_godot --headless --path "$PROJECT_DIR" --script res://tests/test_polish.gd
if [[ "$FORT_RUN_GAMEPLAY" == true ]]; then
  run_godot --headless --path "$PROJECT_DIR" --script res://tests/test_gameplay.gd -- first_one
  run_godot --headless --path "$PROJECT_DIR" --script res://tests/test_gameplay.gd -- strategy
  run_godot --headless --path "$PROJECT_DIR" --script res://tests/test_gameplay.gd -- strategy_perfect
fi
