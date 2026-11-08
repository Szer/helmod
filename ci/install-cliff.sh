#!/usr/bin/env bash
set -euo pipefail
dest=${1:?tool directory required}
mkdir -p "$dest"
name=git-cliff-2.14.2-x86_64-unknown-linux-gnu
curl -fsSL --retry 3 "https://github.com/orhun/git-cliff/releases/download/v2.14.2/$name.tar.gz" -o "$dest/git-cliff.tar.gz"
echo "24f397c733add5390fdceee3a2088588ab0d5f944ce00d34cb7029b888cf2db4  $dest/git-cliff.tar.gz" | sha256sum -c -
tar xzf "$dest/git-cliff.tar.gz" --strip-components=1 -C "$dest" "git-cliff-2.14.2/git-cliff"
