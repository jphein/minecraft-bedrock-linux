/*
 * GameInput.dll stub for Minecraft Bedrock on WineGDK.
 * Provides v2 IGameInput with mouse + gamepad via Win32/XInput.
 */

#include <windows.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

static FILE *g_log = NULL;
static void trace_init(void) {
    if (!g_log) g_log = fopen("Z:\\tmp\\gameinput.log", "w");
}
#define TRACE(fmt, ...) do { trace_init(); if (g_log) { fprintf(g_log, fmt "\n", ##__VA_ARGS__); fflush(g_log); } } while(0)

/* --- GameInput kind flags (from GameInputKind enum) --- */
#define GI_KIND_RAW          0x00000001u
#define GI_KIND_CTRL_AXIS    0x00000002u
#define GI_KIND_CTRL_BTN     0x00000004u
#define GI_KIND_CTRL_SW      0x00000008u
#define GI_KIND_CONTROLLER   0x0000000Eu
#define GI_KIND_KEYBOARD     0x00000010u
#define GI_KIND_MOUSE        0x00000020u
#define GI_KIND_TOUCH        0x00000100u
#define GI_KIND_MOTION       0x00001000u
#define GI_KIND_ARCADESTICK  0x00010000u
#define GI_KIND_FLIGHTSTICK  0x00020000u
#define GI_KIND_GAMEPAD      0x00040000u
#define GI_KIND_RACINGWHEEL  0x00080000u
#define GI_KIND_UINAV        0x01000000u

#define GI_MOUSE_LEFT     0x00000001u
#define GI_MOUSE_RIGHT    0x00000002u
#define GI_MOUSE_MIDDLE   0x00000004u
#define GI_MOUSE_4        0x00000008u
#define GI_MOUSE_5        0x00000010u
#define GI_RELPOS         0x00000002u
#define GI_DEV_CONNECTED  0x00000001u

/* GameInput gamepad buttons */
#define GI_GP_MENU         0x00000001u
#define GI_GP_VIEW         0x00000002u
#define GI_GP_A            0x00000004u
#define GI_GP_B            0x00000008u
#define GI_GP_X            0x00000010u
#define GI_GP_Y            0x00000020u
#define GI_GP_DPAD_UP      0x00000040u
#define GI_GP_DPAD_DOWN    0x00000080u
#define GI_GP_DPAD_LEFT    0x00000100u
#define GI_GP_DPAD_RIGHT   0x00000200u
#define GI_GP_LSHOULDER    0x00000400u
#define GI_GP_RSHOULDER    0x00000800u
#define GI_GP_LTHUMB       0x00001000u
#define GI_GP_RTHUMB       0x00002000u

/* XInput constants (avoid header dependency) */
#define XI_DPAD_UP       0x0001
#define XI_DPAD_DOWN     0x0002
#define XI_DPAD_LEFT     0x0004
#define XI_DPAD_RIGHT    0x0008
#define XI_START         0x0010
#define XI_BACK          0x0020
#define XI_LTHUMB        0x0040
#define XI_RTHUMB        0x0080
#define XI_LSHOULDER     0x0100
#define XI_RSHOULDER     0x0200
#define XI_A             0x1000
#define XI_B             0x2000
#define XI_X             0x4000
#define XI_Y             0x8000

typedef uint32_t GIKind;
typedef uint32_t GIDevStatus;
typedef uint32_t GIEnumKind;
typedef uint32_t GIFocusPolicy;
typedef uint32_t GISysButtons;
typedef uint64_t GIToken;

typedef struct {
    uint32_t buttons;
    uint32_t positions;
    int64_t positionX;
    int64_t positionY;
    int64_t absolutePositionX;
    int64_t absolutePositionY;
    int64_t wheelX;
    int64_t wheelY;
} GIMouseState;

typedef struct {
    uint32_t buttons;
    float leftTrigger;
    float rightTrigger;
    float leftThumbstickX;
    float leftThumbstickY;
    float rightThumbstickX;
    float rightThumbstickY;
} GIGamepadState;

/* Must match real GameInputDeviceInfo layout exactly */
typedef struct { uint16_t page; uint16_t id; } GIUsage;
typedef struct { uint16_t major, minor, build, revision; } GIVersion;
typedef struct { uint8_t value[32]; } GIDevId;

typedef struct {
    uint32_t infoSize;            /* 0 */
    uint16_t vendorId;            /* 4 */
    uint16_t productId;           /* 6 */
    uint16_t revisionNumber;      /* 8 */
    uint8_t  interfaceNumber;     /* 10 */
    uint8_t  collectionNumber;    /* 11 */
    GIUsage  usage;               /* 12 */
    GIVersion hardwareVersion;    /* 16 */
    GIVersion firmwareVersion;    /* 24 */
    GIDevId  deviceId;            /* 32 */
    GIDevId  deviceRootId;        /* 64 */
    uint32_t deviceFamily;        /* 96 */
    uint32_t capabilities;        /* 100 */
    GIKind   supportedInput;      /* 104 */
    uint32_t supportedRumbleMotors; /* 108 */
    uint32_t inputReportCount;    /* 112 */
    uint32_t outputReportCount;   /* 116 */
    uint32_t featureReportCount;  /* 120 */
    uint32_t controllerAxisCount; /* 124 */
    uint32_t controllerButtonCount; /* 128 */
    uint32_t controllerSwitchCount; /* 132 */
    uint32_t keyCount;            /* 136 */
    uint32_t mouseButtonCount;    /* 140 */
    uint32_t touchPointCount;     /* 144 */
    uint32_t touchSensorCount;    /* 148 */
    uint32_t motionAxisCount;     /* 152 */
    uint32_t arcadeStickButtonCount; /* 156 */
    uint32_t flightStickButtonCount; /* 160 */
    uint32_t gamepadButtonCount;  /* 164 */
    uint32_t racingWheelButtonCount; /* 168 */
    uint32_t uiNavigationButtonCount; /* 172 */
    void    *inputReportInfo;     /* 176 */
    void    *outputReportInfo;    /* 184 */
    void    *featureReportInfo;   /* 192 */
    void    *controllerAxisInfo;  /* 200 */
    void    *controllerButtonInfo; /* 208 */
    void    *controllerSwitchInfo; /* 216 */
    void    *keyboardInfo;        /* 224 */
    void    *mouseInfo;           /* 232 */
    void    *touchSensorInfo;     /* 240 */
    void    *motionInfo;          /* 248 */
    void    *arcadeStickInfo;     /* 256 */
    void    *flightStickInfo;     /* 264 */
    void    *gamepadInfo;         /* 272 */
    void    *racingWheelInfo;     /* 280 */
    void    *uiNavigationInfo;    /* 288 */
    void    *forceFeedbackMotorInfo; /* 296 */
    void    *hapticFeedbackMotorInfo; /* 304 */
    const wchar_t *displayName;   /* 312 */
} GIDeviceInfo;

/* GameInputMouseInfo: just basic mouse info (all zeros = defaults) */
typedef struct {
    uint32_t supportedButtons;
    uint16_t sampleRate;
    uint32_t sensorResolution;
    bool     hasWheel;
} GIMouseInfo;

/* GameInputGamepadInfo: button labels (GameInputLabel = uint32) */
typedef struct {
    uint32_t labels[14];
} GIGamepadInfo;

static GIMouseInfo g_mouse_info = { 0x1F, 125, 800, true };
static GIGamepadInfo g_gamepad_info = { {0} };

