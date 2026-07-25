// R015: AGL Shell Protocol Registration Example
// Template code for RViz2 agl-shell integration
// NOTE: This is a standalone example, NOT compiled in harness
// Actual integration: Adapt to RViz2 main.cpp structure

#include <iostream>
#include <cstring>
#include <cstdlib>
#include <wayland-client.h>

// Include generated agl-shell protocol header
// Generated via: wayland-scanner client-header agl-shell.xml agl-shell-client-protocol.h
#ifdef RVIZ_AGL_SHELL_ENABLED
#include "agl-shell-client-protocol.h"
#endif

// Fallback xdg-shell protocol (always available)
#include <xdg-shell-client-protocol.h>

class AglShellRegistrar {
public:
    AglShellRegistrar(const char* app_id, const char* role)
        : app_id_(app_id)
        , role_(role)
        , display_(nullptr)
        , registry_(nullptr)
        , compositor_(nullptr)
        , agl_shell_(nullptr)
        , xdg_wm_base_(nullptr)
        , surface_(nullptr)
    {}

    bool connect() {
        display_ = wl_display_connect(nullptr);
        if (!display_) {
            std::cerr << "[ERROR] Failed to connect to Wayland display\n";
            return false;
        }

        registry_ = wl_display_get_registry(display_);
        wl_registry_add_listener(registry_, &registry_listener_, this);
        wl_display_roundtrip(display_);

        if (!compositor_) {
            std::cerr << "[ERROR] wl_compositor not available\n";
            return false;
        }

        return true;
    }

    bool register_with_hmi_manager() {
#ifdef RVIZ_AGL_SHELL_ENABLED
        if (agl_shell_) {
            std::cout << "[INFO] AGL shell detected, registering with HMI Manager\n";

            // Create Wayland surface
            surface_ = wl_compositor_create_surface(compositor_);
            if (!surface_) {
                std::cerr << "[ERROR] Failed to create Wayland surface\n";
                return false;
            }

            // Register app_id with AGL compositor
            // This tells HMI Manager that we are a managed application
            agl_shell_set_app_id(agl_shell_, app_id_);

            // Request window placement in designated role/slot
            // Roles: "normal", "fullscreen", "split-left", "split-right", "panel"
            agl_shell_set_activate_app(agl_shell_, app_id_, role_, surface_);

            // Mark application as ready
            agl_shell_ready(agl_shell_);

            // Wait for compositor response
            wl_display_roundtrip(display_);

            std::cout << "[INFO] Registered with AGL HMI Manager\n";
            std::cout << "  app_id: " << app_id_ << "\n";
            std::cout << "  role: " << role_ << "\n";

            return true;
        }
#endif

        // Fallback: xdg-shell (generic Wayland)
        if (xdg_wm_base_) {
            std::cout << "[INFO] AGL shell not available, using xdg-shell fallback\n";

            surface_ = wl_compositor_create_surface(compositor_);
            if (!surface_) {
                std::cerr << "[ERROR] Failed to create Wayland surface\n";
                return false;
            }

            struct xdg_surface* xdg_surface = xdg_wm_base_get_xdg_surface(xdg_wm_base_, surface_);
            struct xdg_toplevel* xdg_toplevel = xdg_surface_get_toplevel(xdg_surface);

            xdg_toplevel_set_title(xdg_toplevel, "RViz2");
            xdg_toplevel_set_app_id(xdg_toplevel, app_id_);

            wl_surface_commit(surface_);
            wl_display_roundtrip(display_);

            std::cout << "[INFO] Registered with xdg-shell\n";
            std::cout << "  app_id: " << app_id_ << "\n";

            return true;
        }

        std::cerr << "[ERROR] No Wayland shell protocol available (neither agl-shell nor xdg-shell)\n";
        return false;
    }

