#!/usr/bin/env bash
set -euo pipefail
log=$(mktemp -d)
trap 'rm -rf "$log"' EXIT
# Fail only on the checked module's diagnostics, leaving the inherited GUI outside this gate.
"${LUA_LANGUAGE_SERVER:-lua-language-server}" --check=src/model/launch --checklevel=Warning --logpath="$log" --configpath="$(pwd)/.luarc.json"