/* XInput dynamic loading */
typedef struct { WORD buttons; BYTE lt; BYTE rt; SHORT lx; SHORT ly; SHORT rx; SHORT ry; } XI_PAD;
typedef struct { DWORD packet; XI_PAD pad; } XI_STATE;
typedef DWORD (WINAPI *PFN_XInputGetState)(DWORD, XI_STATE *);
static PFN_XInputGetState pfn_XInputGetState;
static BOOL xi_loaded = FALSE;
static BOOL xi_available = FALSE;

static void load_xinput(void) {
    if (xi_loaded) return;
    xi_loaded = TRUE;
    HMODULE h = LoadLibraryA("xinput1_4.dll");
    if (!h) h = LoadLibraryA("xinput1_3.dll");
    if (!h) h = LoadLibraryA("xinput9_1_0.dll");
    if (h) {
        pfn_XInputGetState = (PFN_XInputGetState)GetProcAddress(h, "XInputGetState");
        if (pfn_XInputGetState) {
            XI_STATE st;
            xi_available = (pfn_XInputGetState(0, &st) == 0);
            TRACE("XInput loaded, controller %s", xi_available ? "CONNECTED" : "not found");
        }
    }
    if (!pfn_XInputGetState) TRACE("XInput not available");
}

/* Forward declarations */
typedef struct StubDevice StubDevice;
typedef struct StubReading StubReading;
typedef struct StubGI StubGI;

/* ================================================================
 * IGameInputReading v2 — 21 methods
 * ================================================================ */
typedef struct StubReadingVtbl {
    HRESULT (STDMETHODCALLTYPE *QI)(StubReading *, REFIID, void **);
    ULONG   (STDMETHODCALLTYPE *AddRef)(StubReading *);
    ULONG   (STDMETHODCALLTYPE *Release)(StubReading *);
    GIKind  (STDMETHODCALLTYPE *GetInputKind)(StubReading *);
    uint64_t(STDMETHODCALLTYPE *GetTimestamp)(StubReading *);
    HRESULT (STDMETHODCALLTYPE *GetDevice)(StubReading *, void **);
    uint32_t(STDMETHODCALLTYPE *GetControllerAxisCount)(StubReading *);
    uint32_t(STDMETHODCALLTYPE *GetControllerAxisState)(StubReading *, uint32_t, float *);
    uint32_t(STDMETHODCALLTYPE *GetControllerButtonCount)(StubReading *);
    uint32_t(STDMETHODCALLTYPE *GetControllerButtonState)(StubReading *, uint32_t, BOOL *);
    uint32_t(STDMETHODCALLTYPE *GetControllerSwitchCount)(StubReading *);
    uint32_t(STDMETHODCALLTYPE *GetControllerSwitchState)(StubReading *, uint32_t, int *);
    uint32_t(STDMETHODCALLTYPE *GetKeyCount)(StubReading *);
    uint32_t(STDMETHODCALLTYPE *GetKeyState)(StubReading *, uint32_t, void *);
    bool    (STDMETHODCALLTYPE *GetMouseState)(StubReading *, GIMouseState *);
    bool    (STDMETHODCALLTYPE *GetSensorsState)(StubReading *, void *);
    bool    (STDMETHODCALLTYPE *GetArcadeStickState)(StubReading *, void *);
    bool    (STDMETHODCALLTYPE *GetFlightStickState)(StubReading *, void *);
    bool    (STDMETHODCALLTYPE *GetGamepadState)(StubReading *, GIGamepadState *);
    bool    (STDMETHODCALLTYPE *GetRacingWheelState)(StubReading *, void *);
    bool    (STDMETHODCALLTYPE *GetUiNavigationState)(StubReading *, void *);
} StubReadingVtbl;

struct StubReading {
    const StubReadingVtbl *lpVtbl;
    LONG ref;
    GIKind kind;
    StubDevice *device;
    GIMouseState mouse;
    GIGamepadState gamepad;
    uint64_t timestamp;
};

static HRESULT STDMETHODCALLTYPE r_qi(StubReading *s, REFIID i, void **o) { *o = s; s->ref++; return S_OK; }
static ULONG STDMETHODCALLTYPE r_addref(StubReading *s) { return InterlockedIncrement(&s->ref); }
static ULONG STDMETHODCALLTYPE r_release(StubReading *s) {
    ULONG r = InterlockedDecrement(&s->ref);
    if (r == 0) HeapFree(GetProcessHeap(), 0, s);
    return r;
}
static GIKind STDMETHODCALLTYPE r_kind(StubReading *s) { return s->kind; }
static uint64_t STDMETHODCALLTYPE r_ts(StubReading *s) { return s->timestamp; }
static HRESULT STDMETHODCALLTYPE r_dev(StubReading *s, void **o);  /* forward — needs StubDevice */
static uint32_t STDMETHODCALLTYPE r_zero(StubReading *s) { return 0; }
static uint32_t STDMETHODCALLTYPE r_zero2(StubReading *s, uint32_t c, void *o) { return 0; }

static bool STDMETHODCALLTYPE r_mouse(StubReading *s, GIMouseState *o) {
    if (!(s->kind & GI_KIND_MOUSE)) return false;
    *o = s->mouse;
    return true;
}

static bool STDMETHODCALLTYPE r_gamepad(StubReading *s, GIGamepadState *o) {
    if (!(s->kind & GI_KIND_GAMEPAD)) return false;
    *o = s->gamepad;
    return true;
}

static bool STDMETHODCALLTYPE r_false(StubReading *s, void *o) { return false; }

static const StubReadingVtbl g_reading_vtbl = {
    r_qi, r_addref, r_release,
    r_kind, r_ts, r_dev,
    (void *)r_zero, (void *)r_zero2, (void *)r_zero, (void *)r_zero2,
    (void *)r_zero, (void *)r_zero2,
    (void *)r_zero, (void *)r_zero2,
    r_mouse,
    r_false, r_false, r_false, (void *)r_gamepad, r_false, r_false,
};

static uint32_t xi_to_gi_buttons(WORD xi) {
    uint32_t gi = 0;
    if (xi & XI_A) gi |= GI_GP_A;
    if (xi & XI_B) gi |= GI_GP_B;
    if (xi & XI_X) gi |= GI_GP_X;
    if (xi & XI_Y) gi |= GI_GP_Y;
    if (xi & XI_START) gi |= GI_GP_MENU;
    if (xi & XI_BACK) gi |= GI_GP_VIEW;
    if (xi & XI_DPAD_UP) gi |= GI_GP_DPAD_UP;
    if (xi & XI_DPAD_DOWN) gi |= GI_GP_DPAD_DOWN;
    if (xi & XI_DPAD_LEFT) gi |= GI_GP_DPAD_LEFT;
    if (xi & XI_DPAD_RIGHT) gi |= GI_GP_DPAD_RIGHT;
    if (xi & XI_LSHOULDER) gi |= GI_GP_LSHOULDER;
    if (xi & XI_RSHOULDER) gi |= GI_GP_RSHOULDER;
    if (xi & XI_LTHUMB) gi |= GI_GP_LTHUMB;
    if (xi & XI_RTHUMB) gi |= GI_GP_RTHUMB;
    return gi;
}

/* ================================================================
 * IGameInputDevice v2 — 11 methods
 * ================================================================ */
