#!/usr/bin/env bash
# Exercise the portal protocol without network access or a publish credential.
set -euo pipefail
root=$(pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
mkdir bin src package
cp "$root/src/info.json" src/
cp "$root/portal-description.md" .
version=$(jq -r .version src/info.json)
archive="helmod-fork_${version}.zip"
echo 'test artifact' > "package/$archive"
(cd package && sha256sum "$archive" > SHA256SUMS)
export EXPECTED_SHA=$(sha1sum "package/$archive" | cut -d' ' -f1)
export GITHUB_REF_TYPE=tag GITHUB_REF_NAME="helmod-fork-$version" FACTORIO_APIKEY=test-only
export VERSION="$version" STATE="$work/state"
export PATH="$work/bin:$PATH"
cat > bin/curl <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
auth=false has_file=false has_description=false has_summary=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    -F) case "$2" in file=@*) has_file=true;; description=*) has_description=true;; esac; shift 2 ;;
    --form-string) [[ $2 == "summary=$(jq -r .description src/info.json)" ]]; has_summary=true; shift 2 ;;
    -H) if [[ $2 == 'Authorization: Bearer test-only' ]]; then auth=true; fi; shift 2 ;;
    --retry|-w) shift 2 ;;
    https://*) url=$1; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  https://mods.factorio.com/api/mods/*)
    [[ $auth == false ]]
    if [[ ! -e "$STATE/uploaded" && $CASE == new ]]; then echo -n 404; exit; fi
    echo -n 200
    if [[ ! -e "$STATE/uploaded" && $CASE != retry && $CASE != conflict ]]; then
      echo '{"releases":[]}' > "$out"
    else
      hash=$EXPECTED_SHA
      if [[ $CASE == conflict || $CASE == bad-hash ]]; then hash=different; fi
      jq -n --arg v "$VERSION" --arg h "$hash" '{releases:[{version:$v,sha1:$h}]}' > "$out"
    fi ;;
  https://mods.factorio.com/api/v2/mods/edit_details)
    [[ $auth == true && $has_description == true && $has_summary == true && $has_file == false ]]
    touch "$STATE/edited"
    echo '{"success":true}' > "$out" ;;
  https://mods.factorio.com/api/v2/mods/*)
    [[ $auth == true ]]
    printf '%s' "$url" > "$STATE/init"
    if [[ $CASE == foreign-url ]]; then
      echo '{"upload_url":"https://example.org/upload"}' > "$out"
    else
      echo '{"upload_url":"https://mods.factorio.com/test-upload"}' > "$out"
    fi ;;
  https://mods.factorio.com/test-upload)
    [[ $auth == false && $has_file == true ]]
    if [[ $CASE == new ]]; then [[ $has_description == true ]]; else [[ $has_description == false ]]; fi
    touch "$STATE/uploaded"
    echo '{"success":true}' > "$out" ;;
  *) echo 'Unexpected destination' >&2; exit 2 ;;
esac
MOCK
chmod +x bin/curl
printf '#!/bin/sh\nexit 0\n' > bin/sleep
chmod +x bin/sleep
for CASE in new next retry conflict bad-hash foreign-url; do
  export CASE STATE="$work/$CASE"
  mkdir "$STATE"
  case "$CASE" in
    new|next)
      "$root/ci/publish.sh" package
      test -e "$STATE/edited"
      test -e "$STATE/uploaded"
      endpoint=init_publish
      if [[ $CASE == next ]]; then endpoint=releases/init_upload; fi
      grep -Fxq "https://mods.factorio.com/api/v2/mods/$endpoint" "$STATE/init" ;;
    retry)
      "$root/ci/publish.sh" package
      test -e "$STATE/edited"
      test ! -e "$STATE/init" ;;
    *)
      if "$root/ci/publish.sh" package; then echo "Unexpected success: $CASE"; exit 1; fi
      if [[ $CASE != bad-hash ]]; then test ! -e "$STATE/uploaded"; fi ;;
  esac
done
echo 'Portal protocol tests passed.'
