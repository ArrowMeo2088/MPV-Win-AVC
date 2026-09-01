# MPV-Win-AVC 精简构建（MSYS2 MINGW64）

面向 B 站流式播放的 **MinGW libmpv**：Intel QSV（`h264_qsv`）+ AAC 软解 + DASH/fMP4 + HTTPS。

参考：`Ref/ffmpeg-build-win-avc-msys2.yml`（FFmpeg 同款 MSYS2 方案，已验证可行）。

## 功能范围

| 启用 | 禁用 |
|------|------|
| `h264_qsv`（Intel HD 520+ / libvpl） | H.264 软解、NV/AMD/ARC/DXVA |
| AAC 软解 | 弹幕、Lua/JS、C 插件、截图、转码 |
| DASH / mov / fMP4 | mpv CLI（`cplayer=false`） |
| HTTP/HTTPS 流式 | MSVC / vcpkg 构建路径 |

## CI

- Workflow：`.github/workflows/build_avc.yml`
- Runner：`windows-latest` + **MSYS2 MINGW64** + `gcc`/`meson`/`ninja`
- 脚本：`ci/build-avc-msys2.sh`（`pacman` 装依赖 + meson 裁剪 FFmpeg + `libmpv-2.dll`）

## 本地构建（MSYS2 MINGW64 终端）

```bash
cd /path/to/MPV-Win-AVC
bash ./ci/build-avc-msys2.sh
```

产出：`dist/mpv-win-avc-x64/bin/`（`libmpv-2.dll` + `libvpl-2.dll` + MinGW/渲染运行时依赖）。

打包说明：

- `libvpl-2.dll` 由 FFmpeg `h264_qsv` 在运行时 `dlopen`，脚本会**显式复制**（`ldd` 无法自动发现）。
- `libass` / `libplacebo` 及其字体栈通过 `static: true` + `PKG_CONFIG=pkg-config --static` **静态链入** `libmpv-2.dll`，避免 `libass-9.dll`、`libfreetype`、`libfontconfig` 等字幕/OSD 运行时 DLL。
- `libplacebo:dovi=disabled` 去掉 `libdovi.dll` 依赖。

预期运行时 DLL（约 7 个，视 MSYS2 版本略有出入）：

| DLL | 用途 |
|-----|------|
| `libmpv-2.dll` | libmpv + 静态 FFmpeg / libass / libplacebo |
| `libvpl-2.dll` | Intel QSV |
| `libshaderc_shared.dll` | D3D11 着色器编译 |
| `libspirv-cross-c-shared.dll` | SPIR-V 转换 |
| `libgcc_s_seh-1.dll` | MinGW 运行时 |
| `libstdc++-6.dll` | MinGW 运行时 |
| `libwinpthread-1.dll` | MinGW 运行时 |

## mpv-kernel 初始化

默认解码模式：**`PreferDecodeType.Qsv`**（`vo=gpu` + `d3d11` + `hwdec=no` → FFmpeg `h264_qsv`）。

```csharp
MpvNative.Initialize(Path.Combine(AppContext.BaseDirectory, "libmpv-2.dll"));
await client.SetVideoOutputAsync(VideoOutputType.Gpu);
await client.SetGpuApiAsync(GpuApiType.D3D11);
await client.SetGpuContextAsync(GpuContextType.D3D11);
await client.SetHardwareDecodeAsync(HardwareDecodeType.None); // lavc → h264_qsv
```

或加载 `config/mpv-avc-kernel.conf`。

## 脚本

| 文件 | 作用 |
|------|------|
| `ci/build-avc-msys2.sh` | **当前** MSYS2 主编译脚本 |
| `ci/build-avc-win32.ps1` | 已弃用（MSVC，CI 不再使用） |
