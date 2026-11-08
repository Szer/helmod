#!/usr/bin/env bash
set -euo pipefail
git fetch --quiet origin refs/heads/fork:refs/remotes/origin/fork --tags
remote_sha=$(git rev-parse origin/fork)
if [[ $remote_sha != "$GITHUB_SHA" ]]; then
  # Recover if a previous attempt pushed the release but the dispatch failed.
  if [[ $(git rev-parse origin/fork^) == "$GITHUB_SHA" ]]; then
    tag=$(git tag --points-at origin/fork --list 'helmod-fork-*')
    if [[ -n $tag && -z $(gh run list --workflow fork.yml --branch "$tag" --limit 1 --json databaseId --jq '.[].databaseId') ]]; then
      gh workflow run fork.yml --ref "$tag"
    fi
  fi
  echo 'The fork has advanced; this check will not push a stale release.'
  exit 0
fi
tag=$(ci/semver.sh plan)
if [[ -z $tag ]]; then echo 'No player-facing changes to release.'; exit 0; fi
ci/semver.sh prepare
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add -- src/info.json src/changelog.txt
git diff --cached --name-status
git diff --cached --check
git commit -m "chore(release): Publish ${tag#helmod-fork-}"
git tag "$tag"
GITHUB_REF_TYPE=tag GITHUB_REF_NAME="$tag" ci/semver.sh verify
git push --atomic origin HEAD:refs/heads/fork "refs/tags/$tag"
# A push from GITHUB_TOKEN does not start a push workflow. Explicitly test and publish the tag.
gh workflow run fork.yml --ref "$tag"
