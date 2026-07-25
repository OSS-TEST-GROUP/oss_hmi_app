/*
 * Qt5 Wayland QPA Plugin Smoke Test
 * Feature: R006 — Qt5 Wayland QPA Plugin Build Verification
 *
 * Purpose:
 *   Minimal Qt5 QWidget application to verify:
 *   1. Qt Wayland QPA plugin loads successfully (AC-3)
 *   2. Qt5 app connects to Wayland compositor socket (AC-4)
 *   3. wl_surface / wl_compositor interfaces bind (AC-5, via WAYLAND_DEBUG=1)
 *
 * Build:
 *   g++ -std=c++11 -fPIC qt_wayland_smoketest.cpp -o qt_wayland_smoketest \
 *       $(pkg-config --cflags --libs Qt5Widgets)
 *
 * Run:
 *   QT_QPA_PLATFORM=wayland QT_DEBUG_PLUGINS=1 WAYLAND_DEBUG=1 \
 *   ./qt_wayland_smoketest
 *
 * Expected Output:
 *   - "Platform: wayland" printed to stdout
 *   - "QWaylandIntegration: Using Wayland" in stderr (QT_DEBUG_PLUGINS=1)
 *   - wl_registry@2::bind wl_compositor in stderr (WAYLAND_DEBUG=1)
 *   - wl_compositor@3::create_surface in stderr (WAYLAND_DEBUG=1)
 *   - Exit code 0 after 5-second auto-close
 */

#include <QApplication>
#include <QLabel>
#include <QGuiApplication>
#include <QTimer>
#include <QDebug>

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);

    // Create minimal widget to trigger Wayland surface creation
    QLabel label("Qt5 Wayland QPA Smoke Test");
    label.setWindowTitle("R006 Qt Wayland Verification");
    label.resize(640, 480);
    label.show();

    // Print platform name (AC-4 verification: should output "wayland")
    QString platformName = QGuiApplication::platformName();
    qDebug() << "Platform:" << platformName;

    // Verify Wayland platform was actually loaded
    if (platformName != "wayland") {
        qCritical() << "ERROR: Expected platform 'wayland', got:" << platformName;
        qCritical() << "QT_QPA_PLATFORM=" << qgetenv("QT_QPA_PLATFORM");
        qCritical() << "Check QT_DEBUG_PLUGINS=1 output for plugin loading errors";
        return 1;
    }

    qDebug() << "Qt5 Wayland QPA plugin loaded successfully";
    qDebug() << "Window visible. Will auto-exit in 5 seconds...";

    // Auto-close after 5 seconds (stability test)
    QTimer::singleShot(5000, &app, &QApplication::quit);

    int exitCode = app.exec();
    qDebug() << "Application exited with code:" << exitCode;
    return exitCode;
}
