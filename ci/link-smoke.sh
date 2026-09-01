#!/usr/bin/env bash
# Quick link probe: static FFmpeg + libxml2 + dynamic libvpl closure.
# Requires PKG_CONFIG_PATH and PKG_CONFIG=pkg-config --static.
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/smoke.c" <<'EOF'
#include <libavformat/avformat.h>
int smoke(void) { return (int)avformat_version(); }
EOF

gcc -c "$tmp/smoke.c" -o "$tmp/smoke.o" $(pkg-config --cflags libavformat libavutil)

gcc -shared -o "$tmp/avc-link-smoke.dll" "$tmp/smoke.o" \
  $(pkg-config --libs --static libavformat libavutil) \
  $(pkg-config --libs --static libxml-2.0) \
  -Wl,-Bdynamic -lvpl

echo "=== Link smoke OK: $tmp/avc-link-smoke.dll ==="
