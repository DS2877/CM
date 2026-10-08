#!/usr/bin/env bash
# Installs the pinned toolchain (same versions as rokit.toml) into ./.tools/bin.
# Used by CI so the build does not depend on GitHub API rate limits.
set -euo pipefail

ROJO=7.4.4
STYLUA=2.0.2
SELENE=0.28.0
LUNE=0.8.9

BIN="${1:-$PWD/.tools/bin}"
mkdir -p "$BIN"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {
	local name="$1" url="$2"
	curl -fsSL --retry 4 --retry-delay 2 -o "$TMP/$name.zip" "$url"
	unzip -o -q "$TMP/$name.zip" -d "$TMP/$name"
	install -m 0755 "$TMP/$name/$name" "$BIN/$name"
}

fetch rojo "https://github.com/rojo-rbx/rojo/releases/download/v$ROJO/rojo-$ROJO-linux-x86_64.zip"
fetch stylua "https://github.com/JohnnyMorganz/StyLua/releases/download/v$STYLUA/stylua-linux-x86_64.zip"
fetch selene "https://github.com/Kampfkarren/selene/releases/download/$SELENE/selene-$SELENE-linux.zip"
fetch lune "https://github.com/lune-org/lune/releases/download/v$LUNE/lune-$LUNE-linux-x86_64.zip"

echo "$BIN"
