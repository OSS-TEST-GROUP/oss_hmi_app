// homebar — floating "home" button overlay for AGL (F010).
//
// A plain xdg_toplevel Wayland client (app_id "homebar") that draws a small
// "home" button. It is shown+floated on top of the active app via
// `agl-shell-activator -a activate/-a float -p homebar` (done by the launcher
// script). agl-shell allows only one primary shell client (grpc-server) and one
// ext/doas client (flutter-auto), so a 3rd shell client is impossible — hence a
// NORMAL floated app instead of an agl-shell panel.
//
// On tap/click it returns to the launcher by asking the agl-shell gRPC service
// (127.0.0.1:14005) to activate "hmi_launcher", via grpcurl.
//
// The compositor may configure the surface at various sizes (it likes to
// maximize). We honour whatever size it gives us: the window is filled with a
// transparent background and the actual button is drawn in the top-left
// BTN_W x BTN_H area, with the input region limited to that button — so when
// floated on top of rviz2, taps outside the button fall through to rviz2.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/mman.h>
#include <wayland-client.h>
#include "xdg-shell-client-protocol.h"

#define BTN_W 240
#define BTN_H 72
#define HOME_APP_ID "hmi_launcher"

static struct wl_display    *display;
static struct wl_compositor *compositor;
static struct wl_shm        *shm;
static struct wl_seat       *seat;
static struct xdg_wm_base   *wm_base;

static struct wl_surface   *surface;
static struct xdg_surface  *xsurface;
static struct xdg_toplevel *xtoplevel;
static int cfg_w = 0, cfg_h = 0;         // last configured size (0 = we choose)
static int cur_w = 0, cur_h = 0;         // current buffer size
static uint32_t last_home_ms = 0;

// ---- ARGB8888 drawing -------------------------------------------------------

static void draw_button(uint32_t *px, int w, int h)
{
    const uint32_t clear  = 0x00000000;  // transparent (outside the button)
    const uint32_t accent = 0xFFF97316;  // orange
    const uint32_t white  = 0xFFFFFFFF;
    const uint32_t border = 0xFFC2410C;

    for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++) {
            uint32_t c = clear;
            if (x < BTN_W && y < BTN_H) {                // the button rectangle
                c = accent;
                if (x < 3 || x >= BTN_W - 3 || y < 3 || y >= BTN_H - 3) c = border;
            }
            px[y * w + x] = c;
        }

    int cx = 56, cy = BTN_H / 2;
    for (int y = cy - 2; y < cy + 13; y++)               // house body
        for (int x = cx - 16; x < cx + 16; x++)
            if (x >= 0 && x < w && y >= 0 && y < h) px[y*w+x] = white;
    for (int y = cy - 18; y < cy - 2; y++) {             // roof
        int half = ((y - (cy - 18)) * 22) / 16;
        for (int x = cx - half; x <= cx + half; x++)
            if (x >= 0 && x < w && y >= 0 && y < h) px[y*w+x] = white;
    }
    for (int y = cy + 3; y < cy + 13; y++)               // door
        for (int x = cx - 4; x < cx + 4; x++)
            if (x >= 0 && x < w && y >= 0 && y < h) px[y*w+x] = accent;
    for (int k = 0; k < 18; k++) {                       // chevron hint
        int xx = 150 + k;
        if (xx < BTN_W) {
            if (cy - k >= 0) { px[(cy-k)*w+xx] = white; }
            if (cy + k < h)  { px[(cy+k)*w+xx] = white; }
        }
    }
}

static struct wl_buffer *make_buffer(int w, int h)
{
    int stride = w * 4, size = stride * h;
    int fd = memfd_create("homebar", 0);
    if (fd < 0) { perror("memfd_create"); return NULL; }
    if (ftruncate(fd, size) < 0) { perror("ftruncate"); close(fd); return NULL; }
    uint32_t *px = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (px == MAP_FAILED) { perror("mmap"); close(fd); return NULL; }
    draw_button(px, w, h);
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, size);
    struct wl_buffer *b = wl_shm_pool_create_buffer(pool, 0, w, h, stride,
                                                    WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    munmap(px, size);
    close(fd);
    return b;
}

// ---- return to launcher -----------------------------------------------------