typedef struct StubDeviceVtbl {
    HRESULT (STDMETHODCALLTYPE *QI)(StubDevice *, REFIID, void **);
    ULONG   (STDMETHODCALLTYPE *AddRef)(StubDevice *);
    ULONG   (STDMETHODCALLTYPE *Release)(StubDevice *);
    const GIDeviceInfo *(STDMETHODCALLTYPE *GetDeviceInfo)(StubDevice *);
    HRESULT (STDMETHODCALLTYPE *GetHapticInfo)(StubDevice *, void *);
    GIDevStatus (STDMETHODCALLTYPE *GetDeviceStatus)(StubDevice *);
    HRESULT (STDMETHODCALLTYPE *CreateForceFeedbackEffect)(StubDevice *, void *);
    bool    (STDMETHODCALLTYPE *IsForceFeedbackMotorPoweredOn)(StubDevice *, void *);
    void    (STDMETHODCALLTYPE *SetForceFeedbackMotorGain)(StubDevice *, void *, float);
    void    (STDMETHODCALLTYPE *SetRumbleState)(StubDevice *, void *);
    void    (STDMETHODCALLTYPE *DirectInputEscape)(StubDevice *, void *);
} StubDeviceVtbl;

struct StubDevice {
    const StubDeviceVtbl *lpVtbl;
    LONG ref;
    GIDeviceInfo info;
    GIKind kind;
};

static HRESULT STDMETHODCALLTYPE d_qi(StubDevice *s, REFIID i, void **o) {
    TRACE("Device::QI dev=%p", (void *)s);
    *o = s; s->ref++; return S_OK;
}
static ULONG STDMETHODCALLTYPE d_addref(StubDevice *s) { return InterlockedIncrement(&s->ref); }
static ULONG STDMETHODCALLTYPE d_release(StubDevice *s) { return InterlockedDecrement(&s->ref); }
static const GIDeviceInfo *STDMETHODCALLTYPE d_info(StubDevice *s) {
    TRACE("GetDeviceInfo dev=%p kind=0x%x", (void *)s, s->kind);
    return &s->info;
}
static HRESULT STDMETHODCALLTYPE d_haptic(StubDevice *s, void *o) { return E_NOTIMPL; }
static GIDevStatus STDMETHODCALLTYPE d_status(StubDevice *s) {
    TRACE("Device::GetDeviceStatus dev=%p", (void *)s);
    return GI_DEV_CONNECTED;
}
static HRESULT STDMETHODCALLTYPE d_ffe(StubDevice *s, void *o) { return E_NOTIMPL; }
static bool STDMETHODCALLTYPE d_ffpow(StubDevice *s, void *o) { return false; }
static void STDMETHODCALLTYPE d_ffgain(StubDevice *s, void *o, float g) {}
static void STDMETHODCALLTYPE d_rumble(StubDevice *s, void *o) {}
static void STDMETHODCALLTYPE d_diesc(StubDevice *s, void *o) {}

static const StubDeviceVtbl g_device_vtbl = {
    d_qi, d_addref, d_release,
    d_info, d_haptic, d_status,
    d_ffe, d_ffpow, d_ffgain, d_rumble, d_diesc,
};

static StubDevice g_mouse_device;
static StubDevice g_gamepad_device;
static int g_devices_init = 0;

static HRESULT STDMETHODCALLTYPE r_dev(StubReading *s, void **o) {
    if (s->device) {
        InterlockedIncrement(&s->device->ref);
        *o = s->device;
        return S_OK;
    }
    *o = NULL;
    return E_NOTIMPL;
}

static void init_devices(void) {
    if (g_devices_init) return;
    g_devices_init = 1;

    memset(&g_mouse_device, 0, sizeof(g_mouse_device));
    g_mouse_device.lpVtbl = &g_device_vtbl;
    g_mouse_device.ref = 999;
    g_mouse_device.kind = GI_KIND_MOUSE;
    g_mouse_device.info.infoSize = sizeof(GIDeviceInfo);
    g_mouse_device.info.usage.page = 0x01;
    g_mouse_device.info.usage.id = 0x02;
    g_mouse_device.info.supportedInput = GI_KIND_MOUSE;
    g_mouse_device.info.mouseButtonCount = 5;
    g_mouse_device.info.deviceId.value[0] = 0x01;
    g_mouse_device.info.mouseInfo = &g_mouse_info;

    memset(&g_gamepad_device, 0, sizeof(g_gamepad_device));
    g_gamepad_device.lpVtbl = &g_device_vtbl;
    g_gamepad_device.ref = 999;
    g_gamepad_device.kind = GI_KIND_GAMEPAD;
    g_gamepad_device.info.infoSize = sizeof(GIDeviceInfo);
    g_gamepad_device.info.vendorId = 0x045e;
    g_gamepad_device.info.productId = 0x0b12;
    g_gamepad_device.info.usage.page = 0x01;
    g_gamepad_device.info.usage.id = 0x05;
    g_gamepad_device.info.deviceFamily = 2;
    g_gamepad_device.info.supportedInput = GI_KIND_GAMEPAD;
    g_gamepad_device.info.supportedRumbleMotors = 0x0F;
    g_gamepad_device.info.gamepadButtonCount = 14;
    g_gamepad_device.info.deviceId.value[0] = 0x02;
    g_gamepad_device.info.gamepadInfo = &g_gamepad_info;
}

/* ================================================================
 * IGameInput v2 — 17 methods
 * ================================================================ */
typedef void (*GIReadingCB)(GIToken, void *, StubReading *, bool);
typedef void (*GIDeviceCB)(GIToken, void *, StubDevice *, uint64_t, GIDevStatus, GIDevStatus);
typedef void (*GISysButtonCB)(GIToken, void *, uint64_t, GISysButtons, GISysButtons);
typedef void (*GIKbLayoutCB)(GIToken, void *, StubDevice *, uint64_t, uint32_t, uint32_t);
typedef struct IGameInputDispatcher IGameInputDispatcher;

/* Callback storage for reading callbacks */
typedef struct {
    GIReadingCB cb;
    void *ctx;
    GIKind kind;
    StubDevice *dev;
    GIToken token;
    BOOL active;
} ReadingCBEntry;

#define MAX_READING_CBS 16
static ReadingCBEntry g_reading_cbs[MAX_READING_CBS];
static LONG g_next_token = 100;
static HANDLE g_poll_thread = NULL;
static volatile BOOL g_running = FALSE;

typedef struct StubGIVtbl {
    HRESULT  (STDMETHODCALLTYPE *QI)(StubGI *, REFIID, void **);
    ULONG    (STDMETHODCALLTYPE *AddRef)(StubGI *);
    ULONG    (STDMETHODCALLTYPE *Release)(StubGI *);
    uint64_t (STDMETHODCALLTYPE *GetCurrentTimestamp)(StubGI *);
    HRESULT  (STDMETHODCALLTYPE *GetCurrentReading)(StubGI *, GIKind, StubDevice *, StubReading **);
    HRESULT  (STDMETHODCALLTYPE *GetNextReading)(StubGI *, StubReading *, GIKind, StubDevice *, StubReading **);
    HRESULT  (STDMETHODCALLTYPE *GetPreviousReading)(StubGI *, StubReading *, GIKind, StubDevice *, StubReading **);
    HRESULT  (STDMETHODCALLTYPE *RegisterReadingCallback)(StubGI *, StubDevice *, GIKind, void *, GIReadingCB, GIToken *);
    HRESULT  (STDMETHODCALLTYPE *RegisterDeviceCallback)(StubGI *, StubDevice *, GIKind, GIDevStatus, GIEnumKind, void *, GIDeviceCB, GIToken *);
    HRESULT  (STDMETHODCALLTYPE *RegisterSystemButtonCallback)(StubGI *, StubDevice *, GISysButtons, void *, GISysButtonCB, GIToken *);
    HRESULT  (STDMETHODCALLTYPE *RegisterKeyboardLayoutCallback)(StubGI *, StubDevice *, void *, GIKbLayoutCB, GIToken *);
    void     (STDMETHODCALLTYPE *StopCallback)(StubGI *, GIToken);
    bool     (STDMETHODCALLTYPE *UnregisterCallback)(StubGI *, GIToken);
    HRESULT  (STDMETHODCALLTYPE *CreateDispatcher)(StubGI *, IGameInputDispatcher **);
    HRESULT  (STDMETHODCALLTYPE *FindDeviceFromId)(StubGI *, const APP_LOCAL_DEVICE_ID *, StubDevice **);
    HRESULT  (STDMETHODCALLTYPE *FindDeviceFromPlatformString)(StubGI *, const WCHAR *, StubDevice **);
    void     (STDMETHODCALLTYPE *SetFocusPolicy)(StubGI *, GIFocusPolicy);
} StubGIVtbl;

