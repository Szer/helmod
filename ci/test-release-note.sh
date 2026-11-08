#!/usr/bin/env bash
set -euo pipefail
for title in 'fix: Correct quantities' 'feat(ui): Show cargo' 'break: Change imports'; do
  for body in '' 'Release-note:  ' $'Release-note: One\nRelease-note: Two'; do
    if ci/release-note.sh "$title" <<< "$body" >/dev/null 2>&1; then exit 1; fi
  done
  [[ $(ci/release-note.sh "$title" <<< $'Details\r\nRelease-note: Keep intermediate products balanced.\r\n') == 'Keep intermediate products balanced.' ]]
done
ci/release-note.sh 'ci: Update tooling' </dev/null