    void disconnect() {
        if (surface_) {
            wl_surface_destroy(surface_);
        }
        if (registry_) {
            wl_registry_destroy(registry_);
        }
        if (display_) {
            wl_display_disconnect(display_);
        }
    }

private:
    static void registry_handler(void* data, struct wl_registry* registry,
                                   uint32_t name, const char* interface,
                                   uint32_t version) {
        auto* self = static_cast<AglShellRegistrar*>(data);

        std::cout << "[DEBUG] Wayland global: " << interface << " (version " << version << ")\n";

        if (strcmp(interface, "wl_compositor") == 0) {
            self->compositor_ = static_cast<struct wl_compositor*>(
                wl_registry_bind(registry, name, &wl_compositor_interface, 4));
        }
        else if (strcmp(interface, "xdg_wm_base") == 0) {
            self->xdg_wm_base_ = static_cast<struct xdg_wm_base*>(
                wl_registry_bind(registry, name, &xdg_wm_base_interface, 1));
        }
#ifdef RVIZ_AGL_SHELL_ENABLED
        else if (strcmp(interface, "agl_shell") == 0) {
            self->agl_shell_ = static_cast<struct agl_shell*>(
                wl_registry_bind(registry, name, &agl_shell_interface, 1));
            std::cout << "[INFO] AGL shell protocol bound (version " << version << ")\n";
        }
#endif
    }

    static void registry_remover(void* data, struct wl_registry* registry, uint32_t name) {
        // Global removed (not handled in this example)
    }

    const char* app_id_;
    const char* role_;

    struct wl_display* display_;
    struct wl_registry* registry_;
    struct wl_compositor* compositor_;
    struct wl_surface* surface_;

#ifdef RVIZ_AGL_SHELL_ENABLED
    struct agl_shell* agl_shell_;
#endif
    struct xdg_wm_base* xdg_wm_base_;

    static const struct wl_registry_listener registry_listener_;
};

const struct wl_registry_listener AglShellRegistrar::registry_listener_ = {
    AglShellRegistrar::registry_handler,
    AglShellRegistrar::registry_remover
};

int main(int argc, char* argv[]) {
    const char* app_id = std::getenv("APP_ID");
    if (!app_id) {
        app_id = "org.agl.rviz2";
    }

    const char* role = std::getenv("RVIZ_AGL_ROLE");
    if (!role) {
        role = "normal";
    }

    std::cout << "=== AGL Shell Registration Example ===\n";
    std::cout << "app_id: " << app_id << "\n";
    std::cout << "role: " << role << "\n\n";

    AglShellRegistrar registrar(app_id, role);

    if (!registrar.connect()) {
        std::cerr << "[ERROR] Wayland connection failed\n";
        return 1;
    }

    if (!registrar.register_with_hmi_manager()) {
        std::cerr << "[ERROR] HMI Manager registration failed\n";
        registrar.disconnect();
        return 1;
    }

    std::cout << "\n[SUCCESS] RViz2 registered with AGL HMI Manager\n";
    std::cout << "Press Ctrl+C to exit\n";

    // Keep running (in real RViz2, this would be the main event loop)
    while (true) {
        // wl_display_dispatch(display_) in real application
        sleep(1);
    }

    registrar.disconnect();
    return 0;
}

/* ===== Build Instructions (standalone example) =====

# Prerequisites: Install Wayland development packages
sudo apt-get install -y libwayland-dev wayland-protocols

# Generate agl-shell protocol bindings (if RVIZ_AGL_SHELL_ENABLED defined)
# wget https://git.automotivelinux.org/src/agl-compositor/plain/protocol/agl-shell.xml
# wayland-scanner client-header agl-shell.xml agl-shell-client-protocol.h
# wayland-scanner private-code agl-shell.xml agl-shell-protocol.c

# Compile (xdg-shell only, no agl-shell)
g++ -o agl_shell_register agl_shell_register.cpp \
    $(pkg-config --cflags --libs wayland-client) \
    -std=c++11

# Compile (with agl-shell support)
# g++ -o agl_shell_register agl_shell_register.cpp agl-shell-protocol.c \
#     $(pkg-config --cflags --libs wayland-client) \
#     -DRVIZ_AGL_SHELL_ENABLED \
#     -std=c++11

# Run
export WAYLAND_DISPLAY=wayland-0
export APP_ID=org.agl.rviz2
export RVIZ_AGL_ROLE=normal
./agl_shell_register

===== Expected Output =====

=== AGL Shell Registration Example ===
app_id: org.agl.rviz2
role: normal

[DEBUG] Wayland global: wl_compositor (version 4)
[DEBUG] Wayland global: xdg_wm_base (version 1)
[DEBUG] Wayland global: agl_shell (version 1)
[INFO] AGL shell protocol bound (version 1)
[INFO] AGL shell detected, registering with HMI Manager
[INFO] Registered with AGL HMI Manager
  app_id: org.agl.rviz2
  role: normal

[SUCCESS] RViz2 registered with AGL HMI Manager
Press Ctrl+C to exit

*/
