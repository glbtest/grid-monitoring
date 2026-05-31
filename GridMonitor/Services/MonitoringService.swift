import Foundation

/// Центральна логіка одного циклу моніторингу, спільна для foreground-опитування
/// та фонової задачі: отримати знімок → виявити перехід → записати подію → сповістити.
///
/// `@MainActor`, бо торкається `HistoryStore` (SwiftData ModelContext) та зберігає
/// останній відомий стан.
@MainActor
final class MonitoringService {
    private let session: SessionManager
    private let client: FSolarAPIClient
    private let history: HistoryStore
    private let notifier: NotificationScheduling

    private(set) var lastStatus: GridStatus?
    private(set) var lastSnapshot: RealtimeSnapshot?

    init(
        session: SessionManager,
        client: FSolarAPIClient,
        history: HistoryStore,
        notifier: NotificationScheduling
    ) {
        self.session = session
        self.client = client
        self.history = history
        self.notifier = notifier
    }

    /// Один цикл. Повертає свіжий знімок (для оновлення UI).
    /// `notifyOnTransition` = true у фоні; у foreground UI сам показує банер.
    @discardableResult
    func checkOnce(deviceSN: String, deviceType: String, notifyOnTransition: Bool) async throws -> RealtimeSnapshot {
        let client = self.client   // Sendable; уникаємо доступу до @MainActor self в акторному замиканні
        let snapshot = try await session.withValidSession { session in
            try await client.fetchRealtime(session: session, deviceSN: deviceSN, deviceType: deviceType)
        }

        if let eventType = DetectGridTransition.transition(
            previous: lastStatus,
            current: snapshot.grid
        ) {
            let event = GridEvent(
                type: eventType,
                date: snapshot.grid.timestamp,
                batterySoCAtEvent: snapshot.battery.soc,
                deviceID: deviceSN
            )
            try? history.record(event)
            if notifyOnTransition {
                await notifier.notify(eventType, soc: snapshot.battery.soc)
            }
        }

        lastStatus = snapshot.grid
        lastSnapshot = snapshot
        return snapshot
    }
}
