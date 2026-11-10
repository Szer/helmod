#!/usr/bin/env bash
set -euo pipefail
dest=${1:?destination required}
manifest=$(realpath ci/repros.sha256)
base=https://raw.githubusercontent.com/Szer/helmod/52eaece9271d0d0f4b43278d83ad6302e24fb22a/audit-repros
mkdir -p "$dest"
cd "$dest"
while read -r digest file; do
  mkdir -p "$(dirname "$file")"
  curl -fsSL --retry 3 "$base/$file" -o "$file"
done < "$manifest"
sha256sum -c "$manifest"
