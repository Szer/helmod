#!/usr/bin/env bash
set -euo pipefail
dest=${1:?destination required}
manifest=$(realpath ci/repros.sha256)
base=https://raw.githubusercontent.com/Szer/helmod/b94614bc39e303d67a37284fc45c820abf7f2f33/audit-repros
mkdir -p "$dest"
cd "$dest"
while read -r digest file; do
  mkdir -p "$(dirname "$file")"
  curl -fsSL --retry 3 "$base/$file" -o "$file"
done < "$manifest"
sha256sum -c "$manifest"
