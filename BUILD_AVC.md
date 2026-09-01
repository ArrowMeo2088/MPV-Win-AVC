# MPV-Win-AVC 精简构建（MSYS2 MINGW64）

面向 B 站流式播放的 **MinGW libmpv**：Intel QSV（`h264_qsv`）+ AAC 软解 + DASH/fMP4 + HTTPS。

FFmpeg 来自独立仓库 [FFmpeg-Win-AVC-DLL](https://github.com/ArrowMeo2088/FFmpeg-Win-AVC-DLL)（configure 静态库），**不再**使用 gstreamer meson-ports ffmpeg。

## 功能范围

| 启用 | 禁用 |
|------|------|
| `h264_qsv`（Intel HD 520+ / libvpl） | H.264 软解、NV/AMD/ARC/DXVA |
| AAC 软解 | 弹幕、Lua/JS、C 插件、截图、转码 |
| DASH / mov / fMP4 | mpv CLI（`cplayer=false`） |
| HTTP/HTTPS 流式 | libass / 字幕字体栈 |

## 运行时部署（mpv-kernel）

拷贝 `dist/mpv-win-avc-x64/bin/` 到应用目录，与 exe 同级。

**阶段二（当前 CI）**：`MPV_PACK_MODE=ldd`，包含 libplacebo/shaderc 等 MinGW DLL。

**阶段三目标**：`MPV_PACK_MODE=minimal`，≤5 DLL、≤40 MiB。

| DLL | 说明 |
|-----|------|
| `libmpv-2.dll` | libmpv + 静态 FFmpeg |
| `libvpl-2.dll` | Intel QSV（必需） |
| `libplacebo-*.dll` 等 | 阶段二动态渲染栈（阶段三静态化后移除） |

`bin/MANIFEST.txt` 记录实际文件大小与 DLL 数量。

## 静态链接闭包

静态 FFmpeg 链入 `libmpv-2.dll` 时，meson 不会自动传播 `libavformat.pc` 的 `Libs.private`：

| 依赖 | 方式 | meson 处理 |
|------|------|------------|
| libav* | 静态 `.a` | `dependency(..., static: true)` |
| libxml2（DASH） | 静态 | `dependency('libxml-2.0', static: true)` + `library()` 显式 `link_args`（`pkg-config --static libxml-2.0`） |
| libvpl（QSV） | 动态 `libvpl-2.dll` | `cc.find_library('vpl', static: false)` |

FFmpeg 须以 `-DLIBXML_STATIC` 重编（见 FFmpeg `BUILD.md`）。`ci/link-smoke.sh` 通过 `av_find_input_format("dash")` + `--whole-archive libavformat` 拉入 `dashdec.o`，避免假阳性。

## 本地构建

```bash
# Ref 下并列克隆
git clone --depth=1 https://github.com/ArrowMeo2088/FFmpeg-Win-AVC-DLL ../FFmpeg-Win-AVC-DLL
git clone --depth=1 https://github.com/ArrowMeo2088/MPV-Win-AVC .

# MSYS2 MINGW64 shell
FFMPEG_SRC=../FFmpeg-Win-AVC-DLL bash ./ci/build-avc-msys2.sh
```

环境变量：

| 变量 | 默认 | 说明 |
|------|------|------|
| `FFMPEG_SRC` | `../FFmpeg-Win-AVC-DLL` | FFmpeg 源码目录 |
| `FFMPEG_PREFIX` | `$FFMPEG_SRC/dist/.../prefix` | pkg-config 前缀 |
| `MPV_PACK_MODE` | `ldd` | `ldd` 全闭包；`minimal` 白名单 |
| `MPV_LTO` | `false` | 链接时 LTO |

## CI

`.github/workflows/build_avc.yml` 串联 checkout FFmpeg + MPV，MSYS2 MINGW64 构建。

## mpv-kernel 初始化

默认 **`PreferDecodeType.Qsv`**（`vo=gpu` + `d3d11` + `hwdec=no` → FFmpeg `h264_qsv`）。

```csharp
MpvNative.Initialize(Path.Combine(AppContext.BaseDirectory, "libmpv-2.dll"));
await client.SetVideoOutputAsync(VideoOutputType.Gpu);
await client.SetGpuApiAsync(GpuApiType.D3D11);
await client.SetGpuContextAsync(GpuContextType.D3D11);
await client.SetHardwareDecodeAsync(HardwareDecodeType.None);
```

或加载 `config/mpv-avc-kernel.conf`。

## 验收

1. CI `build_avc` 绿，`bin/libmpv-2.dll` + `libvpl-2.dll` 存在
2. Intel 核显上 DASH URL 能起播（`h264_qsv`）
3. 阶段三：`bin/` ≤5 DLL，总 ≤40 MiB（见 [DOCS/PHASE3-SIZE.md](DOCS/PHASE3-SIZE.md)）
