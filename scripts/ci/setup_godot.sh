#!/usr/bin/env bash
# Install the pinned official Linux editor and only the Web template we use.
set -euo pipefail
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'Este instalador de CI requiere Linux x86_64.' >&2
  exit 1
fi
FORT_GODOT_VERSION=4.6.3
FORT_INSTALL="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fort-godot-$FORT_GODOT_VERSION"
# Digests of the files extracted from the verified official release archives.
# Recheck these on every run, including a GitHub Actions cache hit.
FORT_EDITOR_SHA256=f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3
FORT_WEB_SHA256=1446f79dc12f60ce5d244c39fb6628ec298337ca5c4f91a16491feea72aa1bc9
FORT_DOWNLOAD="$(mktemp -d "${TMPDIR:-/tmp}/fort-godot-download.XXXXXX")"
trap 'rm -rf "$FORT_DOWNLOAD"' EXIT
FORT_RELEASE="https://github.com/godotengine/godot-builds/releases/download/$FORT_GODOT_VERSION-stable"
FORT_BINARY="Godot_v$FORT_GODOT_VERSION-stable_linux.x86_64.zip"
FORT_TEMPLATES="Godot_v$FORT_GODOT_VERSION-stable_export_templates.tpz"
download_verified() {
  local fort_file="$1"
  local fort_digest="$2"
  curl --fail --location --retry 3 --output "$FORT_DOWNLOAD/$fort_file" "$FORT_RELEASE/$fort_file"
  printf '%s  %s\n' "$fort_digest" "$FORT_DOWNLOAD/$fort_file" | sha256sum --check --strict
}
verify_file() {
  [[ -f "$1" ]] && printf '%s  %s\n' "$2" "$1" | sha256sum --check --strict
}
mkdir -p "$FORT_INSTALL"
if ! verify_file "$FORT_INSTALL/godot" "$FORT_EDITOR_SHA256"; then
  download_verified "$FORT_BINARY" d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3
  unzip -p "$FORT_DOWNLOAD/$FORT_BINARY" "Godot_v$FORT_GODOT_VERSION-stable_linux.x86_64" > "$FORT_INSTALL/godot"
  verify_file "$FORT_INSTALL/godot" "$FORT_EDITOR_SHA256"
fi
if ! verify_file "$FORT_INSTALL/web_nothreads_release.zip" "$FORT_WEB_SHA256"; then
  download_verified "$FORT_TEMPLATES" 3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8
  unzip -p "$FORT_DOWNLOAD/$FORT_TEMPLATES" templates/web_nothreads_release.zip > "$FORT_INSTALL/web_nothreads_release.zip"
  verify_file "$FORT_INSTALL/web_nothreads_release.zip" "$FORT_WEB_SHA256"
fi
chmod +x "$FORT_INSTALL/godot"
FORT_TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$FORT_GODOT_VERSION.stable"
mkdir -p "$FORT_TEMPLATE_DIR"
cp "$FORT_INSTALL/web_nothreads_release.zip" "$FORT_TEMPLATE_DIR/web_nothreads_release.zip"
"$FORT_INSTALL/godot" --version
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'GODOT_BIN=%s/godot\n' "$FORT_INSTALL" >> "$GITHUB_ENV"
fi
printf 'GODOT_BIN=%s/godot\n' "$FORT_INSTALL"
