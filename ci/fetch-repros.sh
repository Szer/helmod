#!/usr/bin/env bash
set -euo pipefail
dest=${1:?destination required}
manifest=$(realpath ci/repros.sha256)
base=https://raw.githubusercontent.com/Szer/helmod/526d1d7a20eba9e7672eb6ad205bcfff0e5788de/audit-repros
mkdir -p "$dest"
cd "$dest"
while read -r digest file; do
  mkdir -p "$(dirname "$file")"
  curl -fsSL --retry 3 "$base/$file" -o "$file"
done < "$manifest"
sha256sum -c "$manifest"
