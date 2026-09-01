# MPV-Win-AVC 精简构建（MSYS2 MINGW64）

面向 B 站流式播放的 **MinGW libmpv**：Intel QSV（`h264_qsv`）+ AAC 软解 + DASH/fMP4 + HTTPS。

## 功能范围

| 启用 | 禁用 |
|------|------|
| `h264_qsv`（Intel HD 520+ / libvpl） | H.264 软解、NV/AMD/ARC/DXVA |
| AAC 软解 | 弹幕、Lua/JS、C 插件、截图、转码 |
| DASH / mov / fMP4 | mpv CLI（`cplayer=false`） |
| HTTP/HTTPS 流式 | libass / 字幕字体栈 |

## 运行时部署（mpv-kernel）

仅拷贝 `dist/mpv-win-avc-x64/bin/` 到应用目录，与 exe 同级：

| DLL | 说明 |
|-----|------|
| `libmpv-2.dll` | libmpv + 静态 FFmpeg / libplacebo / shaderc / spirv-cross |
| `libvpl-2.dll` | Intel QSV（`h264_qsv` 运行时 `dlopen`） |
| `libgcc_s_seh-1.dll` | 若 `ldd` 需要 |
| `libstdc++-6.dll` | 若 `ldd` 需要 |
| `libwinpthread-1.dll` | 若 `ldd` 需要 |

`bin/MANIFEST.txt` 记录实际文件大小。打包模式 `MPV_PACK_MODE=minimal`（默认）时，出现白名单外 DLL 则 CI 失败。

**不应出现**：`libass-9.dll`、`libfreetype`、`libshaderc_shared.dll`、`libplacebo-360.dll` 等。

## CI / 本地构建

```bash
cd /path/to/MPV-Win-AVC
bash ./ci/build-avc-msys2.sh
```

脚本会：

1. 自编译**静态** `shaderc`、`spirv-cross` 到 `.deps-prefix/`
2. `force-fallback` 构建**静态** `libplacebo`（无 dovi/lcms/vulkan）
3. 使用 in-tree **libass stub**（无 pacman libass）
4. `-Dbuildtype=release`、`-Db_lto=true`、`strip libmpv-2.dll`
5. 显式复制 `libvpl-2.dll` 并校验 `ldd` 闭包

回退全量 `ldd` 打包：`MPV_PACK_MODE=ldd bash ./ci/build-avc-msys2.sh`

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

1. `bin/` 内 ≤5 个 DLL，含 `libvpl-2.dll`
2. 总体积目标 ≤40 MiB
3. Intel 核显上 DASH URL 能起播（`h264_qsv`）
