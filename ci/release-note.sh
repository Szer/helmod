#!/usr/bin/env bash
# Read a PR or squash body on stdin. Print the note, without its prefix.
set -euo pipefail
mode=${1:?expected required, optional or a PR title}
case "$mode" in
  required|optional) ;;
  *)
    if [[ $mode =~ ^(fix|feat|break)(\([^\)]+\))?: ]]; then mode=required; else exit 0; fi ;;
esac
mapfile -t notes < <(sed -n 's/\r$//; s/^Release-note:[[:blank:]]*//p')
if [[ $mode == optional && ${#notes[@]} == 0 ]]; then exit 0; fi
if [[ ${#notes[@]} != 1 || ! ${notes[0]:-} =~ [^[:space:]] ]]; then
  echo 'Expected exactly one standalone Release-note: line with a player-facing description.' >&2
  exit 1
fi
printf '%s\n' "${notes[0]}"
