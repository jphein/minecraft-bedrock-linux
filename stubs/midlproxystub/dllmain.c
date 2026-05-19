#include <windows.h>
#include <stdio.h>

extern void *fn_ptrs[];

static void init_stubs(void)
{
    HMODULE rpcrt4 = GetModuleHandleA("rpcrt4.dll");
    if (!rpcrt4) rpcrt4 = LoadLibraryA("rpcrt4.dll");
    if (!rpcrt4) return;

    int i;
    for (i = 3; i <= 32; i++) {
        char name[32];
        sprintf(name, "ObjectStublessClient%d", i);
        fn_ptrs[i] = (void *)GetProcAddress(rpcrt4, name);
        if (!fn_ptrs[i]) {
            /* ordinal = 242 + i (base 1: Client3=ord245=idx244, Client4=ord246=idx245...) */
            fn_ptrs[i] = (void *)GetProcAddress(rpcrt4, (LPCSTR)(ULONG_PTR)(242 + i));
        }
    }
}

BOOL WINAPI DllMain(HINSTANCE hInst, DWORD reason, LPVOID reserved)
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(hInst);
        init_stubs();
    }
    return TRUE;
}
