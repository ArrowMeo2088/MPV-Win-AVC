#!/usr/bin/env bash
# MSYS2 MINGW64 libmpv: Intel QSV (h264_qsv) + AAC + DASH/fMP4.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${MPV_DIST_DIR:-$root_dir/dist/mpv-win-avc-x64}"
flat_dir="$dist_dir/bin"
jobs="${MPV_JOBS:-$(nproc 2>/dev/null || echo 4)}"

pacman -S --needed --noconfirm \
  mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-meson \
  mingw-w64-x86_64-ninja \
  mingw-w64-x86_64-pkgconf \
  mingw-w64-x86_64-nasm \
  mingw-w64-x86_64-libass \
  mingw-w64-x86_64-libplacebo \
  mingw-w64-x86_64-shaderc \
  mingw-w64-x86_64-spirv-cross \
  mingw-w64-x86_64-libvpl \
  mingw-w64-x86_64-libxml2 \
  git

# Prefer static archives so libass/libplacebo/font stack link into libmpv-2.dll.
export PKG_CONFIG="pkg-config --static"

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

rm -rf build
meson setup build \
  --wrap-mode=forcefallback \
  -Ddefault_library=shared \
  -Dffmpeg:default_library=static \
  -Dc_args=-march=x86-64-v2 \
  -Dlibmpv=true \
  -Dcplayer=false \
  -Dtests=false \
  -Dgpl=false \
  -Dlua=disabled \
  -Djavascript=disabled \
  -Dsubrandr=disabled \
  -Dcplugins=disabled \
  -Dvapoursynth=disabled \
  -Drubberband=disabled \
  -Dlcms2=disabled \
  -Dlibarchive=disabled \
  -Ddvdnav=disabled \
  -Dlibbluray=disabled \
  -Duchardet=disabled \
  -Dvulkan=disabled \
  -Damf=disabled \
  -Dcuda-hwaccel=disabled \
  -Dcuda-interop=disabled \
  -Dd3d-hwaccel=disabled \
  -Dd3d9-hwaccel=disabled \
  -Dwin32-smtc=disabled \
  -Dwasapi=enabled \
  -Djpeg=disabled \
  -Dd3d11=enabled \
  -Dshaderc=enabled \
  -Dspirv-cross=enabled \
  -Ddrm=disabled \
  -Dwayland=disabled \
  -Dx11=disabled \
  -Dlibplacebo:default_library=static \
  -Dlibplacebo:demos=false \
  -Dlibplacebo:tests=false \
  -Dlibplacebo:vulkan=disabled \
  -Dlibplacebo:d3d11=enabled \
  -Dlibplacebo:shaderc=enabled \
  -Dlibplacebo:lcms=disabled \
  -Dlibplacebo:dovi=disabled \
  -Dffmpeg:programs=disabled \
  -Dffmpeg:tests=disabled \
  -Dffmpeg:avdevice=disabled \
  -Dffmpeg:postproc=disabled \
  -Dffmpeg:libmfx=disabled \
  -Dffmpeg:libvpl=enabled \
  -Dffmpeg:libxml2=enabled \
  -Dffmpeg:schannel=enabled \
  -Dffmpeg:openssl=disabled \
  -Dffmpeg:gnutls=disabled \
  -Dffmpeg:mbedtls=disabled \
  -Dffmpeg:libtls=disabled \
  -Dffmpeg:d3d11va=disabled \
  -Dffmpeg:d3d12va=disabled \
  -Dffmpeg:dxva2=disabled \
  -Dffmpeg:amf=disabled \
  -Dffmpeg:cuda=disabled \
  -Dffmpeg:cuvid=disabled \
  -Dffmpeg:nvdec=disabled \
  -Dffmpeg:nvenc=disabled \
  -Dffmpeg:ffnvcodec=disabled \
  -Dffmpeg:vaapi=disabled \
  -Dffmpeg:vaapi_win32=disabled \
  -Dffmpeg:decoders=disabled \
  -Dffmpeg:h264_decoder=disabled \
  -Dffmpeg:h264_qsv_decoder=enabled \
  -Dffmpeg:aac_decoder=enabled \
  -Dffmpeg:demuxers=disabled \
  -Dffmpeg:dash_demuxer=enabled \
  -Dffmpeg:mov_demuxer=enabled \
  -Dffmpeg:aac_demuxer=enabled \
  -Dffmpeg:h264_demuxer=enabled \
  -Dffmpeg:encoders=disabled \
  -Dffmpeg:muxers=disabled \
  -Dffmpeg:parsers=disabled \
  -Dffmpeg:h264_parser=enabled \
  -Dffmpeg:hevc_parser=enabled \
  -Dffmpeg:aac_parser=enabled \
  -Dffmpeg:bsfs=disabled \
  -Dffmpeg:h264_mp4toannexb_bsf=enabled \
  -Dffmpeg:aac_adtstoasc_bsf=enabled \
  -Dffmpeg:extract_extradata_bsf=enabled \
  -Dffmpeg:filters=disabled \
  -Dffmpeg:aresample_filter=enabled \
  -Dffmpeg:aformat_filter=enabled \
  -Dffmpeg:asrc_abuffer_filter=enabled \
  -Dffmpeg:asink_abuffer_filter=enabled \
  -Dffmpeg:vsrc_buffer_filter=enabled \
  -Dffmpeg:vsink_buffer_filter=enabled \
  -Dffmpeg:format_filter=enabled \
  -Dffmpeg:null_filter=enabled \
  -Dffmpeg:scale_filter=enabled \
  -Dffmpeg:setpts_filter=enabled \
  -Dffmpeg:fps_filter=enabled \
  -Dffmpeg:trim_filter=enabled \
  -Dffmpeg:copy_filter=enabled \
  -Dffmpeg:protocols=disabled \
  -Dffmpeg:file_protocol=enabled \
  -Dffmpeg:http_protocol=enabled \
  -Dffmpeg:https_protocol=enabled \
  -Dffmpeg:tcp_protocol=enabled \
  -Dffmpeg:tls_protocol=enabled \
  -Dffmpeg:pipe_protocol=enabled \
  -Dffmpeg:udp_protocol=enabled \
  -Dffmpeg:dtls_protocol=enabled \
  -Dffmpeg:hwaccels=disabled \
  -Dffmpeg:w32threads=enabled \
  -Dffmpeg:pthreads=disabled \
  -Dffmpeg:network=enabled \
  -Dffmpeg:devices=disabled \
  -Dffmpeg:gpl=disabled \
  -Dffmpeg:version3=enabled

