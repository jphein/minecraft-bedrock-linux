# Pointer-hook injection (cohtml mouse clicks) — playable combo

The GameInput error screen is avoided ONLY when `GameInputRedist.dll` is **absent**
(builtin `GameInputCreate` path). So the cohtml pointer-click hook can't ride on the
redist. Instead we inject it via a **dwmapi.dll proxy** (Minecraft statically imports
`dwmapi.dll!DwmSetWindowAttribute`, so it loads at startup in-process):

    # dwmapi.dll = pointer-hook (gameinput.c, POINTERHOOK_ONLY: no GameInput exports)
    #            + DwmSetWindowAttribute stub
    x86_64-w64-mingw32-gcc -shared -O2 -DPOINTERHOOK_ONLY \
        -o dwmapi.dll gameinput.c dwmapi_export.c

Deploy `dwmapi.dll` into the game dir; launch with `dwmapi=n` (force native) +
`gameinput=b` (builtin) + NO `GameInputRedist.dll`. dwmapi's DllMain installs the
GetPointerInfo inline-hook and a deferred thread that subclasses the Minecraft window
once it appears (captures WM_POINTER → serves cohtml). See scripts/launch-playable.sh.
