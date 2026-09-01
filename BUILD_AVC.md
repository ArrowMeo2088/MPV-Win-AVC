# MPV-Win-AVC 精简构建

面向 B 站流式播放的 **MSVC libmpv** 构建：Intel QSV（`h264_qsv`）硬解 + AAC 软解 + DASH/fMP4 + HTTPS。

配套 C# 封装：[mpv-kernel](../mpv-kernel-master)（`Richasy.MpvKernel`）。

## 功能范围

| 启用 | 禁用 |
|------|------|
| `h264_qsv`（Intel HD 520+ / libvpl） | H.264 软解、NV/AMD/ARC/DXVA/D3D11VA |
| AAC 软解 | 弹幕（subrandr）、Lua/JS 脚本、C 插件 |
| DASH / mov / fMP4 demux | 复杂滤镜、VapourSynth、Vulkan |
| HTTP/HTTPS + 自定义请求头 / Cookies | mpv CLI（`cplayer=false`） |
| 播放、DASH 流式 | 截图、转码/录制、弹幕（subrandr）、Lua/JS、C 插件 |

FFmpeg 以 **静态库** 链入 `libmpv-2.dll`；`libvpl.dll` 运行时随包分发。

## mpv-kernel 适配

### DLL 与部署

`MpvImportResolver` 默认加载 **`libmpv-2.dll`**（与 `Constants.MpvLibraryName = "mpv"` 对应）。

将 CI 产物 `dist/mpv-win-avc-x64/bin/` 下文件放到应用目录（或 `MpvNative.Initialize` 指定路径的同级目录）：

```
YourApp/
  libmpv-2.dll    ← MpvNative.Initialize 指向此文件
  libvpl.dll      ← 必须与 libmpv 同目录或在 PATH 中
```

```csharp
MpvNative.Initialize(Path.Combine(AppContext.BaseDirectory, "libmpv-2.dll"));
var client = await MpvClient.CreateAsync(new MpvInitializeOptions
{
    UseConfig = false,
    LoadScripts = false,
});
```

### 推荐初始化（Intel QSV）

本构建 **未编译** mpv 的 `d3d11va` / `nvdec` / `dxva2` hwdec，也 **未编译** FFmpeg `h264` 软解。  
硬解走 FFmpeg **`h264_qsv`**，请在 C# 侧使用 **GPU 渲染 + lavc QSV**，不要用 `HardwareDecodeType.D3D11va` / `Nvdec`：

```csharp
await client.SetVideoOutputAsync(VideoOutputType.Gpu);
await client.SetGpuApiAsync(GpuApiType.D3D11);
await client.SetGpuContextAsync(GpuContextType.D3D11);
await client.SetHardwareDecodeAsync(HardwareDecodeType.None); // lavc → h264_qsv
```

也可加载打包内的 `config/mpv-avc-kernel.conf`（等价选项见 `etc/mpv-avc-kernel.conf`）。

mpv-kernel 示例里 `PreferDecodeType.D3D11` / `NVDEC` / `Vulkan` **不适用** 本构建；请用 `PreferDecodeType.Qsv`（若已更新示例）或上表代码。

### 已覆盖的 mpv-kernel API

| 能力 | mpv-kernel 入口 | 本构建 |
|------|-----------------|--------|
| 播放 URL / 本地文件 | `PlayAsync` + `loadfile` | ✅ |
| DASH / fMP4 | FFmpeg `dash` demuxer | ✅ |
| HTTP 鉴权头 | `MpvPlayOptions.HttpHeaders` / `SetHttpHeadersAsync` | ✅ |
| User-Agent | `MpvPlayOptions.UserAgent` | ✅ |
| Cookies | `MpvPlayOptions.EnableCookies` | ✅ |
| 窗口嵌入 | `MpvPlayOptions.WindowHandle` → `wid` | ✅ `vo=gpu` + d3d11 |
| 音量 / 进度 / 倍速 | 属性读写 | ✅ |
| 弹幕 | subrandr | ❌ 已禁用 |
| ytdl | `EnableYtdl` | ❌ 不需要（直连 DASH URL） |

### 解码说明

- **视频**：H.264 → Intel QSV（`h264_qsv`）
- **音频**：AAC → 软解
- **截图 / 转码 / 录制**：未包含（`encoders`、`muxers` 均关闭；mpv `jpeg` 未启用）

## CI

- Workflow：`.github/workflows/build_avc.yml`
- 触发：`push` 到 `master`/`main`，或手动 `workflow_dispatch`
- Runner：`windows-2025` + VS DevShell + clang-cl

上游 mpv 的 `build.yml` / `lint.yml` 等已改为仅 `workflow_dispatch`，不再随提交自动跑。

## 本地构建

```powershell
# 1) vcpkg
vcpkg install libvpl:x64-windows libxml2:x64-windows-static pkgconf:x64-windows

# 2) VS DevShell (amd64)
Import-Module "$env:VS\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath <VS路径> -SkipAutomaticLocation -DevCmdArguments "-arch=amd64 -host_arch=amd64"

# 3) 工具
pip install meson
# NASM、ccache 需在 PATH

$env:VCPKG_ROOT = 'C:\vcpkg'
$env:CC = 'clang'
$env:CXX = 'clang++'
$env:CC_LD = 'lld-link'
$env:CXX_LD = 'lld-link'
./ci/build-avc-win32.ps1
```

产出：

```
dist/mpv-win-avc-x64/
  bin/libmpv-2.dll
  bin/libvpl.dll
  config/mpv-avc-kernel.conf
  BUILD_AVC.md
```

## 脚本

| 文件 | 作用 |
|------|------|
| `ci/build-avc-win32.ps1` | meson 配置、编译、打包 |
| `etc/mpv-avc-kernel.conf` | mpv-kernel 推荐默认选项 |
| `ci/build-win32.ps1` | 上游完整 Windows 构建（参考，CI 已停用） |
