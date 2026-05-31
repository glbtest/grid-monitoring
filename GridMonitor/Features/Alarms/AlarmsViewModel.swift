import Foundation

@MainActor
@Observable
final class AlarmsViewModel {
    var alarms: [Alarm] = []
    var isLoading = false
    var errorText: String?

    /// Завантажити тривоги за останні `days` днів для обраного пристрою.
    func load(env: AppEnvironment, days: Int = 7) async {
        guard let sn = env.selectedDeviceSN, !sn.isEmpty else {
            errorText = "Вкажіть серійник інвертора в Налаштуваннях."
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        let client = env.client   // Sendable; не звертаємось до @MainActor env у акторному замиканні
        let to = Date()
        let from = to.addingTimeInterval(-Double(days) * 24 * 3600)
        do {
            let result = try await env.session.withValidSession { session in
                try await client.fetchAlarms(session: session, deviceSN: sn, from: from, to: to)
            }
            alarms = result.sorted { $0.date > $1.date }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
