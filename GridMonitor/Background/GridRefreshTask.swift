import Foundation
import BackgroundTasks

/// Реєстрація та планування фонового оновлення (BGAppRefreshTask).
///
/// ⚠️ iOS НЕ гарантує частоту/факт виконання цієї задачі — система вирішує сама залежно
/// від патернів використання, заряду, Low Power Mode тощо. Тому сповіщення при повністю
/// закритому застосунку можливі із затримкою й не на 100%. Для миттєвих push потрібен
/// власний APNs-реле-бекенд (див. план).
enum GridRefreshTask {
    /// Має збігатися зі значенням у Info.plist → BGTaskSchedulerPermittedIdentifiers.
    static let identifier = "com.gridmonitor.grid-refresh"

    /// Викликати один раз при старті застосунку.
    /// `performCheck` виконує один цикл моніторингу (на MainActor) і повертає успіх.
    static func register(performCheck: @escaping @Sendable () async -> Bool) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let appRefresh = task as? BGAppRefreshTask else { return }
            handle(appRefresh, performCheck: performCheck)
        }
    }

    /// Запланувати наступний запуск (приблизно не раніше ніж через 15 хв).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(
        _ task: BGAppRefreshTask,
        performCheck: @escaping @Sendable () async -> Bool
    ) {
        schedule()   // одразу плануємо наступний

        let work = Task {
            let success = await performCheck()
            task.setTaskCompleted(success: success)
        }
        task.expirationHandler = { work.cancel() }
    }
}
