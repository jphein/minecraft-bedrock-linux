# GameConfigHelper.dll stub
# Provides OpenGameConfigForPackage for GameLaunchHelper.exe (Minecraft Bedrock)

CC = x86_64-w64-mingw32-gcc
DLL = GameConfigHelper.dll
PROTON_DIR ?= $(HOME)/.steam/root/compatibilitytools.d/GDK-Proton10-32
PREFIX_DIR ?= $(HOME)/Games/MinecraftBedrock/prefix

all: $(DLL)

$(DLL): gameconfighelper.c gameconfighelper.def
	$(CC) -shared -o $@ $^ -Wl,--out-implib,libgameconfighelper.a

verify: $(DLL)
	objdump -p $(DLL) | grep OpenGameConfig

deploy: $(DLL)
	cp $(DLL) $(PROTON_DIR)/files/lib/wine/x86_64-windows/gameconfighelper.dll
	cp $(DLL) $(PREFIX_DIR)/pfx/drive_c/windows/system32/GameConfigHelper.dll

clean:
	rm -f $(DLL) libgameconfighelper.a

.PHONY: all verify deploy clean
