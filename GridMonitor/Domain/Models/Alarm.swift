import Foundation

/// Тривога/попередження від FSolar (журнал `device_warring_list`).
struct Alarm: Identifiable, Equatable, Sendable {
    let id: String          // warringId
    let deviceSN: String
    let code: String        // warnCode, напр. "4"
    let name: String        // warringName, напр. "Abnormal Mains Power Supply"
    let type: String        // warringType: "W" = Warning, "F" = Fault
    let date: Date          // dataTime
    let level: Int?

    /// Чи це тривога про зникнення мережі (Abnormal Mains Power Supply).
    var isMainsFailure: Bool {
        code == "4" || name.localizedCaseInsensitiveContains("mains")
    }
}