ninja -C build -j"$jobs" libmpv-2.dll

rm -rf "$dist_dir"
mkdir -p "$flat_dir" "$dist_dir/config"
cp -f build/libmpv-2.dll "$flat_dir/"

# Runtime DLL closure (MinGW prefix only).
declare -A queued=()
queue=()
mingw_bin="/mingw64/bin"

enqueue() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local key
  key="$(basename "$f")"
  [[ -n "${queued[$key]:-}" ]] && return 0
  queued[$key]=1
  queue+=("$f")
}

# h264_qsv loads libvpl via dlopen; ldd does not see it.
for runtime_dll in libvpl-2.dll; do
  src="$mingw_bin/$runtime_dll"
  if [[ ! -f "$src" ]]; then
    echo "ERROR: required runtime DLL missing: $src" >&2
    exit 1
  fi
  cp -f "$src" "$flat_dir/"
  enqueue "$flat_dir/$runtime_dll"
done

enqueue "$flat_dir/libmpv-2.dll"
while ((${#queue[@]} > 0)); do
  current="${queue[0]}"
  queue=("${queue[@]:1}")
  while read -r dep; do
    [[ -n "$dep" && -f "$dep" ]] || continue
    [[ "$dep" == "$mingw_bin/"* ]] || continue
    dest="$flat_dir/$(basename "$dep")"
    [[ -f "$dest" ]] || cp -f "$dep" "$dest"
    enqueue "$dest"
  done < <(ldd "$current" 2>/dev/null | awk '/=>/ {print $3}')
done

cp -f etc/mpv-avc-kernel.conf "$dist_dir/config/"
cp -f BUILD_AVC.md "$dist_dir/"

echo "=== Done: $flat_dir ==="
ls -1 "$flat_dir"
