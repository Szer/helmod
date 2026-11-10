#!/usr/bin/env bash
set -euo pipefail
dest=${1:?destination required}
manifest=$(realpath ci/repros.sha256)
base=https://raw.githubusercontent.com/Szer/helmod/59791a9c72ff5aee6100aaf1fd58019ccd90da6c/audit-repros
mkdir -p "$dest"
cd "$dest"
while read -r digest file; do
  mkdir -p "$(dirname "$file")"
  curl -fsSL --retry 3 "$base/$file" -o "$file"
done < "$manifest"
sha256sum -c "$manifest"
