#!/usr/bin/env bash
set -euo pipefail
engine=${1:?Factorio directory required}
archive=${2:?package path required}
repro=${3:?original Helmod save required}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/mods/verify-fork"
cp "$archive" "$work/mods/"
cat > "$work/mods/verify-fork/info.json" <<'JSON'
{"name":"verify-fork","title":"Release check","version":"1.0.0","author":"Szer","factorio_version":"2.1","dependencies":["helmod-fork"]}
JSON
cat > "$work/mods/verify-fork/control.lua" <<'LUA'
script.on_nth_tick(1, function()
    local models = remote.call("helmod_interface", "get_models")
    assert(type(models) == "table" and next(models) ~= nil, "Missing migrated sheets")
    log("PACKAGE MIGRATION PASS")
end)
LUA
printf '[path]\nread-data=%s/data\nwrite-data=%s/user\n' "$engine" "$work" > "$work/config.ini"
args=(--config "$work/config.ini" --mod-directory "$work/mods")
"$engine/bin/x64/factorio" "${args[@]}" --create "$work/test.zip"
"$engine/bin/x64/factorio" "${args[@]}" --benchmark "$repro" --benchmark-ticks 1 | tee "$work/benchmark.log"
grep -Fq 'PACKAGE MIGRATION PASS' "$work/benchmark.log"
