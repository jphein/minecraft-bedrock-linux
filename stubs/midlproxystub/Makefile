# api-ms-win-core-com-midlproxystub-l1-1-0.dll stub
#
# Provides ObjectStublessClient3-32 for GameInputRedist.dll.
#
# Background:
#   GameInputRedist.dll imports ObjectStublessClient3/4 from the API set
#   api-ms-win-core-com-midlproxystub-l1-1-0.dll. Wine's API set schema
#   redirects this to combase.dll, which in turn has forwarders pointing
#   to rpcrt4.ObjectStublessClient3/4. However, Wine Staging 10.0's PE-only
#   mode fails to resolve these forwarders (find_forwarded_export bug), so
#   the IAT slot gets populated with combase's unimplemented stub, causing
#   an abort when GameInputRedist calls it.
#
# Fix:
#   Provide a real api-ms-win-core-com-midlproxystub-l1-1-0.dll that Wine
#   uses instead of the API set redirect. At DLL load time, DllMain obtains
#   the actual ObjectStublessClientN function pointers from rpcrt4.dll (which
#   has working implementations) via GetProcAddress, and stores them in a
#   table. Each stub tail-calls into rpcrt4's implementation.

CC = x86_64-w64-mingw32-gcc
DLL = api-ms-win-core-com-midlproxystub-l1-1-0.dll

all: $(DLL)

$(DLL): dllmain.c stubs.s midlproxystub.def
	$(CC) -O2 -shared -o $@ dllmain.c stubs.s midlproxystub.def -lkernel32

verify: $(DLL)
	@echo "Checking exports:"
	@objdump -p $(DLL) | grep "ObjectStubless" | wc -l | xargs -I{} echo "  {} ObjectStublessClientN exports (expect 30)"
	@objdump -p $(DLL) | grep "ObjectStublessClient4" | head -1

PREFIX_DIR ?= $(HOME)/Games/MinecraftBedrock/prefix

deploy: $(DLL)
	cp $(DLL) $(PREFIX_DIR)/pfx/drive_c/windows/system32/$(DLL)
	@echo "Deployed to $(PREFIX_DIR)/pfx/drive_c/windows/system32/"

clean:
	rm -f $(DLL)

.PHONY: all verify deploy clean
