#!/usr/bin/env bash
set -euo pipefail
tools=${1:?tool directory required}
mkdir -p "$tools/factorio" "$tools/luals"
fetch() {
  local url=$1 digest=$2 dest=$3
  curl -fsSL --retry 3 "$url" -o "$dest"
  echo "$digest  $dest" | sha256sum -c -
}
fetch https://factorio.com/get-download/2.1.24/headless/linux64 c49b66cff90aceff87b30f2973af0df7f51712cb2ee3153e0169d9bed46a964f "$tools/factorio.tar.xz"
tar xJf "$tools/factorio.tar.xz" --strip-components=1 -C "$tools/factorio"
fetch https://github.com/LuaLS/lua-language-server/releases/download/3.19.2/lua-language-server-3.19.2-linux-x64.tar.gz 93ad326b10f6c00911dd8c450fa098332dbd8f9f45d1052f5636a2d54479b947 "$tools/luals.tar.gz"
tar xzf "$tools/luals.tar.gz" -C "$tools/luals"
