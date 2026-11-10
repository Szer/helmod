#!/usr/bin/env bash
set -euo pipefail
dest=${1:?destination required}
manifest=$(realpath ci/repros.sha256)
base=https://raw.githubusercontent.com/Szer/helmod/182b0ffd8fa7741e532b7b4e4b7507b90a730d65/audit-repros
mkdir -p "$dest"
cd "$dest"
while read -r digest file; do
  mkdir -p "$(dirname "$file")"
  curl -fsSL --retry 3 "$base/$file" -o "$file"
done < "$manifest"
sha256sum -c "$manifest"
