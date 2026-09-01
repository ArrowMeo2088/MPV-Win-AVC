#!/usr/bin/env bash
# MSYS2 MINGW64 libmpv: Intel QSV (h264_qsv) + AAC + DASH/fMP4.
# Uses FFmpeg-Win-AVC-DLL static prefix via pkg-config (no meson ffmpeg subproject).
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
dist_dir="${MPV_DIST_DIR:-$root_dir/dist/mpv-win-avc-x64}"
flat_dir="$dist_dir/bin"
jobs="${MPV_JOBS:-$(nproc 2>/dev/null || echo 4)}"
pack_mode="${MPV_PACK_MODE:-ldd}"
use_lto="${MPV_LTO:-false}"
mingw_bin="/mingw64/bin"

ffmpeg_src="${FFMPEG_SRC:-$root_dir/../FFmpeg-Win-AVC-DLL}"
ffmpeg_dist="${FFMPEG_DIST_DIR:-$ffmpeg_src/dist/ffmpeg-win-x64-static}"
ffmpeg_prefix="${FFMPEG_PREFIX:-$ffmpeg_dist/prefix}"

pacman -S --needed --noconfirm \
  mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-meson \
  mingw-w64-x86_64-ninja \
  mingw-w64-x86_64-pkgconf \
  mingw-w64-x86_64-libplacebo \
  mingw-w64-x86_64-shaderc \
  mingw-w64-x86_64-spirv-cross \
  mingw-w64-x86_64-libvpl \
  mingw-w64-x86_64-libxml2

if [[ ! -f "$ffmpeg_prefix/lib/pkgconfig/libavcodec.pc" ]]; then
  echo "=== Building FFmpeg from $ffmpeg_src ==="
  FFMPEG_SRC="$ffmpeg_src" \
  FFMPEG_DIST_DIR="$ffmpeg_dist" \
  FFMPEG_PREFIX="$ffmpeg_prefix" \
    bash "$ffmpeg_src/scripts/build-win-mingw-static.sh"
fi

export PKG_CONFIG_PATH="$ffmpeg_prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-/mingw64/lib/pkgconfig}"
export PKG_CONFIG="${PKG_CONFIG:-pkg-config --static}"

echo "=== FFmpeg pkg-config ==="
pkg-config --modversion libavcodec
pkg-config --libs --static libavcodec | head -c 200
echo

rm -f "$root_dir/subprojects/ffmpeg.wrap"

meson_args=(
  --wrap-mode=nofallback
  -Dbuildtype=release
  -Ddefault_library=shared
  -Dc_args=-march=x86-64-v2
  -Dlibmpv=true
  -Dcplayer=false
  -Dtests=false
  -Dgpl=false
  -Diconv=disabled
  -Dlua=disabled
  -Djavascript=disabled
  -Dsubrandr=disabled
  -Dcplugins=disabled
  -Dvapoursynth=disabled
  -Drubberband=disabled
  -Dlcms2=disabled
  -Dlibarchive=disabled
  -Ddvdnav=disabled
  -Dlibbluray=disabled
  -Duchardet=disabled
  -Dvulkan=disabled
  -Damf=disabled
  -Dcuda-hwaccel=disabled
  -Dcuda-interop=disabled
  -Dd3d-hwaccel=disabled
  -Dd3d9-hwaccel=disabled
  -Dwin32-smtc=disabled
  -Dwasapi=enabled
  -Djpeg=disabled
  -Dd3d11=enabled
  -Dshaderc=enabled
  -Dspirv-cross=enabled
  -Ddrm=disabled
  -Dwayland=disabled
  -Dx11=disabled
)

if [[ "$use_lto" == "true" ]]; then
  meson_args+=(-Db_lto=true)
fi

if [[ -d build/meson-private ]]; then
  meson setup build --reconfigure "${meson_args[@]}"
else
  meson setup build "${meson_args[@]}"
fi

ninja -C build -j"$jobs" libmpv-2.dll
strip -s build/libmpv-2.dll

rm -rf "$dist_dir"
mkdir -p "$flat_dir" "$dist_dir/config"
cp -f build/libmpv-2.dll "$flat_dir/"

copy_mingw_dll() {
  local name="$1"
  local src="$mingw_bin/$name"
  if [[ ! -f "$src" ]]; then
    echo "ERROR: required DLL missing: $src" >&2
    exit 1
  fi
  cp -f "$src" "$flat_dir/$name"
}

copy_mingw_dll libvpl-2.dll

is_allowed_dll() {
  case "$1" in
    libmpv-2.dll|libvpl-2.dll|libgcc_s_seh-1.dll|libssp-0.dll|libstdc++-6.dll|libwinpthread-1.dll)
      return 0 ;;
    libshaderc_shared.dll|spirv-cross-c-shared.dll)
      return 0 ;;
  esac
  case "$1" in
    libplacebo-*.dll)
      return 0 ;;
  esac
  return 1
}

while read -r dep; do
  [[ -n "$dep" && -f "$dep" ]] || continue
  [[ "$dep" == "$mingw_bin/"* ]] || continue
  name="$(basename "$dep")"
  [[ "$name" == "libmpv-2.dll" ]] && continue
  if [[ "$pack_mode" == "ldd" ]]; then
    [[ -f "$flat_dir/$name" ]] || cp -f "$dep" "$flat_dir/$name"
  elif is_allowed_dll "$name"; then
    [[ -f "$flat_dir/$name" ]] || cp -f "$dep" "$flat_dir/$name"
  else
    echo "ERROR: unexpected MinGW dependency: $name ($dep)" >&2
    exit 1
  fi
done < <(ldd "$flat_dir/libmpv-2.dll" 2>/dev/null | awk '/=>/ {print $3}')

{
  echo "# MPV-Win-AVC runtime manifest"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# ffmpeg: $(git -C "$ffmpeg_src" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  total=0
  while IFS= read -r f; do
    sz=$(stat -c%s "$f" 2>/dev/null || wc -c <"$f")
    total=$((total + sz))
    printf '%8d  %s\n' "$sz" "$(basename "$f")"
  done < <(find "$flat_dir" -maxdepth 1 -name '*.dll' | sort)
  echo "--------"
  printf 'total %d bytes (%.2f MiB)\n' "$total" "$(awk "BEGIN {printf \"%.2f\", $total/1024/1024}")"
  echo "dll_count $(find "$flat_dir" -maxdepth 1 -name '*.dll' | wc -l)"
} >"$flat_dir/MANIFEST.txt"

cp -f etc/mpv-avc-kernel.conf "$dist_dir/config/"
cp -f BUILD_AVC.md "$dist_dir/"

echo "=== Done: $flat_dir ==="
ls -1 "$flat_dir"
cat "$flat_dir/MANIFEST.txt"
