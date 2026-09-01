# Minimal MSVC libmpv for Bilibili AVC + DASH streaming.
# Video: Intel QSV (h264_qsv via libvpl). Audio: AAC software decode.
# Requires: VS DevShell, meson, ninja, nasm, vcpkg (libvpl + libxml2).
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

$subprojects = "subprojects"
$distDir = "dist/mpv-win-avc-x64"
$vcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { "C:\vcpkg" }

foreach ($tool in @('meson', 'ninja', 'git', 'python')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Missing required tool on PATH: $tool"
    }
}
if (-not (Get-Command nasm -ErrorAction SilentlyContinue)) {
    throw "Missing nasm on PATH (CI: run ci/install-ci-deps.ps1 first)"
}
Write-Host "nasm: $(nasm -v | Select-Object -First 1)"

if (-not (Test-Path $subprojects)) {
    New-Item -Path $subprojects -ItemType Directory | Out-Null
}

function Write-WrapFile {
    param(
        [string]$Path,
        [string]$Url,
        [string]$Revision,
        [string]$Method = "",
        [string[]]$Provides = @()
    )
    $content = @"
[wrap-git]
url = $Url
revision = $Revision
depth = 1
clone-recursive = true
"@
    if ($Method) {
        $content += "`nmethod = $Method"
    }
    if ($Provides.Count -gt 0) {
        $content += "`n[provide]`n$($Provides -join "`n")"
    }
    Set-Content -Path $Path -Value $content -NoNewline
}

# shaderc + spirv-cross: required for mpv d3d11 video output on Windows.
if (-not (Test-Path "$subprojects/shaderc_cmake")) {
    git clone https://github.com/google/shaderc --depth 1 $subprojects/shaderc_cmake
    Set-Content -Path "$subprojects/shaderc_cmake/p.diff" -Value @'
diff --git a/third_party/CMakeLists.txt b/third_party/CMakeLists.txt
index 9e9d8b1..fecab91 100644
--- a/third_party/CMakeLists.txt
+++ b/third_party/CMakeLists.txt
@@ -92,7 +92,11 @@ if (NOT TARGET glslang)
       # Glslang tests are off by default. Turn them on if testing Shaderc.
       set(GLSLANG_TESTS ON)
     endif()
-    set(GLSLANG_ENABLE_INSTALL $<NOT:${SKIP_GLSLANG_INSTALL}>)
+    if (SKIP_GLSLANG_INSTALL)
+      set(GLSLANG_ENABLE_INSTALL OFF)
+    else()
+      set(GLSLANG_ENABLE_INSTALL ON)
+    endif()
     set(ENABLE_HLSL "${SHADERC_ENABLE_HLSL}")
     add_subdirectory(${SHADERC_GLSLANG_DIR} glslang)
   endif()
'@
    git -C $subprojects/shaderc_cmake apply --ignore-whitespace p.diff
}
if (-not (Test-Path "$subprojects/shaderc")) {
    New-Item -Path "$subprojects/shaderc" -ItemType Directory | Out-Null
}
Set-Content -Path "$subprojects/shaderc/meson.build" -Value @"
project('shaderc', 'cpp', version: '2024.1')

python = find_program('python3')
run_command(python, '../shaderc_cmake/utils/git-sync-deps', check: true)
run_command(python,
    '../shaderc_cmake/third_party/spirv-tools/utils/update_build_version.py',
    '../shaderc_cmake/third_party/spirv-tools/CHANGES',
    '../shaderc_cmake/third_party/spirv-tools/build-version.inc',
    check: true)

cmake = import('cmake')
opts = cmake.subproject_options()
opts.add_cmake_defines({
    'CMAKE_MSVC_RUNTIME_LIBRARY': 'MultiThreaded',
    'CMAKE_POLICY_DEFAULT_CMP0091': 'NEW',
    'SHADERC_SKIP_INSTALL': 'ON',
    'SHADERC_SKIP_TESTS': 'ON',
    'SHADERC_SKIP_EXAMPLES': 'ON',
    'SHADERC_SKIP_COPYRIGHT_CHECK': 'ON'
})
shaderc_proj = cmake.subproject('shaderc_cmake', options: opts)
shaderc_dep = declare_dependency(dependencies: [
    shaderc_proj.dependency('shaderc'),
    shaderc_proj.dependency('shaderc_util'),
    shaderc_proj.dependency('SPIRV-Tools-static'),
    shaderc_proj.dependency('SPIRV-Tools-opt'),
    shaderc_proj.dependency('glslang'),
])
meson.override_dependency('shaderc', shaderc_dep)
"@

if (-not (Test-Path "$subprojects/spirv-cross-c-shared")) {
    New-Item -Path "$subprojects/spirv-cross-c-shared" -ItemType Directory | Out-Null
}
Set-Content -Path "$subprojects/spirv-cross-c-shared/meson.build" -Value @"
project('spirv-cross', 'cpp', version: '0.59.0')
cmake = import('cmake')
opts = cmake.subproject_options()
opts.add_cmake_defines({
    'CMAKE_MSVC_RUNTIME_LIBRARY': 'MultiThreaded',
    'CMAKE_POLICY_DEFAULT_CMP0091': 'NEW',
    'SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS': 'ON',
    'SPIRV_CROSS_CLI': 'OFF',
    'SPIRV_CROSS_ENABLE_TESTS': 'OFF',
    'SPIRV_CROSS_ENABLE_MSL': 'OFF',
    'SPIRV_CROSS_ENABLE_CPP': 'OFF',
    'SPIRV_CROSS_ENABLE_REFLECT': 'OFF',
    'SPIRV_CROSS_ENABLE_UTIL': 'OFF',
})
spirv_cross_proj = cmake.subproject('spirv-cross', options: opts)
spirv_cross_c_dep = declare_dependency(dependencies: [
    spirv_cross_proj.dependency('spirv-cross-c'),
    spirv_cross_proj.dependency('spirv-cross-core'),
    spirv_cross_proj.dependency('spirv-cross-glsl'),
    spirv_cross_proj.dependency('spirv-cross-hlsl'),
])
meson.override_dependency('spirv-cross-c-shared', spirv_cross_c_dep)
"@

meson wrap update-db
meson wrap install expat
meson wrap install harfbuzz
meson wrap install libpng
meson wrap install zlib

Write-WrapFile -Path "$subprojects/ffmpeg.wrap" `
    -Url "https://gitlab.freedesktop.org/gstreamer/meson-ports/ffmpeg.git" `
    -Revision "meson-8.1" `
    -Provides @(
        "dependency_names = libavcodec, libavdevice, libavfilter, libavformat, libavutil, libswresample, libswscale"
        "program_names = ffmpeg"
    )
Write-WrapFile -Path "$subprojects/libass.wrap" `
    -Url "https://github.com/libass/libass" `
    -Revision "master"
Write-WrapFile -Path "$subprojects/libplacebo.wrap" `
    -Url "https://code.videolan.org/videolan/libplacebo.git" `
    -Revision "master"
Write-WrapFile -Path "$subprojects/spirv-cross.wrap" `
    -Url "https://github.com/KhronosGroup/SPIRV-Cross" `
    -Revision "main" `
    -Method "cmake"

$pkgConfig = "$vcpkgRoot/installed/x64-windows/tools/pkgconf/pkgconf.exe"
if (-not (Test-Path $pkgConfig)) {
    throw "pkgconf not found: $pkgConfig (install vcpkg pkgconf:x64-windows)"
}
$env:PKG_CONFIG = $pkgConfig
$env:PKG_CONFIG_PATH = @(
    "$vcpkgRoot/installed/x64-windows/lib/pkgconfig"
    "$vcpkgRoot/installed/x64-windows-static/lib/pkgconfig"
) -join ';'

if (Test-Path build) {
    Remove-Item -Recurse -Force build
}

$mesonArgs = @(
    "setup", "build",
    "--wrap-mode=forcefallback",
    "-Ddefault_library=shared",
    "-Dffmpeg:default_library=static",
    "-Dc_args=-march=x86-64-v2",
    "-Dlibmpv=true",
    "-Dcplayer=false",
    "-Dtests=false",
    "-Dgpl=false",
    "-Dlua=disabled",
    "-Djavascript=disabled",
    "-Dsubrandr=disabled",
    "-Dcplugins=disabled",
    "-Dvapoursynth=disabled",
    "-Drubberband=disabled",
    "-Dlcms2=disabled",
    "-Dlibarchive=disabled",
    "-Ddvdnav=disabled",
    "-Dlibbluray=disabled",
    "-Duchardet=disabled",
    "-Dvulkan=disabled",
    "-Damf=disabled",
    "-Dcuda-hwaccel=disabled",
    "-Dcuda-interop=disabled",
    "-Dd3d-hwaccel=disabled",
    "-Dd3d9-hwaccel=disabled",
    "-Dwin32-smtc=disabled",
    "-Dwasapi=enabled",
    "-Djpeg=disabled",
    "-Dd3d11=enabled",
    "-Dshaderc=enabled",
    "-Dspirv-cross=enabled",
    "-Ddrm=disabled",
    "-Dwayland=disabled",
    "-Dx11=disabled",
    "-Dharfbuzz:freetype=enabled",
    "-Dlibass:test=disabled",
    "-Dlibplacebo:demos=false",
    "-Dlibplacebo:tests=false",
    "-Dlibplacebo:vulkan=disabled",
    "-Dlibplacebo:d3d11=enabled",
    "-Dlibplacebo:shaderc=enabled",
    "-Dlibplacebo:lcms=disabled",
    "-Dlibpsl:tests=false",
    "-Dlibjpeg-turbo:tests=disabled",
    "-Dxxhash:inline-all=true",
    "-Dxxhash:cli=false",
    # FFmpeg: aligned with FFmpeg-Win-AVC-DLL configure-avc-dash baseline
    "-Dffmpeg:programs=disabled",
    "-Dffmpeg:tests=disabled",
    "-Dffmpeg:avdevice=disabled",
    "-Dffmpeg:postproc=disabled",
    "-Dffmpeg:libmfx=disabled",
    "-Dffmpeg:libvpl=enabled",
    "-Dffmpeg:libxml2=enabled",
    "-Dffmpeg:schannel=enabled",
    "-Dffmpeg:openssl=disabled",
    "-Dffmpeg:gnutls=disabled",
    "-Dffmpeg:mbedtls=disabled",
    "-Dffmpeg:libtls=disabled",
    "-Dffmpeg:d3d11va=disabled",
    "-Dffmpeg:d3d12va=disabled",
    "-Dffmpeg:dxva2=disabled",
    "-Dffmpeg:amf=disabled",
    "-Dffmpeg:cuda=disabled",
    "-Dffmpeg:cuvid=disabled",
    "-Dffmpeg:nvdec=disabled",
    "-Dffmpeg:nvenc=disabled",
    "-Dffmpeg:ffnvcodec=disabled",
    "-Dffmpeg:vaapi=disabled",
    "-Dffmpeg:vaapi_win32=disabled",
    "-Dffmpeg:decoders=disabled",
    "-Dffmpeg:h264_decoder=disabled",
    "-Dffmpeg:h264_qsv_decoder=enabled",
    "-Dffmpeg:aac_decoder=enabled",
    "-Dffmpeg:demuxers=disabled",
    "-Dffmpeg:dash_demuxer=enabled",
    "-Dffmpeg:mov_demuxer=enabled",
    "-Dffmpeg:aac_demuxer=enabled",
    "-Dffmpeg:h264_demuxer=enabled",
    "-Dffmpeg:encoders=disabled",
    "-Dffmpeg:muxers=disabled",
    "-Dffmpeg:parsers=disabled",
    "-Dffmpeg:h264_parser=enabled",
    "-Dffmpeg:hevc_parser=enabled",
    "-Dffmpeg:aac_parser=enabled",
    "-Dffmpeg:bsfs=disabled",
    "-Dffmpeg:h264_mp4toannexb_bsf=enabled",
    "-Dffmpeg:aac_adtstoasc_bsf=enabled",
    "-Dffmpeg:extract_extradata_bsf=enabled",
    "-Dffmpeg:filters=disabled",
    "-Dffmpeg:aresample_filter=enabled",
    "-Dffmpeg:aformat_filter=enabled",
    "-Dffmpeg:asrc_abuffer_filter=enabled",
    "-Dffmpeg:asink_abuffer_filter=enabled",
    "-Dffmpeg:vsrc_buffer_filter=enabled",
    "-Dffmpeg:vsink_buffer_filter=enabled",
    "-Dffmpeg:format_filter=enabled",
    "-Dffmpeg:null_filter=enabled",
    "-Dffmpeg:scale_filter=enabled",
    "-Dffmpeg:setpts_filter=enabled",
    "-Dffmpeg:fps_filter=enabled",
    "-Dffmpeg:trim_filter=enabled",
    "-Dffmpeg:copy_filter=enabled",
    "-Dffmpeg:protocols=disabled",
    "-Dffmpeg:file_protocol=enabled",
    "-Dffmpeg:http_protocol=enabled",
    "-Dffmpeg:https_protocol=enabled",
    "-Dffmpeg:tcp_protocol=enabled",
    "-Dffmpeg:tls_protocol=enabled",
    "-Dffmpeg:pipe_protocol=enabled",
    "-Dffmpeg:udp_protocol=enabled",
    "-Dffmpeg:dtls_protocol=enabled",
    "-Dffmpeg:hwaccels=disabled",
    "-Dffmpeg:w32threads=enabled",
    "-Dffmpeg:pthreads=disabled",
    "-Dffmpeg:network=enabled",
    "-Dffmpeg:devices=disabled",
    "-Dffmpeg:gpl=disabled",
    "-Dffmpeg:version3=enabled"
)

meson @mesonArgs
ninja -C build libmpv-2.dll

if (Test-Path $distDir) {
    Remove-Item -Recurse -Force $distDir
}
New-Item -Path "$distDir/bin" -ItemType Directory -Force | Out-Null

Copy-Item -Force "build/libmpv-2.dll" "$distDir/bin/"

$libvplDll = Get-ChildItem "$vcpkgRoot/installed/x64-windows/bin/libvpl*.dll" -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $libvplDll) {
    throw "libvpl.dll not found under $vcpkgRoot/installed/x64-windows/bin"
}
Copy-Item -Force $libvplDll.FullName "$distDir/bin/"

New-Item -Path "$distDir/config" -ItemType Directory -Force | Out-Null
Copy-Item -Force "etc/mpv-avc-kernel.conf" "$distDir/config/"
Copy-Item -Force "BUILD_AVC.md" "$distDir/"

Write-Host "=== Build complete ==="
Get-ChildItem "$distDir/bin"
