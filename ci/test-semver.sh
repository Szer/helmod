#!/usr/bin/env bash
set -euo pipefail
root=$(pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q -b fork
git config user.name Test
git config user.email test@example.invalid
mkdir src
cp "$root/cliff.toml" .
echo '{"name":"helmod-fork","version":"2.3.9"}' > src/info.json
echo "Version: 2.3.9" > src/changelog.txt
git add -- src/info.json src/changelog.txt cliff.toml
git commit -qm initial
git tag helmod-fork-2.3.9
change() { git commit --allow-empty -qm "$1"; }
plan() { "$root/ci/semver.sh" plan; }
unset GITHUB_REF_TYPE GITHUB_REF_NAME
change 'docs: Update developer instructions'
[[ -z $(plan) ]]
change 'fix: Keep entered quantities after reload (#42)'
[[ $(plan) == helmod-fork-2.3.10 ]]
fix=$(git rev-parse HEAD)
mkdir release-notes
echo 'Release-note: Preserve quantities in saved plans' > "release-notes/$fix.txt"
git add -- "release-notes/$fix.txt"
git commit -qm 'docs: Clarify the pending quantity fix'
git commit --allow-empty -qm 'feat(ui): Show the quality of orbital cargo' -m 'Release-note: See cargo quality in the orbit planner'
[[ $(plan) == helmod-fork-2.4.0 ]]
change 'break: Replace the legacy import format'
change 'ci: Update build tools'
[[ $(plan) == helmod-fork-3.0.0 ]]
"$root/ci/semver.sh" prepare
grep -Fxq '    - Preserve quantities in saved plans' src/changelog.txt
grep -Fxq '  Features:' src/changelog.txt
grep -Fxq '    - See cargo quality in the orbit planner' src/changelog.txt
grep -Fxq '    - Replace the legacy import format' src/changelog.txt
if grep -E 'Keep entered quantities|Show the quality|developer instructions|build tools|#42' src/changelog.txt; then exit 1; fi
git add -- src/info.json src/changelog.txt
git commit -qm 'chore(release): Publish 3.0.0'
git tag helmod-fork-3.0.0
GITHUB_REF_TYPE=tag GITHUB_REF_NAME=helmod-fork-3.0.0 "$root/ci/semver.sh" verify
echo 'wrong release note' >> src/changelog.txt
if GITHUB_REF_TYPE=tag GITHUB_REF_NAME=helmod-fork-3.0.0 "$root/ci/semver.sh" verify >/dev/null; then exit 1; fi
echo 'SemVer policy checks passed.'

# Run the release job against a disposable Git remote; record its workflow dispatch.
git restore -- src/changelog.txt
mkdir -p ci bin
cp "$root/ci/semver.sh" "$root/ci/auto-release.sh" "$root/ci/release-note.sh" ci/
git add -- ci/semver.sh ci/auto-release.sh ci/release-note.sh
git commit -qm 'ci: Install release tools'
git init -q --bare "$tmp/remote.git"
git remote add origin "$tmp/remote.git"
git push -q --tags origin HEAD:fork
cat > bin/gh <<'GH'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'workflow run') printf '%s\n' "$*" >> "$DISPATCH_LOG" ;;
  'run list') exit 0 ;;
  *) exit 2 ;;
esac
GH
chmod +x bin/gh
export PATH="$tmp/bin:$PATH" DISPATCH_LOG="$tmp/dispatch"
export GITHUB_SHA=$(git rev-parse HEAD)
ci/auto-release.sh
test ! -e "$DISPATCH_LOG"
change 'fix: Preserve the selected fuel after loading a save'
git push -q origin HEAD:fork
export GITHUB_SHA=$(git rev-parse HEAD)
ci/auto-release.sh
[[ $(git rev-parse helmod-fork-3.0.1) == "$(git --git-dir="$tmp/remote.git" rev-parse fork)" ]]
grep -Fxq 'workflow run fork.yml --ref helmod-fork-3.0.1' "$DISPATCH_LOG"
ci/auto-release.sh
[[ $(git --git-dir="$tmp/remote.git" rev-parse fork) == "$(git rev-parse helmod-fork-3.0.1)" ]]
echo 'Atomic tag, release commit and dispatch checks passed.'
