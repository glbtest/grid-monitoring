import Testing
import Foundation
import SwiftData
@testable import GridMonitor

/// Нотифікатор-шпигун для перевірки, що сповіщення надсилаються при переходах.
actor SpyNotifier: NotificationScheduling {
    private(set) var sent: [GridEventType] = []
    func requestAuthorization() async -> Bool { true }
    func notify(_ event: GridEventType, soc: Int?) async { sent.append(event) }
    func sentEvents() -> [GridEventType] { sent }
}

@MainActor
struct MonitoringServiceTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: GridEvent.self, configurations: config)
        return ModelContext(container)
    }

    @Test func recordsEventAndNotifiesOnTransition() async throws {
        let client = MockFSolarAPIClient()
        let session = SessionManager(client: client)
        try await session.logIn(Credentials(username: "u", password: "p"))
        let context = try makeContext()
        let notifier = SpyNotifier()
        let service = MonitoringService(
            session: session,
            client: client,
            history: HistoryStore(context: context),
            notifier: notifier
        )

        // MockFSolarAPIClient чергує стан мережі кожні ~4 виклики → за 8 циклів буде ≥1 перехід.
        for _ in 0..<8 {
            _ = try await service.checkOnce(deviceSN: "MOCK-SN-0001", deviceType: "OG", notifyOnTransition: true)
        }

        let events = try HistoryStore(context: context).recentEvents()
        #expect(!events.isEmpty)
        let sent = await notifier.sentEvents()
        #expect(sent.count == events.count)
    }
}
