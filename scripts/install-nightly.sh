#!/usr/bin/env bash
set -euo pipefail

# Set this to your test profile's mods directory, or override it in the environment.
SAVE_FOLDER="${SAVE_FOLDER:-$HOME/.factorio-nightly/mods}"

mkdir -p -- "$SAVE_FOLDER"
work=$(mktemp -d -- "$SAVE_FOLDER/.nightly-install.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT

api=https://api.github.com/repos/Szer/helmod/releases/tags/nightly
curl -fsSL --retry 3 "$api" -o "$work/release.json"
digest=$(jq -er 'select(.tag_name == "nightly" and .prerelease == true)
  | .assets[] | select(.name == "helmod-fork-nightly.zip") | .digest' "$work/release.json")
[[ $digest =~ ^sha256:([a-f0-9]{64})$ ]] || { echo 'Missing nightly SHA-256' >&2; exit 1; }
curl -fsSL --retry 3 https://github.com/Szer/helmod/releases/download/nightly/helmod-fork-nightly.zip -o "$work/nightly.zip"
printf '%s  %s\n' "${digest#sha256:}" "$work/nightly.zip" | sha256sum --check --status || {
  echo 'Nightly checksum mismatch; nothing installed. Retry if the nightly just changed.' >&2; exit 1;
}
unzip -tq "$work/nightly.zip" >/dev/null
info=$(unzip -Z1 "$work/nightly.zip" | grep -Ex 'helmod-fork_[0-9]+\.[0-9]+\.[0-9]+/info\.json')
version=$(unzip -p "$work/nightly.zip" "$info" | jq -er 'select(.name == "helmod-fork") | .version')
filename="helmod-fork_${version}.zip"
[[ $info == "${filename%.zip}/info.json" ]] || { echo 'Invalid mod metadata' >&2; exit 1; }

target="$SAVE_FOLDER/$filename"
if [[ -f $target ]] && cmp -s -- "$target" "$work/nightly.zip"; then
  printf 'Already installed: %s\n' "$target"
  exit 0
fi
if [[ -e $target || -L $target ]]; then
  backup=$(mktemp -- "$target.backup.XXXXXXXX")
  cp -- "$target" "$backup"
  printf 'Previous ZIP backed up to %s\n' "$backup"
fi
mv -T -- "$work/nightly.zip" "$target"
printf 'Installed: %s\nStart Factorio with --mod-directory "%s" to use this profile.\n' "$target" "$SAVE_FOLDER"
