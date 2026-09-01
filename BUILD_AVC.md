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

产出：`dist/mpv-win-avc-x64/bin/`（`libmpv-2.dll` + MinGW 运行时依赖闭包 + `libvpl-2.dll`）。

## mpv-kernel 初始化

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
