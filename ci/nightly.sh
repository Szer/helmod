#!/usr/bin/env bash
set -euo pipefail
dir=${1:?tested artifact directory required}
[[ $GITHUB_EVENT_NAME == push && $GITHUB_REF == refs/heads/fork && $(git rev-parse HEAD) == "$GITHUB_SHA" ]]
(cd "$dir" && sha256sum -c SHA256SUMS)
version=$(jq -er .version src/info.json)
filename="helmod-fork_${version}.zip"
archive="$dir/$filename"
unzip -p "$archive" "helmod-fork_${version}/info.json" | cmp - src/info.json
digest=$(sha256sum "$archive" | cut -d' ' -f1)
previous=$(git ls-remote origin refs/tags/nightly | cut -f1)
if [[ -n $previous && $previous != "$GITHUB_SHA" ]]; then
  git fetch -q origin refs/tags/nightly
  if git merge-base --is-ancestor "$GITHUB_SHA" FETCH_HEAD; then
    echo 'A newer tested build is already available.'
    exit 0
  fi
  git merge-base --is-ancestor FETCH_HEAD "$GITHUB_SHA" || { echo 'Nightly history diverged'; exit 1; }
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$archive" "$work/helmod-fork-nightly.zip"
pending=$(ci/semver.sh notes)
cat > "$work/body" <<NOTES
Test build from [${GITHUB_SHA:0:7}](https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA) · [passing workflow](https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)

Download the attached ZIP, rename it to **$filename**, and install it in a separate Factorio test profile. Use a copy of your save.

SHA-256: \`$digest\`

Pending player-facing changes since the last portal version:

${pending:-No player-facing changes.}
NOTES

git push --force-with-lease="refs/tags/nightly:$previous" origin "$GITHUB_SHA:refs/tags/nightly"
if gh release view nightly --json tagName >/dev/null 2>&1; then
  gh release upload nightly "$work/helmod-fork-nightly.zip" --clobber
  gh release edit nightly --prerelease --latest=false --title 'Nightly test build' --notes-file "$work/body"
else
  gh release create nightly "$work/helmod-fork-nightly.zip" --verify-tag --prerelease --latest=false \
    --title 'Nightly test build' --notes-file "$work/body"
fi
gh release download nightly --pattern helmod-fork-nightly.zip --dir "$work/verify"
cmp "$archive" "$work/verify/helmod-fork-nightly.zip"
