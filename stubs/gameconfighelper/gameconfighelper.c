/*
 * GameConfigHelper.dll stub
 *
 * Minimal stub for Minecraft Bedrock's GameLaunchHelper.exe.
 * GameLaunchHelper imports OpenGameConfigForPackage from this DLL.
 * We return S_OK to let the launcher proceed.
 */

#include <windows.h>

HRESULT __stdcall OpenGameConfigForPackage(void *package_id, void **config)
{
    if (config)
        *config = NULL;
    return S_OK;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    return TRUE;
}
