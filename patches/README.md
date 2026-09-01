# libass removal

Upstream mpv declares libass as a hard dependency. For Bili.NetF we ship
in-tree stubs instead of linking libass and its font stack:

- `sub/ass.h`, `sub/ass_types.h` — API headers (from libmpv-darwin-build patch)
- `sub/ass_stub.c` — no-op implementations for Windows DLL link
- `meson.build` — `features['libass'] = false`, no pkg-config libass

Reference patch (mpv 0.36): `mpv-remove-libass.patch` (may not apply cleanly on newer mpv).
