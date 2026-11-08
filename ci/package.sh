#!/usr/bin/env bash
set -euo pipefail
dir=${1:?output directory required}
name=$(jq -er .name src/info.json)
version=$(jq -er .version src/info.json)
[[ $name == helmod-fork && $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
if [[ ${GITHUB_REF_TYPE:-} == tag ]]; then
  [[ $GITHUB_REF_NAME == "$name-$version" ]] || { echo "Tag does not match src/info.json"; exit 1; }
fi
mkdir -p "$dir"
prefix="${name}_${version}"
git archive --format=zip --mtime="$(git show -s --format=%cI HEAD)" --prefix="$prefix/" -o "$dir/$prefix.zip" HEAD:src
unzip -tq "$dir/$prefix.zip"
unzip -p "$dir/$prefix.zip" "$prefix/info.json" | cmp - src/info.json
unzip -p "$dir/$prefix.zip" "$prefix/LICENSE" | cmp - src/LICENSE
(cd "$dir" && sha256sum "$prefix.zip" > SHA256SUMS)
