import Foundation
import UserNotifications

/// Абстракція над локальними сповіщеннями. Виділена протоколом, щоб у майбутньому
/// підмінити на APNs-реле (див. docs/fsolar-api.md / план — «миттєві push»).
protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    func notify(_ event: GridEventType, soc: Int?) async
}

struct LocalNotificationScheduler: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func notify(_ event: GridEventType, soc: Int?) async {
        let content = UNMutableNotificationContent()
        switch event {
        case .gridLost:
            content.title = "⚡️ Зникла мережа"
            content.body = soc.map { "Живлення від батареї. Заряд: \($0)%." }
                ?? "Живлення від батареї."
        case .gridRestored:
            content.title = "✅ З'явилась мережа"
            content.body = soc.map { "Мережа відновлена. Заряд батареї: \($0)%." }
                ?? "Мережа відновлена."
        }
        content.sound = .default

        // trigger nil → доставити негайно.
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
