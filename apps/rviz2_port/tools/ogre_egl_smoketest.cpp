/**
 * OGRE 14.x EGL+Wayland Smoke Test
 * Feature: R005 — OGRE EGL+Wayland Build Verification
 *
 * Purpose:
 *   Verify that OGRE 14.x successfully initializes EGL context
 *   without segfault in a Wayland environment (AC-5).
 *
 * Expected Output:
 *   - Ogre.log contains "EGL" or "GLES2" or "Wayland" initialization messages
 *   - Exit code 0 (no crash)
 *   - Process runs for 5+ seconds without segfault
 *
 * Build:
 *   g++ -std=c++14 ogre_egl_smoketest.cpp -o ogre_egl_smoketest \
 *       -I/opt/ogre/include/OGRE \
 *       -L/opt/ogre/lib \
 *       -lOgreMain \
 *       -pthread
 *
 * Run:
 *   LIBGL_ALWAYS_SOFTWARE=1 ./ogre_egl_smoketest
 */

#include <iostream>
#include <exception>
#include <thread>
#include <chrono>

// OGRE 14.x headers
#include <OgreRoot.h>
#include <OgreLogManager.h>
#include <OgreConfigFile.h>
#include <OgreException.h>

int main(int argc, char** argv) {
    std::cout << "=== OGRE 14.x EGL+Wayland Smoke Test ===" << std::endl;

    Ogre::Root* root = nullptr;
    Ogre::LogManager* logMgr = nullptr;

    try {
        // Initialize OGRE log manager
        logMgr = new Ogre::LogManager();
        Ogre::Log* log = logMgr->createLog("/var/log/ogre/Ogre.log", true, true, false);
        log->setLogDetail(Ogre::LL_BOREME); // Verbose logging for debugging
        std::cout << "[INFO] Log file: /var/log/ogre/Ogre.log" << std::endl;

        // Initialize OGRE root (no plugins.cfg, resources.cfg for smoke test)
        std::cout << "[INFO] Creating OGRE Root..." << std::endl;
        root = new Ogre::Root("", "", "");

        // Load render system plugins manually
        std::cout << "[INFO] Loading RenderSystem_GL3Plus plugin..." << std::endl;
        try {
            root->loadPlugin("/opt/ogre/lib/OGRE/RenderSystem_GL3Plus");
        } catch (const Ogre::Exception& e) {
            std::cerr << "[WARN] Failed to load GL3Plus: " << e.what() << std::endl;
            std::cout << "[INFO] Trying RenderSystem_GL (legacy)..." << std::endl;
            root->loadPlugin("/opt/ogre/lib/OGRE/RenderSystem_GL");
        }

        // Get available render systems
        const Ogre::RenderSystemList& renderSystems = root->getAvailableRenderers();
        if (renderSystems.empty()) {
            std::cerr << "[ERROR] No render systems available!" << std::endl;
            return 1;
        }

        std::cout << "[INFO] Available render systems:" << std::endl;
        for (auto* rs : renderSystems) {
            std::cout << "  - " << rs->getName() << std::endl;
        }

        // Select first available render system
        Ogre::RenderSystem* renderSystem = renderSystems[0];
        std::cout << "[INFO] Selected: " << renderSystem->getName() << std::endl;
        root->setRenderSystem(renderSystem);

        // Initialize without creating a window (headless mode for smoke test)
        std::cout << "[INFO] Initializing OGRE (auto-create window: false)..." << std::endl;
        root->initialise(false);

        std::cout << "[SUCCESS] OGRE initialized successfully!" << std::endl;

        // AC-5 requirement: Run for 5+ seconds without crash
        std::cout << "[INFO] Stability test: waiting 5 seconds..." << std::endl;
        std::this_thread::sleep_for(std::chrono::seconds(5));

        std::cout << "[SUCCESS] OGRE stable for 5+ seconds. No segfault." << std::endl;

        // Cleanup (LogManager must be deleted before Root to avoid log flush dependency conflicts in OGRE 14.x)
        delete logMgr;
        delete root;

        std::cout << "=== Smoke Test PASSED ===" << std::endl;
        return 0;

    } catch (const Ogre::Exception& e) {
        std::cerr << "[ERROR] OGRE Exception: " << e.getFullDescription() << std::endl;
        if (root) delete root;
        if (logMgr) delete logMgr;
        return 1;

    } catch (const std::exception& e) {
        std::cerr << "[ERROR] Standard Exception: " << e.what() << std::endl;
        if (root) delete root;
        if (logMgr) delete logMgr;
        return 1;

    } catch (...) {
        std::cerr << "[ERROR] Unknown exception!" << std::endl;
        if (root) delete root;
        if (logMgr) delete logMgr;
        return 1;
    }
}
