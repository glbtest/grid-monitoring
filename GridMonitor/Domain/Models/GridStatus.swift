import Foundation

/// Робочий режим інвертора стосовно мережі.
enum WorkMode: String, Codable, Sendable {
    case line       // живлення від мережі
    case battery    // живлення від батареї (мережі немає)
    case bypass     // байпас
    case unknown
}

/// Знімок стану електромережі в конкретний момент.
struct GridStatus: Equatable, Sendable {
    /// Чи присутня мережа. Обчислюється з полів FSolar за правилом з docs/fsolar-api.md §6.
    let isPresent: Bool
    let voltage: Double?      // В
    let frequency: Double?    // Гц
    let workMode: WorkMode
    let timestamp: Date
}
