#!/usr/bin/env bash
set -euo pipefail
mode=${1:?use plan, prepare or verify}
start=HEAD
# Verify a release tag against its predecessor, not against itself.
if [[ $mode == verify && ${GITHUB_REF_TYPE:-} == tag ]]; then start=HEAD^; fi
base=$(git describe --first-parent --abbrev=0 --tags --match 'helmod-fork-[0-9]*' "$start")
[[ $base =~ ^helmod-fork-[0-9]+\.[0-9]+\.[0-9]+$ ]]
args=(--config cliff.toml --no-exec --use-branch-tags)
if [[ $start == 'HEAD^' ]]; then args+=(--ignore-tags "^${GITHUB_REF_NAME//./\\.}$"); fi
if [[ -n ${2:-} ]]; then args+=(--with-commit "$2"); fi
args+=("$base..$start")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git-cliff "${args[@]}" --context > "$tmp/context"
if ! jq -e 'any(.[]; .commits | length > 0)' "$tmp/context" >/dev/null; then
  if [[ $mode == plan ]]; then exit 0; fi
  echo 'No release-bearing commits since the previous tag.' >&2
  exit 1
fi
tag=$(git-cliff "${args[@]}" --bumped-version)
[[ $tag =~ ^helmod-fork-([0-9]+\.[0-9]+\.[0-9]+)$ ]]
version=${BASH_REMATCH[1]}
if [[ $mode == plan ]]; then echo "$tag"; exit 0; fi
# Use a date derived from released changes so checks and retries produce the same notes.
timestamp=$(jq '[.[].commits[].committer.timestamp] | max' "$tmp/context")
day=$(date -u -d "@$timestamp" +%F)
git-cliff "${args[@]}" --bump | sed -e '/./,$!d' -e "s/^Date:.*/Date: $day/" > "$tmp/entry"
cat "$tmp/entry" > "$tmp/changelog"
git show "$base:src/changelog.txt" >> "$tmp/changelog"
case "$mode" in
  prepare)
    jq --arg v "$version" '.version=$v' src/info.json > "$tmp/info"
    cp "$tmp/info" src/info.json
    cp "$tmp/changelog" src/changelog.txt ;;
  verify)
    [[ $(jq -er .version src/info.json) == "$version" ]]
    if [[ ${GITHUB_REF_TYPE:-} == tag ]]; then
      [[ $GITHUB_REF_NAME == "$tag" ]]
      git diff --exit-code HEAD^ HEAD -- . ':!src/info.json' ':!src/changelog.txt'
    fi
    diff -u "$tmp/changelog" src/changelog.txt ;;
  *) echo "Unknown mode: $mode" >&2; exit 2 ;;
esac
