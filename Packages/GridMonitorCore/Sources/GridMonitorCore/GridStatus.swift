import Foundation

/// Робочий режим інвертора стосовно мережі.
public enum WorkMode: String, Codable, Sendable {
    case line       // живлення від мережі
    case battery    // живлення від батареї (мережі немає)
    case bypass     // байпас
    case unknown
}

/// Знімок стану електромережі в конкретний момент.
public struct GridStatus: Equatable, Sendable {
    /// Чи присутня мережа. Обчислюється з полів FSolar за правилом з docs/fsolar-api.md §6.
    public let isPresent: Bool
    public let voltage: Double?      // В
    public let frequency: Double?    // Гц
    public let workMode: WorkMode
    public let timestamp: Date

    public init(isPresent: Bool, voltage: Double?, frequency: Double?, workMode: WorkMode, timestamp: Date) {
        self.isPresent = isPresent
        self.voltage = voltage
        self.frequency = frequency
        self.workMode = workMode
        self.timestamp = timestamp
    }
}