struct StubGI {
    const StubGIVtbl *lpVtbl;
    LONG ref;
};

static StubReading *create_mouse_reading(void) {
    POINT cur;
    StubReading *r = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*r));
    if (!r) return NULL;
    r->lpVtbl = &g_reading_vtbl;
    r->ref = 1;
    r->kind = GI_KIND_MOUSE;
    r->device = &g_mouse_device;
    r->timestamp = GetTickCount64() * 10000ULL;

    GetCursorPos(&cur);
    r->mouse.positions = GI_RELPOS;
    r->mouse.absolutePositionX = cur.x;
    r->mouse.absolutePositionY = cur.y;

    if (GetAsyncKeyState(VK_LBUTTON) & 0x8000) r->mouse.buttons |= GI_MOUSE_LEFT;
    if (GetAsyncKeyState(VK_RBUTTON) & 0x8000) r->mouse.buttons |= GI_MOUSE_RIGHT;
    if (GetAsyncKeyState(VK_MBUTTON) & 0x8000) r->mouse.buttons |= GI_MOUSE_MIDDLE;
    if (GetAsyncKeyState(VK_XBUTTON1) & 0x8000) r->mouse.buttons |= GI_MOUSE_4;
    if (GetAsyncKeyState(VK_XBUTTON2) & 0x8000) r->mouse.buttons |= GI_MOUSE_5;

    return r;
}

static StubReading *create_gamepad_reading(void) {
    XI_STATE xi;
    StubReading *r;

    if (!pfn_XInputGetState || pfn_XInputGetState(0, &xi) != 0)
        return NULL;

    r = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*r));
    if (!r) return NULL;
    r->lpVtbl = &g_reading_vtbl;
    r->ref = 1;
    r->kind = GI_KIND_GAMEPAD;
    r->device = &g_gamepad_device;
    r->timestamp = GetTickCount64() * 10000ULL;

    r->gamepad.buttons = xi_to_gi_buttons(xi.pad.buttons);
    r->gamepad.leftTrigger = xi.pad.lt / 255.0f;
    r->gamepad.rightTrigger = xi.pad.rt / 255.0f;
    r->gamepad.leftThumbstickX = xi.pad.lx / 32767.0f;
    r->gamepad.leftThumbstickY = xi.pad.ly / 32767.0f;
    r->gamepad.rightThumbstickX = xi.pad.rx / 32767.0f;
    r->gamepad.rightThumbstickY = xi.pad.ry / 32767.0f;

    return r;
}

/* Poll thread: fires registered reading callbacks */
static DWORD WINAPI poll_thread(LPVOID arg) {
    (void)arg;
    TRACE("poll thread started");
    while (g_running) {
        for (int i = 0; i < MAX_READING_CBS; i++) {
            if (!g_reading_cbs[i].active || !g_reading_cbs[i].cb)
                continue;

            if (g_reading_cbs[i].kind & GI_KIND_MOUSE) {
                StubReading *r = create_mouse_reading();
                if (r) {
                    g_reading_cbs[i].cb(g_reading_cbs[i].token, g_reading_cbs[i].ctx, r, false);
                    r_release(r);
                }
            }
            if (g_reading_cbs[i].kind & GI_KIND_GAMEPAD) {
                StubReading *r = create_gamepad_reading();
                if (r) {
                    g_reading_cbs[i].cb(g_reading_cbs[i].token, g_reading_cbs[i].ctx, r, false);
                    r_release(r);
                }
            }
        }
        Sleep(4);
    }
    TRACE("poll thread exiting");
    return 0;
}

static void ensure_poll_thread(void) {
    if (g_poll_thread) return;
    g_running = TRUE;
    g_poll_thread = CreateThread(NULL, 0, poll_thread, NULL, 0, NULL);
}

static HRESULT STDMETHODCALLTYPE gi_qi(StubGI *s, REFIID i, void **o) {
    const unsigned *d = (const unsigned *)i;
    TRACE("IGameInput::QI iid={%08x-%04x-%04x-%02x%02x%02x%02x%02x%02x%02x%02x}",
        d[0], ((unsigned short*)i)[2], ((unsigned short*)i)[3],
        ((unsigned char*)i)[8], ((unsigned char*)i)[9], ((unsigned char*)i)[10], ((unsigned char*)i)[11],
        ((unsigned char*)i)[12], ((unsigned char*)i)[13], ((unsigned char*)i)[14], ((unsigned char*)i)[15]);
    *o = s; s->ref++; return S_OK;
}
static ULONG STDMETHODCALLTYPE gi_addref(StubGI *s) { return InterlockedIncrement(&s->ref); }
static ULONG STDMETHODCALLTYPE gi_release(StubGI *s) {
    ULONG r = InterlockedDecrement(&s->ref);
    if (r == 0) HeapFree(GetProcessHeap(), 0, s);
    return r;
}
static uint64_t STDMETHODCALLTYPE gi_ts(StubGI *s) { return GetTickCount64() * 10000ULL; }

