# 阶段三：体积压缩路线

当前阶段二使用 pacman 动态 `libplacebo`/`shaderc`/`spirv-cross`，`MPV_PACK_MODE=ldd` 打包全部 MinGW 依赖 DLL。

## 已做

- FFmpeg configure 白名单：去掉 `hevc` parser（B 站纯 AVC）
- FFmpeg 静态链入 `libmpv-2.dll`（`pkg-config --static` + meson `static: true`）

## 下一步（目标 ≤5 DLL、≤40 MiB）

1. 查看 `bin/MANIFEST.txt` 中各 DLL 大小，确认 FFmpeg 静态后 `libmpv-2.dll` 体积
2. MPV：恢复静态 `libplacebo` + 修 spirv-cross pkg-config 全库链接，或评估 mpv d3d11 无 placebo 路径
3. FFmpeg：若仍超标，对 `libavcodec/allcodecs.c` 等做注册表级删减
4. 切换 `MPV_PACK_MODE=minimal`，白名单仅保留：
   - `libmpv-2.dll`
   - `libvpl-2.dll`
   - `libgcc_s_seh-1.dll` / `libstdc++-6.dll` / `libwinpthread-1.dll`（按 `ldd` 需要）

## 验证命令

```bash
# MSYS2 MINGW64
ldd dist/mpv-win-avc-x64/bin/libmpv-2.dll
wc -c dist/mpv-win-avc-x64/bin/*.dll
```
