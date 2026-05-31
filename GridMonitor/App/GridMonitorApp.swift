import SwiftUI
import SwiftData

@main
struct GridMonitorApp: App {
    /// Контейнер SwiftData для історії подій мережі.
    private let modelContainer: ModelContainer
    /// DI-контейнер застосунку (живе весь час роботи застосунку).
    private let env: AppEnvironment

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: GridEvent.self)
        } catch {
            fatalError("Не вдалося створити ModelContainer: \(error)")
        }
        self.modelContainer = container
        self.env = AppEnvironment()
        Self.registerBackgroundTask(env: env, container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
        }
        .modelContainer(modelContainer)
    }

    /// Реєстрація фонової задачі. Має відбутися до завершення запуску застосунку.
    /// Весь цикл (побудова сервісу + перевірка) виконується на MainActor, щоб не виносити
    /// non-Sendable `MonitoringService` за межі акторної ізоляції.
    private static func registerBackgroundTask(env: AppEnvironment, container: ModelContainer) {
        GridRefreshTask.register {
            await runBackgroundCheck(env: env, container: container)
        }
    }

    @MainActor
    private static func runBackgroundCheck(env: AppEnvironment, container: ModelContainer) async -> Bool {
        guard let sn = env.selectedDeviceSN else { return false }
        let service = env.makeMonitoringService(context: ModelContext(container))
        do {
            _ = try await service.checkOnce(deviceSN: sn, deviceType: env.selectedDeviceType, notifyOnTransition: true)
            return true
        } catch {
            return false
        }
    }
}

/// Кореневий перемикач: логін або головний таб-бар.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        if env.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Стан", systemImage: "bolt.fill") }
            AlarmsView()
                .tabItem { Label("Тривоги", systemImage: "exclamationmark.triangle") }
            HistoryView()
                .tabItem { Label("Історія", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Налаштування", systemImage: "gearshape") }
        }
    }
}