static HRESULT STDMETHODCALLTYPE gi_curread(StubGI *s, GIKind kind, StubDevice *dev, StubReading **out) {
    if (!out) return E_POINTER;
    TRACE("GetCurrentReading kind=0x%x dev=%p", kind, (void *)dev);

    if (dev) {
        if (dev == &g_mouse_device && (kind & GI_KIND_MOUSE)) {
            *out = create_mouse_reading();
            return *out ? S_OK : E_OUTOFMEMORY;
        }
        if (dev == &g_gamepad_device && (kind & GI_KIND_GAMEPAD)) {
            *out = create_gamepad_reading();
            return *out ? S_OK : E_NOTIMPL;
        }
    }

    if (kind & GI_KIND_GAMEPAD) {
        StubReading *r = create_gamepad_reading();
        if (r) { *out = r; return S_OK; }
    }
    if (kind & GI_KIND_MOUSE) {
        *out = create_mouse_reading();
        return *out ? S_OK : E_OUTOFMEMORY;
    }

    *out = NULL;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE gi_nxtread(StubGI *s, StubReading *ref, GIKind k, StubDevice *d, StubReading **o) {
    TRACE("GetNextReading kind=0x%x", k);
    if (o) *o = NULL;
    return E_NOTIMPL;
}
static HRESULT STDMETHODCALLTYPE gi_prvread(StubGI *s, StubReading *ref, GIKind k, StubDevice *d, StubReading **o) {
    if (o) *o = NULL;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE gi_regrdc(StubGI *s, StubDevice *d, GIKind k, void *ctx, GIReadingCB cb, GIToken *t) {
    TRACE("RegisterReadingCallback kind=0x%x dev=%p cb=%p", k, (void *)d, (void *)cb);
    GIToken token = (GIToken)InterlockedIncrement(&g_next_token);
    if (t) *t = token;

    for (int i = 0; i < MAX_READING_CBS; i++) {
        if (!g_reading_cbs[i].active) {
            g_reading_cbs[i].cb = cb;
            g_reading_cbs[i].ctx = ctx;
            g_reading_cbs[i].kind = k;
            g_reading_cbs[i].dev = d;
            g_reading_cbs[i].token = token;
            g_reading_cbs[i].active = TRUE;
            ensure_poll_thread();
            break;
        }
    }
    return S_OK;
}

/* Async device callback delivery */
typedef struct {
    GIDeviceCB cb;
    GIToken token;
    void *ctx;
    GIKind kind;
} DevCBArgs;

static DWORD WINAPI dev_cb_thread(LPVOID arg) {
    DevCBArgs *a = (DevCBArgs *)arg;
    Sleep(50);
    uint64_t ts = GetTickCount64() * 10000ULL;
    if (a->kind & GI_KIND_MOUSE) {
        TRACE("  [async] firing mouse device callback");
        a->cb(a->token, a->ctx, &g_mouse_device, ts, GI_DEV_CONNECTED, 0);
    }
    if (a->kind & GI_KIND_GAMEPAD) {
        load_xinput();
        if (xi_available) {
            TRACE("  [async] firing gamepad device callback");
            a->cb(a->token, a->ctx, &g_gamepad_device, ts, GI_DEV_CONNECTED, 0);
        }
    }
    HeapFree(GetProcessHeap(), 0, a);
    return 0;
}

/* ================================================================
 * GetPointerInfo hook + WndProc subclass
 *
 * Wine generates WM_POINTER when EnableMouseInPointer(TRUE) is set,
 * but stubs GetPointerInfo → returns FALSE.  Microsoft.UI.Input.dll
 * calls GetPointerInfo inside its WM_POINTER handler and discards
 * the event when it fails.  We track pointer state from WM_POINTER
 * messages in our WndProc subclass and serve it from a hooked
 * GetPointerInfo.
 * ================================================================ */

/* WM_POINTER message IDs (guard against mingw already defining some) */
#ifndef WM_POINTERUPDATE
#define WM_POINTERUPDATE  0x0245
#endif
#ifndef WM_POINTERDOWN
#define WM_POINTERDOWN    0x0246
#endif
#ifndef WM_POINTERUP
#define WM_POINTERUP      0x0247
#endif
#ifndef WM_POINTERWHEEL
#define WM_POINTERWHEEL   0x024E
#endif
#ifndef WM_POINTERHWHEEL
#define WM_POINTERHWHEEL  0x024F
#endif

/* POINTER_FLAG values for POINTER_INFO.pointerFlags */
#define PF_NEW          0x00000001u
#define PF_INRANGE      0x00000002u
#define PF_INCONTACT    0x00000004u
#define PF_FIRSTBUTTON  0x00000010u
#define PF_SECONDBUTTON 0x00000020u
#define PF_THIRDBUTTON  0x00000040u
#define PF_PRIMARY      0x00002000u
#define PF_CONFIDENCE   0x00004000u
#define PF_DOWN         0x00010000u
#define PF_UPDATE       0x00020000u
#define PF_UP           0x00040000u

/* POINTER_BUTTON_CHANGE_TYPE */
#define PBC_NONE             0
#define PBC_FIRSTBUTTON_DOWN 1
#define PBC_FIRSTBUTTON_UP   2
#define PBC_SECONDBUTTON_DOWN 3
#define PBC_SECONDBUTTON_UP  4
#define PBC_THIRDBUTTON_DOWN 5
#define PBC_THIRDBUTTON_UP   6

/* Must match Windows SDK POINTER_INFO exactly */
typedef struct {
    DWORD  pointerType;               /* 0  */
    UINT32 pointerId;                 /* 4  */
    UINT32 frameId;                   /* 8  */
    DWORD  pointerFlags;              /* 12 */
    HANDLE sourceDevice;              /* 16 */
    HWND   hwndTarget;                /* 24 */
    POINT  ptPixelLocation;           /* 32 */
    POINT  ptHimetricLocation;        /* 40 */
    POINT  ptPixelLocationRaw;        /* 48 */
    POINT  ptHimetricLocationRaw;     /* 56 */
    DWORD  dwTime;                    /* 64 */
    UINT32 historyCount;              /* 68 */
    INT32  InputData;                 /* 72 */
    DWORD  dwKeyStates;               /* 76 */
    UINT64 PerformanceCount;          /* 80 */
    DWORD  ButtonChangeType;          /* 88 */
} StubPointerInfo;

static StubPointerInfo g_cur_pointer;
static UINT32 g_ptr_frame;
static volatile BOOL g_ptr_valid;

static void update_pointer_state(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    UINT32 pid = LOWORD(wp);
    WORD mflags = HIWORD(wp);
    LARGE_INTEGER qpc;

    memset(&g_cur_pointer, 0, sizeof(g_cur_pointer));
    g_cur_pointer.pointerType = 4; /* PT_MOUSE */
    g_cur_pointer.pointerId = pid;
    g_cur_pointer.frameId = ++g_ptr_frame;
    g_cur_pointer.hwndTarget = hwnd;
    g_cur_pointer.ptPixelLocation.x = (short)LOWORD(lp);
    g_cur_pointer.ptPixelLocation.y = (short)HIWORD(lp);
    g_cur_pointer.ptPixelLocationRaw = g_cur_pointer.ptPixelLocation;
    g_cur_pointer.ptHimetricLocation = g_cur_pointer.ptPixelLocation;
    g_cur_pointer.ptHimetricLocationRaw = g_cur_pointer.ptPixelLocation;
    g_cur_pointer.dwTime = GetTickCount();
    g_cur_pointer.historyCount = 1;

    QueryPerformanceCounter(&qpc);
    g_cur_pointer.PerformanceCount = qpc.QuadPart;

    DWORD pf = (DWORD)mflags;
    switch (msg) {
    case WM_POINTERDOWN:   pf |= PF_DOWN;   break;
    case WM_POINTERUP:     pf |= PF_UP;     break;
    case WM_POINTERUPDATE: pf |= PF_UPDATE; break;
    }
    g_cur_pointer.pointerFlags = pf;

    if (msg == WM_POINTERDOWN) {
        if (mflags & 0x0010) g_cur_pointer.ButtonChangeType = PBC_FIRSTBUTTON_DOWN;
        else if (mflags & 0x0020) g_cur_pointer.ButtonChangeType = PBC_SECONDBUTTON_DOWN;
        else if (mflags & 0x0040) g_cur_pointer.ButtonChangeType = PBC_THIRDBUTTON_DOWN;
    } else if (msg == WM_POINTERUP) {
        if (!(mflags & 0x0010)) g_cur_pointer.ButtonChangeType = PBC_FIRSTBUTTON_UP;
        else if (!(mflags & 0x0020)) g_cur_pointer.ButtonChangeType = PBC_SECONDBUTTON_UP;
    }

    g_ptr_valid = TRUE;
}

static int g_gpi_count = 0;

static BOOL WINAPI hooked_GetPointerInfo(UINT32 id, StubPointerInfo *info) {
    g_gpi_count++;
    if (!info || !g_ptr_valid || id != g_cur_pointer.pointerId) {
        TRACE("GetPointerInfo #%d FAIL id=%u (valid=%d cur_id=%u info=%p)",
            g_gpi_count, id, (int)g_ptr_valid, g_cur_pointer.pointerId, info);
        SetLastError(87 /* ERROR_INVALID_PARAMETER */);
        return FALSE;
    }
    *info = g_cur_pointer;
    TRACE("GetPointerInfo #%d id=%u type=%u flags=0x%x btn=%u xy=(%ld,%ld)",
        g_gpi_count, id, info->pointerType, info->pointerFlags,
        info->ButtonChangeType,
        info->ptPixelLocation.x, info->ptPixelLocation.y);
    return TRUE;
}

static void inline_hook(void *target, void *replacement, const char *name) {
    DWORD old_protect;
    if (VirtualProtect(target, 14, PAGE_EXECUTE_READWRITE, &old_protect)) {
        unsigned char *p = (unsigned char *)target;
        p[0] = 0x48; p[1] = 0xB8;
        *(void **)(p + 2) = replacement;
        p[10] = 0xFF; p[11] = 0xE0;
        VirtualProtect(target, 14, old_protect, &old_protect);
        FlushInstructionCache(GetCurrentProcess(), target, 14);
        TRACE("Hooked %s at %p", name, target);
    }
}

static BOOL WINAPI hooked_GetPointerDeviceRects(HANDLE device, RECT *deviceRect, RECT *displayRect) {
    int w = GetSystemMetrics(SM_CXSCREEN);
    int h = GetSystemMetrics(SM_CYSCREEN);
    if (deviceRect)  { deviceRect->left = 0;  deviceRect->top = 0;  deviceRect->right = w;  deviceRect->bottom = h; }
    if (displayRect) { displayRect->left = 0; displayRect->top = 0; displayRect->right = w; displayRect->bottom = h; }
    static int gpdr_count = 0;
    if (++gpdr_count <= 5)
        TRACE("GetPointerDeviceRects #%d -> %dx%d", gpdr_count, w, h);
    return TRUE;
}

static BOOL WINAPI hooked_GetPointerInputTransform(UINT32 pointerId, UINT32 historyCount, INPUT_TRANSFORM *transforms) {
    if (!transforms || !historyCount) { SetLastError(87); return FALSE; }
    for (UINT32 i = 0; i < historyCount; i++) {
        memset(&transforms[i], 0, sizeof(INPUT_TRANSFORM));
        transforms[i]._11 = 1.0f;
        transforms[i]._22 = 1.0f;
        transforms[i]._33 = 1.0f;
        transforms[i]._44 = 1.0f;
    }
    static int gpit_count = 0;
    if (++gpit_count <= 5)
        TRACE("GetPointerInputTransform #%d id=%u count=%u -> identity", gpit_count, pointerId, historyCount);
    return TRUE;
}

static BOOL WINAPI hooked_GetPointerTouchInfo(UINT32 id, void *info) {
    SetLastError(87);
    return FALSE;
}

/* Wine stubs user32!GetPointerType (returns FALSE). Bedrock probes pointer support
 * once a GameInput mouse device exists; the failing stub appears to trip the
 * "missing required component" path. Report PT_MOUSE (4) so the probe succeeds. */
static BOOL WINAPI hooked_GetPointerType(UINT32 id, DWORD *type) {
    if (type) *type = 4 /* PT_MOUSE */;
    static int n = 0;
    if (++n <= 5) TRACE("GetPointerType #%d id=%u -> PT_MOUSE", n, id);
    return TRUE;
}

/* IAT patching for DLLs that import unimplemented functions */
static void patch_module_iat(HMODULE module, const char *targetDll, const char *funcName, void *replacement) {
    BYTE *base = (BYTE *)module;
    IMAGE_DOS_HEADER *dos = (IMAGE_DOS_HEADER *)base;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return;
    IMAGE_NT_HEADERS *nt = (IMAGE_NT_HEADERS *)(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) return;

    DWORD rva = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
    if (!rva) return;
    IMAGE_IMPORT_DESCRIPTOR *imp = (IMAGE_IMPORT_DESCRIPTOR *)(base + rva);

    for (; imp->Name; imp++) {
        const char *name = (const char *)(base + imp->Name);
        if (_stricmp(name, targetDll) != 0) continue;

        IMAGE_THUNK_DATA *orig = (IMAGE_THUNK_DATA *)(base + imp->OriginalFirstThunk);
        IMAGE_THUNK_DATA *thunk = (IMAGE_THUNK_DATA *)(base + imp->FirstThunk);

        for (; orig->u1.AddressOfData; orig++, thunk++) {
            if (orig->u1.Ordinal & IMAGE_ORDINAL_FLAG64) continue;
            IMAGE_IMPORT_BY_NAME *ibn = (IMAGE_IMPORT_BY_NAME *)(base + (DWORD)orig->u1.AddressOfData);
            if (strcmp((char *)ibn->Name, funcName) == 0) {
                DWORD old;
                VirtualProtect(&thunk->u1.Function, sizeof(void *), PAGE_READWRITE, &old);
                thunk->u1.Function = (ULONGLONG)replacement;
                VirtualProtect(&thunk->u1.Function, sizeof(void *), old, &old);
                TRACE("IAT patched %s -> %p", funcName, replacement);
                return;
            }
        }
    }
    TRACE("IAT patch FAILED: %s not found in %s", funcName, targetDll);
}

static void install_pointer_hooks(void) {
    HMODULE u32 = GetModuleHandleA("user32.dll");
    if (!u32) return;

    typedef BOOL (WINAPI *PFN_EMIP)(BOOL);
    PFN_EMIP pEMIP = (PFN_EMIP)GetProcAddress(u32, "EnableMouseInPointer");
    if (pEMIP) {
        BOOL r = pEMIP(TRUE);
        TRACE("EnableMouseInPointer(TRUE) -> %d", r);
    }

    FARPROC fn;
    fn = GetProcAddress(u32, "GetPointerInfo");
    if (fn) inline_hook((void *)fn, (void *)hooked_GetPointerInfo, "GetPointerInfo");

    fn = GetProcAddress(u32, "GetPointerDeviceRects");
    if (fn) inline_hook((void *)fn, (void *)hooked_GetPointerDeviceRects, "GetPointerDeviceRects");

    fn = GetProcAddress(u32, "GetPointerTouchInfo");
    if (fn) inline_hook((void *)fn, (void *)hooked_GetPointerTouchInfo, "GetPointerTouchInfo");
    /* NOTE: do NOT hook GetPointerType — forcing PT_MOUSE trips Bedrock's GDK
     * component check and brings back the "missing required component" screen. */
}

/* Window subclass — tracks WM_POINTER state for GetPointerInfo */
static WNDPROC g_orig_wndproc = NULL;
static HWND g_target_hwnd = NULL;   /* set on subclass; used by the click injector */
static int g_move_count = 0;
static int g_click_count = 0;

typedef LONG_PTR (WINAPI *PFN_SWLP)(HWND, int, LONG_PTR);
typedef LONG_PTR (WINAPI *PFN_GWLP)(HWND, int);
typedef LRESULT (WINAPI *PFN_CWPW)(WNDPROC, HWND, UINT, WPARAM, LPARAM);
static PFN_CWPW pfn_CWPW = NULL;

static int g_ptr_move_count = 0;
static volatile BOOL g_iat_patched = FALSE;
static void patch_ui_input_iat(void);

static void **g_mouse_gate_ptr = NULL;

static LRESULT CALLBACK hooked_wndproc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (!g_iat_patched) {
        HMODULE uiInput = GetModuleHandleA("Microsoft.UI.Input.dll");
        if (uiInput) {
            g_iat_patched = TRUE;
            patch_ui_input_iat();
        }
    }

    if (msg >= 0x0245 && msg <= 0x0257) {
        update_pointer_state(hwnd, msg, wp, lp);
        if (msg == WM_POINTERDOWN || msg == WM_POINTERUP) {
            TRACE("WM_POINTER%s id=%u flags=0x%04x xy=(%d,%d)",
                msg == WM_POINTERDOWN ? "DOWN" : "UP",
                LOWORD(wp), HIWORD(wp),
                (int)(short)LOWORD(lp), (int)(short)HIWORD(lp));
        } else if (msg == WM_POINTERUPDATE) {
            g_ptr_move_count++;
            if (g_ptr_move_count <= 5)
                TRACE("WM_POINTERUPDATE #%d id=%u flags=0x%04x xy=(%d,%d)",
                    g_ptr_move_count, LOWORD(wp), HIWORD(wp),
                    (int)(short)LOWORD(lp), (int)(short)HIWORD(lp));
        }
    }

    if (msg >= WM_MOUSEFIRST && msg <= WM_MOUSELAST) {
        if (msg == WM_MOUSEMOVE) {
            g_move_count++;
            if (g_move_count <= 3)
                TRACE("WM_MOUSEMOVE #%d xy=(%d,%d)", g_move_count,
                    (int)(short)LOWORD(lp), (int)(short)HIWORD(lp));
        } else {
            g_click_count++;
            if (g_click_count <= 10)
                TRACE("WM_MOUSE 0x%04x #%d xy=(%d,%d)", msg, g_click_count,
                    (int)(short)LOWORD(lp), (int)(short)HIWORD(lp));
        }

        /* Gate bypass handled by permanent clear in dump_game_vtable */
    }

    if (!g_orig_wndproc) return DefWindowProcW(hwnd, msg, wp, lp);
    return pfn_CWPW(g_orig_wndproc, hwnd, msg, wp, lp);
}

static void dump_game_vtable(void) {
    void **game_obj_slot = (void **)0x14dce0898ULL;
    void *game_obj = *game_obj_slot;
    if (!game_obj) { TRACE("game_obj is NULL"); return; }

    void *handler_obj = *(void **)((char *)game_obj + 0x18);
    if (!handler_obj) { TRACE("handler_obj (game_obj+0x18) is NULL"); return; }

    void **vtable = *(void ***)handler_obj;
    TRACE("game_obj=%p handler=%p vtable=%p", game_obj, handler_obj, (void *)vtable);
    for (int i = 10; i <= 20; i++)
        TRACE("  vtable[%d] (offset 0x%x) = %p", i, i*8, vtable[i]);

    /* Check the field that gates WM_MOUSE handling:
     * game_obj->0x8 is params_struct->field[0] in the dispatch.
     * vtable[16] checks (game_obj->0x8)->0xC0 — if non-NULL, skips ALL mouse input. */
    void *field_0x8 = *(void **)((char *)game_obj + 0x8);
    TRACE("game_obj->0x8 = %p", field_0x8);
    if (field_0x8) {
        void **gate_ptr = (void **)((char *)field_0x8 + 0xC0);
        void *gate_field = *gate_ptr;
        if (gate_field) {
            TRACE("game_obj->0x8->0xC0 = %p — clearing to enable WM_MOUSE", gate_field);
            *gate_ptr = NULL;
        } else {
            TRACE("game_obj->0x8->0xC0 = NULL (mouse already OK)");
        }
    }
}

static void patch_ui_input_iat(void) {
    HMODULE uiInput = GetModuleHandleA("Microsoft.UI.Input.dll");
    if (!uiInput) { TRACE("Microsoft.UI.Input.dll not loaded"); return; }
    TRACE("Microsoft.UI.Input.dll at %p — patching IAT", (void *)uiInput);

    const char *apiset = "api-ms-win-rtcore-ntuser-wmpointer-l1-1-0.dll";
    patch_module_iat(uiInput, apiset, "GetPointerInfo",           (void *)hooked_GetPointerInfo);
    patch_module_iat(uiInput, apiset, "GetPointerDeviceRects",    (void *)hooked_GetPointerDeviceRects);
    patch_module_iat(uiInput, apiset, "GetPointerInputTransform", (void *)hooked_GetPointerInputTransform);
    patch_module_iat(uiInput, apiset, "GetPointerTouchInfo",      (void *)hooked_GetPointerTouchInfo);
}

static volatile LONG g_subclassed = 0;
static void subclass_game_window(void) {
    typedef HWND (WINAPI *PFN_FindWindow)(LPCSTR, LPCSTR);
    if (g_subclassed) return;  /* once only; set on success below */
    HMODULE u32 = GetModuleHandleA("user32.dll");
    if (!u32) return;
    PFN_FindWindow pFW = (PFN_FindWindow)GetProcAddress(u32, "FindWindowA");
    PFN_SWLP pfn_SWLP = (PFN_SWLP)GetProcAddress(u32, "SetWindowLongPtrW");
    pfn_CWPW = (PFN_CWPW)GetProcAddress(u32, "CallWindowProcW");
    if (!pFW || !pfn_SWLP || !pfn_CWPW) return;

    HWND target = pFW(NULL, "Minecraft");
    if (!target) { TRACE("Minecraft window not found"); return; }

    g_orig_wndproc = (WNDPROC)pfn_SWLP(target, GWLP_WNDPROC, (LONG_PTR)hooked_wndproc);
    g_target_hwnd = target;
    g_subclassed = 1;
    TRACE("Subclassed window %p, orig WndProc=%p", (void *)target, (void *)g_orig_wndproc);

    patch_ui_input_iat();
    dump_game_vtable();
}

/* Deferred installer: poll for the Minecraft window, then subclass it for cohtml clicks.
 * Lets this DLL deliver the UI-pointer fix WITHOUT being the GameInput provider — so it can
 * run alongside the real builtin gameinput.dll (which clears the GameInput error screen). */
static DWORD WINAPI deferred_pointer_thread(LPVOID unused) {
    typedef HWND (WINAPI *PFN_FindWindow)(LPCSTR, LPCSTR);
    HMODULE u32 = GetModuleHandleA("user32.dll");
    PFN_FindWindow pFW = u32 ? (PFN_FindWindow)GetProcAddress(u32, "FindWindowA") : NULL;
    (void)unused;
    for (int i = 0; i < 1200 && !g_subclassed; i++) {  /* up to ~120s */
        if (pFW && pFW(NULL, "Minecraft")) { subclass_game_window(); break; }
        Sleep(100);
    }
    return 0;
}

static HRESULT STDMETHODCALLTYPE gi_regdev(StubGI *s, StubDevice *dev, GIKind kind, GIDevStatus filter, GIEnumKind ek, void *ctx, GIDeviceCB cb, GIToken *token) {
    GIToken t = (GIToken)InterlockedIncrement(&g_next_token);
    if (token) *token = t;
    TRACE("RegisterDeviceCallback kind=0x%x filter=0x%x ek=%u cb=%p", kind, filter, ek, (void *)cb);

    if (kind & GI_KIND_MOUSE) subclass_game_window();

    if (!cb) return S_OK;

    DevCBArgs *a = HeapAlloc(GetProcessHeap(), 0, sizeof(*a));
    a->cb = cb; a->token = t; a->ctx = ctx; a->kind = kind;
    CreateThread(NULL, 0, dev_cb_thread, a, 0, NULL);
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE gi_regsys(StubGI *s, StubDevice *d, GISysButtons f, void *ctx, GISysButtonCB cb, GIToken *t) {
    TRACE("RegisterSystemButtonCallback");
    if (t) *t = (GIToken)InterlockedIncrement(&g_next_token);
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE gi_regkbl(StubGI *s, StubDevice *d, void *ctx, GIKbLayoutCB cb, GIToken *t) {
    TRACE("RegisterKeyboardLayoutCallback");
    if (t) *t = (GIToken)InterlockedIncrement(&g_next_token);
    return S_OK;
}
static void STDMETHODCALLTYPE gi_stopcb(StubGI *s, GIToken t) {
    TRACE("StopCallback token=%llu", (unsigned long long)t);
    for (int i = 0; i < MAX_READING_CBS; i++) {
        if (g_reading_cbs[i].active && g_reading_cbs[i].token == t)
            g_reading_cbs[i].active = FALSE;
    }
}
static bool STDMETHODCALLTYPE gi_unregcb(StubGI *s, GIToken t) {
    TRACE("UnregisterCallback token=%llu", (unsigned long long)t);
    gi_stopcb(s, t);
    return true;
}
static HRESULT STDMETHODCALLTYPE gi_disp(StubGI *s, IGameInputDispatcher **o) {
    TRACE("CreateDispatcher");
    if (o) *o = NULL;
    return E_NOTIMPL;
}
static HRESULT STDMETHODCALLTYPE gi_findid(StubGI *s, const APP_LOCAL_DEVICE_ID *id, StubDevice **o) {
    TRACE("FindDeviceFromId");
    if (o) *o = NULL;
    return E_NOTIMPL;
}
static HRESULT STDMETHODCALLTYPE gi_findstr(StubGI *s, const WCHAR *v, StubDevice **o) {
    TRACE("FindDeviceFromPlatformString");
    if (o) *o = NULL;
    return E_NOTIMPL;
}
static void STDMETHODCALLTYPE gi_focus(StubGI *s, GIFocusPolicy p) {
    TRACE("SetFocusPolicy %u", p);
}

static const StubGIVtbl g_gi_vtbl = {
    gi_qi, gi_addref, gi_release,
    gi_ts, gi_curread, gi_nxtread, gi_prvread,
    gi_regrdc, gi_regdev, gi_regsys, gi_regkbl,
    gi_stopcb, gi_unregcb,
    gi_disp, gi_findid, gi_findstr, gi_focus,
};

static HRESULT make_gi(void **out) {
    StubGI *gi;
    init_devices();
    load_xinput();
    gi = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*gi));
    if (!gi) return E_OUTOFMEMORY;
    gi->lpVtbl = &g_gi_vtbl;
    gi->ref = 1;
    *out = gi;
    TRACE("GameInput created at %p", (void *)gi);
    return S_OK;
}

#ifndef POINTERHOOK_ONLY
__declspec(dllexport)
#endif
HRESULT __stdcall GameInputCreate(void **out) {
    TRACE("GameInputCreate called");
    return make_gi(out);
}
HRESULT __stdcall GameInputInitialize(REFIID riid, void **out) {
    TRACE("GameInputInitialize called (not exported — game should use GameInputCreate)");
    (void)riid;
    return make_gi(out);
}
__declspec(dllexport) HRESULT __stdcall DllCanUnloadNow(void) { return S_FALSE; }
__declspec(dllexport) HRESULT __stdcall DllGetClassObject(REFCLSID c, REFIID r, void **o) {
    if (o) *o = NULL;
    return CLASS_E_CLASSNOTAVAILABLE;
}

/* ------------------------------------------------------------------
 * Scripted click injector
 *
 * XTEST/synthetic input does NOT reach the XWayland window under
 * mutter-Wayland (pointer warp works, button press is dropped), so we
 * cannot drive the cohtml menu from the host.  Instead we post a proper
 * WM_POINTER sequence straight to the subclassed window — the same path
 * the wndproc already feeds to cohtml via GetPointerInfo.  No Wayland,
 * no XTEST involved.
 *
 * Command file: Z:\tmp\mc-inject.txt  (= /tmp/mc-inject.txt), one line
 * "<screenX> <screenY>".  The file is consumed (deleted) once handled.
 *
 * wparam HIWORD carries the low word of POINTER_INFO.pointerFlags, which
 * update_pointer_state() copies verbatim (then ORs PF_DOWN/PF_UP):
 *   0x2002 = PF_INRANGE|PF_PRIMARY                       (hover / up)
 *   0x2016 = PF_INRANGE|PF_INCONTACT|PF_PRIMARY|PF_FIRSTBUTTON (down)
 * ------------------------------------------------------------------ */
static void inject_click(HWND hwnd, int x, int y) {
    typedef BOOL (WINAPI *PFN_SCP)(int, int);
    typedef UINT (WINAPI *PFN_SI)(UINT, INPUT *, int);
    HMODULE u32 = GetModuleHandleA("user32.dll");
    PFN_SCP pSetCursorPos = u32 ? (PFN_SCP)GetProcAddress(u32, "SetCursorPos") : NULL;
    PFN_SI  pSendInput    = u32 ? (PFN_SI)GetProcAddress(u32, "SendInput") : NULL;
    (void)hwnd;

    /* The cohtml Ore UI mouse comes from the WineGDK GameInput mouse device, whose
     * read path uses GetCursorPos() (absolute position) + GetAsyncKeyState(VK_LBUTTON)
     * (button state).  Both are Wine-internal, so SetCursorPos + SendInput drive them
     * directly — no Wayland / XTEST involved (XTEST button events are dropped by mutter).
     * x,y are screen pixels. */
    int sw = GetSystemMetrics(SM_CXSCREEN);
    int sh = GetSystemMetrics(SM_CYSCREEN);
    if (sw <= 0) sw = 1920;
    if (sh <= 0) sh = 1080;

    if (pSetCursorPos) pSetCursorPos(x, y);
    Sleep(40);

    if (pSendInput) {
        INPUT in[3];
        memset(in, 0, sizeof(in));
        LONG ax = (LONG)((x * 65535) / (sw - 1));
        LONG ay = (LONG)((y * 65535) / (sh - 1));
        in[0].type = INPUT_MOUSE;
        in[0].mi.dx = ax; in[0].mi.dy = ay;
        in[0].mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
        pSendInput(1, &in[0], sizeof(INPUT));
        Sleep(30);
        memset(in, 0, sizeof(in));
        in[0].type = INPUT_MOUSE; in[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
        pSendInput(1, &in[0], sizeof(INPUT));
        Sleep(70);
        in[0].mi.dwFlags = MOUSEEVENTF_LEFTUP;
        pSendInput(1, &in[0], sizeof(INPUT));
    }

    TRACE("Injected SendInput click at screen=(%d,%d) [scr %dx%d] SCP=%p SI=%p",
          x, y, sw, sh, (void *)pSetCursorPos, (void *)pSendInput);
}

static DWORD WINAPI injector_thread(LPVOID unused) {
    (void)unused;
    while (g_running) {
        Sleep(150);
        if (!g_target_hwnd) continue;
        FILE *f = fopen("Z:\\tmp\\mc-inject.txt", "r");
        if (!f) continue;
        int x = -1, y = -1;
        int ok = fscanf(f, "%d %d", &x, &y);
        fclose(f);
        remove("Z:\\tmp\\mc-inject.txt");
        if (ok == 2 && x >= 0 && y >= 0)
            inject_click(g_target_hwnd, x, y);
        else
            TRACE("injector: bad command (ok=%d)", ok);
    }
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved) {
    if (reason == DLL_PROCESS_ATTACH) {
        TRACE("DLL loaded");
        g_running = TRUE;
        install_pointer_hooks();
        CreateThread(NULL, 0, deferred_pointer_thread, NULL, 0, NULL);
        CreateThread(NULL, 0, injector_thread, NULL, 0, NULL);
    } else if (reason == DLL_PROCESS_DETACH) {
        g_running = FALSE;
    }
    return TRUE;
}
