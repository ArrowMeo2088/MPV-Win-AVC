#!/usr/bin/env bash
# Link probe: pull dashdec.o from libavformat.a and close libxml2 + dynamic vpl.
# Requires PKG_CONFIG_PATH and PKG_CONFIG=pkg-config --static.
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/smoke.c" <<'EOF'
#include <libavformat/avformat.h>
const AVInputFormat *smoke_dash(void) {
    return av_find_input_format("dash");
}
EOF

gcc -c "$tmp/smoke.c" -o "$tmp/smoke.o" $(pkg-config --cflags libavformat libavutil)

gcc -shared -o "$tmp/avc-link-smoke.dll" "$tmp/smoke.o" \
  -Wl,--whole-archive $(pkg-config --libs --static libavformat) -Wl,--no-whole-archive \
  $(pkg-config --libs --static libavutil) \
  $(pkg-config --libs --static libxml-2.0) \
  -Wl,-Bdynamic -lvpl

echo "=== Link smoke OK: $tmp/avc-link-smoke.dll ==="
