CC = x86_64-w64-mingw32-gcc
CFLAGS = -shared -O2
TARGETS = api-ms-win-rtcore-ntuser-private-l1-1-1.dll ext-ms-win-ntuser-private-l1-1-1.dll

all: $(TARGETS)

api-ms-win-rtcore-ntuser-private-l1-1-1.dll: ntuser_private.c ntuser_private.def
	$(CC) $(CFLAGS) -o $@ $^

ext-ms-win-ntuser-private-l1-1-1.dll: ext_ntuser_private.c ext_ntuser_private.def
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f $(TARGETS)

.PHONY: all clean
