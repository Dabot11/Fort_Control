#!/usr/bin/env bash
# Build the current source tree without changing native/iOS settings or caches.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORT_OUTPUT="$PROJECT_DIR/build/web"
if [[ "$#" -ne 0 ]]; then
  echo 'Uso: bash scripts/export_web.sh (salida: build/web; requiere Godot 4.6.3 y su plantilla Web sin hilos)' >&2
  if [[ "$#" -eq 1 && ( "$1" == --help || "$1" == -h ) ]]; then exit 0; fi
  exit 2
fi
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
FORT_VERSION="$("$FORT_GODOT" --version)"
case "$FORT_VERSION" in
  4.6.3.stable.*) ;;
  *) echo "Esta exportación usa Godot 4.6.3 Standard; se encontró: $FORT_VERSION" >&2; exit 1 ;;
esac
command -v python3 >/dev/null 2>&1 || { echo 'Se requiere Python 3 para preparar la exportación.' >&2; exit 127; }
FORT_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/fort-control-web.XXXXXX")"
trap 'rm -rf "$FORT_STAGE"' EXIT
FORT_PROJECT="$FORT_STAGE/project"
FORT_ARTIFACT="$FORT_STAGE/export"
mkdir -p "$FORT_PROJECT" "$FORT_ARTIFACT"

# Copy only game inputs, including uncommitted edits. Native export presets,
# credentials, editor caches and previous builds never enter the Web project.
python3 - "$PROJECT_DIR" "$FORT_PROJECT" <<'PY'
from pathlib import Path
import shutil
import sys

source, destination = map(Path, sys.argv[1:])
for name in ("assets", "resources", "scenes", "scripts"):
    shutil.copytree(source / name, destination / name,
                    ignore=shutil.ignore_patterns(".DS_Store", "__pycache__", "*.log", "*.tmp"))
shutil.copy2(source / "project.godot", destination / "project.godot")
shutil.copy2(source / "tools/web/export_presets.cfg", destination / "export_presets.cfg")
(destination / ".fort-web-staging").touch()
PY

# Godot can report import/script failures with exit code zero.
run_godot() {
  local fort_status=0
  "$FORT_GODOT" "$@" 2>&1 | tee "$FORT_STAGE/godot.log" || fort_status=$?
  if [[ "$fort_status" -ne 0 ]]; then return "$fort_status"; fi
  if grep -Eq 'SCRIPT ERROR:|ERROR:' "$FORT_STAGE/godot.log"; then
    echo 'Godot informó un error; no se publicará esta exportación.' >&2
    return 1
  fi
}
run_godot --headless --path "$FORT_PROJECT" --script res://scripts/prepare_web.gd -- "$FORT_PROJECT/project.godot"

# Commit plus content digest prevents stale assets even for repeated local edits.
FORT_COMMIT="$(git -C "$PROJECT_DIR" rev-parse HEAD)"
FORT_DIRTY=false
if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain --untracked-files=normal)" ]]; then FORT_DIRTY=true; fi
FORT_CONTENT="$(python3 - "$FORT_PROJECT" <<'PY'
from pathlib import Path
import hashlib
import sys

root = Path(sys.argv[1])
digest = hashlib.sha256()
for path in sorted(root.rglob("*")):
    if path.is_file() and ".godot" not in path.relative_to(root).parts:
        digest.update(path.relative_to(root).as_posix().encode() + b"\0")
        digest.update(path.read_bytes())
print(digest.hexdigest())
PY
)"
FORT_BASENAME="fort-${FORT_COMMIT:0:12}-${FORT_CONTENT:0:8}"
run_godot --headless --path "$FORT_PROJECT" --editor --import --quit
run_godot --headless --path "$FORT_PROJECT" --export-release Web "$FORT_ARTIFACT/$FORT_BASENAME.html"
mv "$FORT_ARTIFACT/$FORT_BASENAME.html" "$FORT_ARTIFACT/index.html"
python3 - "$FORT_ARTIFACT" "$FORT_BASENAME" "$FORT_COMMIT" "$FORT_CONTENT" "$FORT_DIRTY" "$FORT_VERSION" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json
import sys

output = Path(sys.argv[1])
basename, commit, content_digest, dirty, engine = sys.argv[2:]
for name in ("index.html", f"{basename}.js", f"{basename}.wasm", f"{basename}.pck"):
    path = output / name
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"Exportación incompleta: {name}")
metadata = {
    "commit": commit,
    "content_sha256": content_digest,
    "dirty": dirty == "true",
    "godot": engine,
    "built_at": datetime.now(timezone.utc).isoformat(),
    "asset_prefix": basename,
}
(output / "version.json").write_text(json.dumps(metadata, indent=2) + "\n")
(output / ".nojekyll").touch()
PY

# Replace only the generated directory, after all validation has succeeded.
mkdir -p "$PROJECT_DIR/build"
if [[ -L "$PROJECT_DIR/build" || -L "$FORT_OUTPUT" ]]; then
  echo 'La carpeta build/web no puede ser un enlace simbólico.' >&2
  exit 1
fi
rm -rf "$FORT_OUTPUT"
mv "$FORT_ARTIFACT" "$FORT_OUTPUT"
printf 'Web lista: %s/index.html\nCommit: %s\n' "$FORT_OUTPUT" "$FORT_COMMIT"
