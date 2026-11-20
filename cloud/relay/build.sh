#!/bin/sh
set -eu

cd "$(dirname "$0")"
bindgen_version=$(awk '/^name = "wasm-bindgen"$/ { getline; gsub(/"/, "", $3); print $3; exit }' Cargo.lock)
if [ "$(wasm-bindgen --version 2>/dev/null || true)" != "wasm-bindgen $bindgen_version" ]; then
    printf 'Install wasm-bindgen-cli %s to match Cargo.lock.\n' "$bindgen_version" >&2
    exit 1
fi

cargo build --locked --release --target wasm32-unknown-unknown
wasm-bindgen --target web --no-typescript --out-name relay --out-dir build \
    "${CARGO_TARGET_DIR:-target}/wasm32-unknown-unknown/release/opscode_relay.wasm"
cp src/entry.mjs build/entry.mjs
