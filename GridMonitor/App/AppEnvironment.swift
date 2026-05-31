import Foundation
import GridMonitorCore
import SwiftUI
import SwiftData

/// Простий DI-контейнер застосунку. Тримає мережевий клієнт, менеджер сесії та нотифікатор.
///
/// Поки Етап M0 не завершено — `useMock == true` і застосунок працює на `MockFSolarAPIClient`.
/// Після заповнення docs/fsolar-api.md та `Endpoints.swift` → встановити `useMock = false`.
@MainActor
@Observable
final class AppEnvironment {
    /// ⚠️ Переключити на false після завершення Етапу M0.
    static let useMock = true

    let client: FSolarAPIClient
    let session: SessionManager
    let notifier: NotificationScheduling

    var isAuthenticated: Bool

    /// Серійник обраного інвертора (не секрет → UserDefaults).
    var selectedDeviceSN: String? {
        didSet { UserDefaults.standard.set(selectedDeviceSN, forKey: "selectedDeviceSN") }
    }

    /// Тип пристрою для запиту знімку (напр. "OG" — off-grid). Потрібен для get_device_snapshot.
    var selectedDeviceType: String {
        didSet { UserDefaults.standard.set(selectedDeviceType, forKey: "selectedDeviceType") }
    }

    init() {
        let client: FSolarAPIClient = Self.useMock ? MockFSolarAPIClient() : LiveFSolarAPIClient()
        self.client = client
        self.session = SessionManager(client: client)
        self.notifier = LocalNotificationScheduler()
        self.selectedDeviceSN = UserDefaults.standard.string(forKey: "selectedDeviceSN")
        self.selectedDeviceType = UserDefaults.standard.string(forKey: "selectedDeviceType") ?? "OG"
        self.isAuthenticated = (try? KeychainStore().get("fsolar.username")) != nil
    }

    func logOut() async {
        try? await session.logOut()
        selectedDeviceSN = nil
        isAuthenticated = false
    }

    func makeMonitoringService(context: ModelContext) -> MonitoringService {
        MonitoringService(
            session: session,
            client: client,
            history: HistoryStore(context: context),
            notifier: notifier
        )
    }
}
