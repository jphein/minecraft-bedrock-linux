#include <windows.h>

typedef union {
    UINT64 Version;
    struct {
        USHORT Revision;
        USHORT Build;
        USHORT Minor;
        USHORT Major;
    } DUMMYSTRUCTNAME;
} PACKAGE_VERSION;

__declspec(dllexport) HRESULT __cdecl MddBootstrapInitialize(UINT32 majorMinorVersion,
    PCWSTR versionTag, PACKAGE_VERSION minVersion)
{
    return S_OK;
}

__declspec(dllexport) HRESULT __cdecl MddBootstrapInitialize2(UINT32 majorMinorVersion,
    PCWSTR versionTag, PACKAGE_VERSION minVersion, UINT32 options)
{
    return S_OK;
}

__declspec(dllexport) void __cdecl MddBootstrapShutdown(void)
{
}

__declspec(dllexport) HRESULT __cdecl MddBootstrapTestInitialize(PCWSTR path, PCWSTR frameworkPath,
    PCWSTR mainPackage)
{
    return S_OK;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    return TRUE;
}