static void go_home(uint32_t time_ms)
{
    if (time_ms && last_home_ms && (time_ms - last_home_ms) < 800) return;
    last_home_ms = time_ms;
    fprintf(stderr, "[homebar] -> activate %s via grpc :14005\n", HOME_APP_ID);
    if (fork() == 0) {
        execlp("sh", "sh", "-c",
            "grpcurl -plaintext -d '{\"app_id\":\"hmi_launcher\",\"output_name\":\"DP-1\"}' "
            "127.0.0.1:14005 agl_shell_ipc.AglShellManagerService/ActivateApp 2>/dev/null "
            "|| grpcurl -plaintext -import-path /opt -proto agl_shell.proto "
            "-d '{\"app_id\":\"hmi_launcher\",\"output_name\":\"DP-1\"}' "
            "127.0.0.1:14005 agl_shell_ipc.AglShellManagerService/ActivateApp",
            (char *)NULL);
        _exit(127);
    }
}

static int in_button(int x, int y) { return x >= 0 && x < BTN_W && y >= 0 && y < BTN_H; }

// ---- input ------------------------------------------------------------------

static void t_down(void *d, struct wl_touch *t, uint32_t s, uint32_t tm,
                   struct wl_surface *su, int32_t id, wl_fixed_t x, wl_fixed_t y)
{ (void)d;(void)t;(void)s;(void)id; if (su == surface && in_button(wl_fixed_to_int(x), wl_fixed_to_int(y))) go_home(tm); }
static void t_up(void *d, struct wl_touch *t, uint32_t s, uint32_t tm, int32_t id){ (void)d;(void)t;(void)s;(void)tm;(void)id; }
static void t_motion(void *d, struct wl_touch *t, uint32_t tm, int32_t id, wl_fixed_t x, wl_fixed_t y){ (void)d;(void)t;(void)tm;(void)id;(void)x;(void)y; }
static void t_frame(void *d, struct wl_touch *t){ (void)d;(void)t; }
static void t_cancel(void *d, struct wl_touch *t){ (void)d;(void)t; }
static const struct wl_touch_listener touch_listener = { t_down, t_up, t_motion, t_frame, t_cancel };

static struct wl_surface *ptr_surf; static int ptr_x, ptr_y;
static void p_enter(void *d, struct wl_pointer *p, uint32_t s, struct wl_surface *su, wl_fixed_t x, wl_fixed_t y){ (void)d;(void)p;(void)s; ptr_surf = su; ptr_x = wl_fixed_to_int(x); ptr_y = wl_fixed_to_int(y); }
static void p_leave(void *d, struct wl_pointer *p, uint32_t s, struct wl_surface *su){ (void)d;(void)p;(void)s;(void)su; ptr_surf = NULL; }
static void p_motion(void *d, struct wl_pointer *p, uint32_t t, wl_fixed_t x, wl_fixed_t y){ (void)d;(void)p;(void)t; ptr_x = wl_fixed_to_int(x); ptr_y = wl_fixed_to_int(y); }
static void p_button(void *d, struct wl_pointer *p, uint32_t s, uint32_t t, uint32_t btn, uint32_t st)
{ (void)d;(void)p;(void)s;(void)btn; if (st == WL_POINTER_BUTTON_STATE_PRESSED && ptr_surf == surface && in_button(ptr_x, ptr_y)) go_home(t); }
static void p_axis(void *d, struct wl_pointer *p, uint32_t t, uint32_t a, wl_fixed_t v){ (void)d;(void)p;(void)t;(void)a;(void)v; }
static const struct wl_pointer_listener ptr_listener = { p_enter, p_leave, p_motion, p_button, p_axis };

static void seat_caps(void *d, struct wl_seat *s, uint32_t caps)
{ (void)d;
  if (caps & WL_SEAT_CAPABILITY_TOUCH)   wl_touch_add_listener(wl_seat_get_touch(s), &touch_listener, NULL);
  if (caps & WL_SEAT_CAPABILITY_POINTER) wl_pointer_add_listener(wl_seat_get_pointer(s), &ptr_listener, NULL); }
static void seat_name(void *d, struct wl_seat *s, const char *n){ (void)d;(void)s;(void)n; }
static const struct wl_seat_listener seat_listener = { seat_caps, seat_name };

// ---- xdg-shell --------------------------------------------------------------

