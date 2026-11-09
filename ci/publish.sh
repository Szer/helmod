#!/usr/bin/env bash
set -euo pipefail
: "${FACTORIO_APIKEY:?Configure the FACTORIO_APIKEY Actions secret}"
dir=${1:?verified artifact directory required}
name=$(jq -er .name src/info.json)
version=$(jq -er .version src/info.json)
[[ $name == helmod-fork && ${GITHUB_REF_TYPE:-} == tag && $GITHUB_REF_NAME == "$name-$version" ]]
archive="$dir/${name}_${version}.zip"
(cd "$dir" && sha256sum -c SHA256SUMS)
digest=$(sha1sum "$archive" | cut -d' ' -f1)
api=https://mods.factorio.com/api
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
lookup() {
  curl -sS --retry 2 -H 'Cache-Control: no-cache' -o "$work/details" -w '%{http_code}' "$api/mods/$name/full?t=$(date +%s%N)"
}
release_hash() {
  jq -r --arg version "$version" '.releases[] | select(.version == $version) | .sha1' "$work/details"
}
sync_description() {
  local summary
  summary=$(jq -er .description src/info.json)
  if jq -e --arg summary "$summary" --rawfile body portal-description.md \
      '.summary == $summary and ((.description // "") | rtrimstr("\n")) == ($body | rtrimstr("\n"))' "$work/details" >/dev/null; then
    return
  fi
  curl -fsS --retry 2 -H "Authorization: Bearer $FACTORIO_APIKEY" -F "mod=$name" \
    --form-string "summary=$summary" -F 'description=<portal-description.md' \
    "$api/v2/mods/edit_details" -o "$work/edit"
  jq -e '.success == true' "$work/edit" >/dev/null
}
status=$(lookup)
case "$status" in
  404) endpoint=init_publish ;;
  200)
    existing=$(release_hash)
    if [[ -n $existing ]]; then
      [[ $existing == "$digest" ]] || { echo "Version exists with a different hash; refusing to replace it"; exit 1; }
      echo "Identical release is already published."
      sync_description
      exit 0
    fi
    endpoint=releases/init_upload ;;
  *) echo "Portal lookup failed: HTTP $status"; exit 1 ;;
esac
curl -fsS --retry 2 -H "Authorization: Bearer $FACTORIO_APIKEY" -F "mod=$name" "$api/v2/mods/$endpoint" -o "$work/init"
url=$(jq -er '.upload_url' "$work/init")
[[ $url =~ ^https://([a-zA-Z0-9-]+\.)*factorio\.com/ ]] || { echo "Unexpected upload destination"; exit 1; }
fields=()
if [[ $endpoint == init_publish ]]; then
  fields=(-F 'description=<portal-description.md' -F category=utilities -F license=default_mit -F 'source_url=https://github.com/Szer/helmod/tree/fork')
fi
# The upload is retried by rerunning the job, after checking for the published hash.
curl -fsS -F "file=@$archive;type=application/zip" "${fields[@]}" "$url" -o "$work/result"
jq -e '.success == true' "$work/result" >/dev/null
for delay in 1 2 4 8 16; do
  if [[ $(lookup) == 200 && $(release_hash) == "$digest" ]]; then
    sync_description
    echo "Verified https://mods.factorio.com/mod/$name version $version ($digest)"
    exit 0
  fi
  sleep "$delay"
done
echo "Upload acknowledged; could not verify portal release hash."
exit 1
