#!/usr/bin/env bash
# MSYS2 MINGW64 libmpv: Intel QSV (h264_qsv) + AAC + DASH/fMP4.
# Minimal runtime: libmpv-2.dll + libvpl-2.dll + MinGW C++ runtime (optional).
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${MPV_DIST_DIR:-$root_dir/dist/mpv-win-avc-x64}"
flat_dir="$dist_dir/bin"
deps_prefix="${MPV_DEPS_PREFIX:-$root_dir/.deps-prefix}"
jobs="${MPV_JOBS:-$(nproc 2>/dev/null || echo 4)}"
pack_mode="${MPV_PACK_MODE:-minimal}"
use_lto="${MPV_LTO:-true}"
mingw_bin="/mingw64/bin"

pacman -S --needed --noconfirm \
  mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-meson \
  mingw-w64-x86_64-ninja \
  mingw-w64-x86_64-pkgconf \
  mingw-w64-x86_64-cmake \
  mingw-w64-x86_64-nasm \
  mingw-w64-x86_64-libvpl \
  mingw-w64-x86_64-libxml2 \
  git

mkdir -p "$deps_prefix"/{lib/pkgconfig,include,bin}

export PKG_CONFIG_PATH="${deps_prefix}/lib/pkgconfig:${PKG_CONFIG_PATH:-/mingw64/lib/pkgconfig}"

build_shaderc() {
  local mark="$deps_prefix/lib/libshaderc_combined.a"
  [[ -f "$mark" ]] && return 0
  echo "=== Building static shaderc ==="
  local src="$root_dir/.build-deps/shaderc"
  if [[ ! -d "$src/.git" ]]; then
    rm -rf "$src"
    git clone --depth=1 https://github.com/google/shaderc.git "$src"
    (cd "$src" && ./utils/git-sync-deps)
  fi
  cmake -S "$src" -B "$src/build" -G Ninja \
    -DCMAKE_INSTALL_PREFIX="$deps_prefix" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DSHADERC_SKIP_TESTS=ON \
    -DSHADERC_SKIP_EXAMPLES=ON
  ninja -C "$src/build" -j"$jobs" install
}

build_spirv_cross() {
  local mark="$deps_prefix/lib/libspirv-cross-c.a"
  [[ -f "$mark" ]] && return 0
  echo "=== Building static spirv-cross ==="
  local src="$root_dir/.build-deps/SPIRV-Cross"
  if [[ ! -d "$src/.git" ]]; then
    rm -rf "$src"
    git clone --depth=1 https://github.com/KhronosGroup/SPIRV-Cross.git "$src"
  fi
  cmake -S "$src" -B "$src/build" -G Ninja \
    -DCMAKE_INSTALL_PREFIX="$deps_prefix" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSPIRV_CROSS_SHARED=OFF \
    -DSPIRV_CROSS_STATIC=ON \
    -DSPIRV_CROSS_CLI=OFF \
    -DSPIRV_CROSS_ENABLE_TESTS=OFF
  ninja -C "$src/build" -j"$jobs" install
}

fix_deps_pkgconfig() {
  local pcdir="$deps_prefix/lib/pkgconfig"
  mkdir -p "$pcdir"

  # shaderc static install may still emit shaderc_shared in shaderc.pc.
  if [[ -f "$pcdir/shaderc_combined.pc" ]]; then
    cp -f "$pcdir/shaderc_combined.pc" "$pcdir/shaderc.pc"
  elif [[ -f "$pcdir/shaderc.pc" ]]; then
    sed -i 's/shaderc_shared/shaderc_combined/g' "$pcdir/shaderc.pc"
  fi

  # libplacebo + mpv look up spirv-cross-c-shared; static SPIRV-Cross ships spirv-cross-c.pc.
  if [[ -f "$pcdir/spirv-cross-c.pc" ]]; then
    sed 's/^Name:.*/Name: spirv-cross-c-shared/' "$pcdir/spirv-cross-c.pc" \
      >"$pcdir/spirv-cross-c-shared.pc"
  fi

  echo "=== deps pkg-config ==="
  pkg-config --modversion shaderc 2>/dev/null || true
  pkg-config --libs shaderc 2>/dev/null || true
  pkg-config --modversion spirv-cross-c-shared 2>/dev/null || true
  pkg-config --libs spirv-cross-c-shared 2>/dev/null || true
}

build_shaderc
build_spirv_cross
fix_deps_pkgconfig

mkdir -p subprojects
cat >subprojects/ffmpeg.wrap <<'EOF'
[wrap-git]
url = https://gitlab.freedesktop.org/gstreamer/meson-ports/ffmpeg.git
revision = meson-8.1
depth = 1
clone-recursive = true

[provide]
dependency_names = libavcodec, libavdevice, libavfilter, libavformat, libavutil, libswresample, libswscale
program_names = ffmpeg
EOF

