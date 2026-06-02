CC = x86_64-w64-mingw32-gcc
WINDRES = x86_64-w64-mingw32-windres
CFLAGS = -shared -O2 -Wl,--kill-at
TARGET = GameInput.dll

$(TARGET): gameinput.c gameinput.def version.o
	$(CC) $(CFLAGS) -o $@ $^

version.o: version.rc
	$(WINDRES) $< $@

clean:
	rm -f $(TARGET) version.o

.PHONY: clean
