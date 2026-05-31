#include <windows.h>

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, void *reserved) {
    (void)inst; (void)reason; (void)reserved;
    return TRUE;
}

/* Ordinal stubs for api-ms-win-rtcore-ntuser-private-l1-1-1.dll
 * Microsoft.InputStateManager.dll imports ordinals 2503 and 2505 (no names).
 * These are undocumented internal ntuser functions. Return 0 as stubs. */

__int64 __stdcall ord_2503(void) { return 0; }
__int64 __stdcall ord_2505(void) { return 0; }
