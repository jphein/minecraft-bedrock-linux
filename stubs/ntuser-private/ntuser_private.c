#include <windows.h>

/* Inject the cohtml pointer-click hook WITHOUT being GameInput-related.
 * GameInputRedist.dll must be ABSENT (builtin GameInputCreate path => no "missing required
 * component" error screen). This stub is loaded by the game (Microsoft.InputStateManager.dll
 * imports ordinals 2503/2505), so we use its DllMain to LoadLibrary pointerhook.dll, whose
 * own DllMain installs the GetPointerInfo hook + window subclass that makes cohtml clicks work. */
static DWORD WINAPI load_pointerhook(void *p) {
    (void)p;
    Sleep(50);                       /* let the loader lock release before LoadLibrary */
    LoadLibraryA("pointerhook.dll"); /* resolved from the game (exe) dir */
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, void *reserved) {
    (void)inst; (void)reserved;
    if (reason == DLL_PROCESS_ATTACH)
        CreateThread(NULL, 0, load_pointerhook, NULL, 0, NULL);
    return TRUE;
}

/* Ordinal stubs for api-ms-win-rtcore-ntuser-private-l1-1-1.dll
 * Microsoft.InputStateManager.dll imports ordinals 2503 and 2505 (no names).
 * These are undocumented internal ntuser functions. Return 0 as stubs. */

__int64 __stdcall ord_2503(void) { return 0; }
__int64 __stdcall ord_2505(void) { return 0; }
