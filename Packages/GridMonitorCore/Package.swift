// swift-tools-version:6.0
import PackageDescription

// Кросплатформне ядро GridMonitor: лише Foundation, без Apple-only фреймворків.
// Компілюється й тестується на Windows/Linux: `swift test`.
let package = Package(
    name: "GridMonitorCore",
    products: [
        .library(name: "GridMonitorCore", targets: ["GridMonitorCore"]),
    ],
    targets: [
        .target(name: "GridMonitorCore"),
        .testTarget(name: "GridMonitorCoreTests", dependencies: ["GridMonitorCore"]),
    ],
    swiftLanguageModes: [.v5]
)
