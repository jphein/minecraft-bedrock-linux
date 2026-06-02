CC = x86_64-w64-mingw32-gcc
CFLAGS = -shared -O2
TARGET = Microsoft.WindowsAppRuntime.Bootstrap.dll

$(TARGET): bootstrap.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)

.PHONY: clean
