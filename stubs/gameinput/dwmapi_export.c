#include <windows.h>
/* Minecraft imports only DwmSetWindowAttribute from dwmapi.dll — stub it (cosmetic). */
__declspec(dllexport) HRESULT WINAPI DwmSetWindowAttribute(HWND hwnd, DWORD attr, LPCVOID pv, DWORD cb) {
    (void)hwnd; (void)attr; (void)pv; (void)cb;
    return S_OK;
}