meson_args=(
  --wrap-mode=forcefallback
  --force-fallback-for=libplacebo
  -Dbuildtype=release
  -Ddefault_library=shared
  -Dffmpeg:default_library=static
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
  -Dlibplacebo:default_library=static
  -Dlibplacebo:demos=false
  -Dlibplacebo:tests=false
  -Dlibplacebo:vulkan=disabled
  -Dlibplacebo:opengl=disabled
  -Dlibplacebo:d3d11=enabled
  -Dlibplacebo:shaderc=enabled
  -Dlibplacebo:lcms=disabled
  -Dlibplacebo:dovi=disabled
  -Dffmpeg:programs=disabled
  -Dffmpeg:tests=disabled
  -Dffmpeg:avdevice=disabled
  -Dffmpeg:postproc=disabled
  -Dffmpeg:libmfx=disabled
  -Dffmpeg:libvpl=enabled
  -Dffmpeg:libxml2=enabled
  -Dffmpeg:schannel=enabled
  -Dffmpeg:openssl=disabled
  -Dffmpeg:gnutls=disabled
  -Dffmpeg:mbedtls=disabled
  -Dffmpeg:libtls=disabled
  -Dffmpeg:d3d11va=disabled
  -Dffmpeg:d3d12va=disabled
  -Dffmpeg:dxva2=disabled
  -Dffmpeg:amf=disabled
  -Dffmpeg:cuda=disabled
  -Dffmpeg:cuvid=disabled
  -Dffmpeg:nvdec=disabled
  -Dffmpeg:nvenc=disabled
  -Dffmpeg:ffnvcodec=disabled
  -Dffmpeg:vaapi=disabled
  -Dffmpeg:vaapi_win32=disabled
  -Dffmpeg:decoders=disabled
  -Dffmpeg:h264_decoder=disabled
  -Dffmpeg:h264_qsv_decoder=enabled
  -Dffmpeg:aac_decoder=enabled
  -Dffmpeg:demuxers=disabled
  -Dffmpeg:dash_demuxer=enabled
  -Dffmpeg:mov_demuxer=enabled
  -Dffmpeg:aac_demuxer=enabled
  -Dffmpeg:h264_demuxer=enabled
  -Dffmpeg:encoders=disabled
  -Dffmpeg:muxers=disabled
  -Dffmpeg:parsers=disabled
  -Dffmpeg:h264_parser=enabled
  -Dffmpeg:aac_parser=enabled
  -Dffmpeg:bsfs=disabled
  -Dffmpeg:h264_mp4toannexb_bsf=enabled
  -Dffmpeg:aac_adtstoasc_bsf=enabled
  -Dffmpeg:extract_extradata_bsf=enabled
  -Dffmpeg:filters=disabled
  -Dffmpeg:aresample_filter=enabled
  -Dffmpeg:aformat_filter=enabled
  -Dffmpeg:asrc_abuffer_filter=enabled
  -Dffmpeg:asink_abuffer_filter=enabled
  -Dffmpeg:vsrc_buffer_filter=enabled
  -Dffmpeg:vsink_buffer_filter=enabled
  -Dffmpeg:format_filter=enabled
  -Dffmpeg:null_filter=enabled
  -Dffmpeg:scale_filter=enabled
  -Dffmpeg:setpts_filter=enabled
  -Dffmpeg:fps_filter=enabled
  -Dffmpeg:trim_filter=enabled
  -Dffmpeg:copy_filter=enabled
  -Dffmpeg:protocols=disabled
  -Dffmpeg:file_protocol=enabled
  -Dffmpeg:http_protocol=enabled
  -Dffmpeg:https_protocol=enabled
  -Dffmpeg:tcp_protocol=enabled
  -Dffmpeg:tls_protocol=enabled
  -Dffmpeg:hwaccels=disabled
  -Dffmpeg:w32threads=enabled
  -Dffmpeg:pthreads=disabled
  -Dffmpeg:network=enabled
  -Dffmpeg:devices=disabled
  -Dffmpeg:gpl=disabled
  -Dffmpeg:version3=enabled
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

# h264_qsv loads libvpl via dlopen.
copy_mingw_dll libvpl-2.dll

is_allowed_dll() {
  case "$1" in
    libmpv-2.dll|libvpl-2.dll|libgcc_s_seh-1.dll|libssp-0.dll|libstdc++-6.dll|libwinpthread-1.dll)
      return 0 ;;
  esac
  return 1
}

while read -r dep; do
  [[ -n "$dep" && -f "$dep" ]] || continue
  [[ "$dep" == "$mingw_bin/"* ]] || continue
  name="$(basename "$dep")"
  [[ "$name" == "libmpv-2.dll" ]] && continue
  if is_allowed_dll "$name"; then
    [[ -f "$flat_dir/$name" ]] || cp -f "$dep" "$flat_dir/$name"
  elif [[ "$pack_mode" == "minimal" ]]; then
    echo "ERROR: unexpected MinGW dependency: $name ($dep)" >&2
    exit 1
  else
    cp -f "$dep" "$flat_dir/$name"
  fi
done < <(ldd "$flat_dir/libmpv-2.dll" 2>/dev/null | awk '/=>/ {print $3}')

{
  echo "# MPV-Win-AVC runtime manifest"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  total=0
  while IFS= read -r f; do
    sz=$(stat -c%s "$f" 2>/dev/null || wc -c <"$f")
    total=$((total + sz))
    printf '%8d  %s\n' "$sz" "$(basename "$f")"
  done < <(find "$flat_dir" -maxdepth 1 -name '*.dll' | sort)
  echo "--------"
  printf 'total %d bytes (%.2f MiB)\n' "$total" "$(awk "BEGIN {printf \"%.2f\", $total/1024/1024}")"
} >"$flat_dir/MANIFEST.txt"

cp -f etc/mpv-avc-kernel.conf "$dist_dir/config/"
cp -f BUILD_AVC.md "$dist_dir/"

echo "=== Done: $flat_dir ==="
ls -1 "$flat_dir"
cat "$flat_dir/MANIFEST.txt"