static void wm_ping(void *d, struct xdg_wm_base *b, uint32_t serial){ (void)d; xdg_wm_base_pong(b, serial); }
static const struct xdg_wm_base_listener wm_listener = { wm_ping };

static void apply_buffer(void)
{
    int w = cfg_w > 0 ? cfg_w : BTN_W;
    int h = cfg_h > 0 ? cfg_h : BTN_H;
    if (w == cur_w && h == cur_h) return;   // no size change
    cur_w = w; cur_h = h;
    struct wl_buffer *b = make_buffer(w, h);
    if (!b) return;
    // Window geometry + input limited to the button rectangle.
    xdg_surface_set_window_geometry(xsurface, 0, 0, w, h);
    struct wl_region *reg = wl_compositor_create_region(compositor);
    wl_region_add(reg, 0, 0, BTN_W < w ? BTN_W : w, BTN_H < h ? BTN_H : h);
    wl_surface_set_input_region(surface, reg);
    wl_region_destroy(reg);
    wl_surface_attach(surface, b, 0, 0);
    wl_surface_damage(surface, 0, 0, w, h);
}

static void xsurf_configure(void *d, struct xdg_surface *xs, uint32_t serial)
{
    (void)d;
    xdg_surface_ack_configure(xs, serial);
    apply_buffer();
    wl_surface_commit(surface);
    // Floating/placement is done externally by homebar-up.sh (host CLI), which
    // is more reliable than an in-container grpc call while the surface is still
    // settling its initial configure.
}
static const struct xdg_surface_listener xsurf_listener = { xsurf_configure };

static void top_configure(void *d, struct xdg_toplevel *t, int32_t w, int32_t h, struct wl_array *st)
{ (void)d;(void)t;(void)st; cfg_w = w; cfg_h = h; fprintf(stderr, "[homebar] configure %dx%d\n", w, h); }
static void top_close(void *d, struct xdg_toplevel *t){ (void)d;(void)t; }
static const struct xdg_toplevel_listener top_listener = { top_configure, top_close };

// ---- registry ---------------------------------------------------------------

static void reg_global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver)
{
    (void)d;(void)ver;
    if (!strcmp(iface, "wl_compositor")) compositor = wl_registry_bind(r, name, &wl_compositor_interface, 1);
    else if (!strcmp(iface, "wl_shm"))   shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
    else if (!strcmp(iface, "wl_seat")) { seat = wl_registry_bind(r, name, &wl_seat_interface, 1); wl_seat_add_listener(seat, &seat_listener, NULL); }
    else if (!strcmp(iface, "xdg_wm_base")) { wm_base = wl_registry_bind(r, name, &xdg_wm_base_interface, 1); xdg_wm_base_add_listener(wm_base, &wm_listener, NULL); }
}
static void reg_remove(void *d, struct wl_registry *r, uint32_t name){ (void)d;(void)r;(void)name; }
static const struct wl_registry_listener reg_listener = { reg_global, reg_remove };

int main(void)
{
    signal(SIGCHLD, SIG_IGN);
    display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "[homebar] cannot connect to wayland\n"); return 1; }

    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &reg_listener, NULL);
    wl_display_roundtrip(display);

    if (!compositor || !shm || !wm_base) { fprintf(stderr, "[homebar] missing globals\n"); return 1; }

    surface   = wl_compositor_create_surface(compositor);
    xsurface  = xdg_wm_base_get_xdg_surface(wm_base, surface);
    xdg_surface_add_listener(xsurface, &xsurf_listener, NULL);
    xtoplevel = xdg_surface_get_toplevel(xsurface);
    xdg_toplevel_add_listener(xtoplevel, &top_listener, NULL);
    xdg_toplevel_set_app_id(xtoplevel, "homebar");
    xdg_toplevel_set_title(xtoplevel, "home");
    xdg_toplevel_set_min_size(xtoplevel, BTN_W, BTN_H);   // fixed-size hint
    xdg_toplevel_set_max_size(xtoplevel, BTN_W, BTN_H);
    wl_surface_commit(surface);                            // -> first configure

    fprintf(stderr, "[homebar] app_id=homebar up (button %dx%d)\n", BTN_W, BTN_H);
    while (wl_display_dispatch(display) != -1) { }
    return 0;
}
