#!/usr/bin/env bash
# Downloads the Godot version the project uses (config/features in project.godot)
# into ~/.cache/everbond-godot and prints the binary path. Does nothing if it is already there.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7}"
DIR="$HOME/.cache/everbond-godot"
BIN="$DIR/Godot_v${VERSION}-stable_linux.x86_64"

if [ ! -x "$BIN" ]; then
	mkdir -p "$DIR"
	curl -sSLf -o "$DIR/godot.zip" \
		"https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
	unzip -qo "$DIR/godot.zip" -d "$DIR"
	rm "$DIR/godot.zip"
fi

echo "$BIN"
