import Foundation

/// Тривога/попередження від FSolar (журнал `device_warring_list`).
public struct Alarm: Identifiable, Equatable, Sendable {
    public let id: String          // warringId
    public let deviceSN: String
    public let code: String        // warnCode, напр. "4"
    public let name: String        // warringName, напр. "Abnormal Mains Power Supply"
    public let type: String        // warringType: "W" = Warning, "F" = Fault
    public let date: Date          // dataTime
    public let level: Int?

    public init(id: String, deviceSN: String, code: String, name: String, type: String, date: Date, level: Int?) {
        self.id = id
        self.deviceSN = deviceSN
        self.code = code
        self.name = name
        self.type = type
        self.date = date
        self.level = level
    }

    /// Чи це тривога про зникнення мережі (Abnormal Mains Power Supply).
    public var isMainsFailure: Bool {
        code == "4" || name.range(of: "mains", options: .caseInsensitive) != nil
    }
}
