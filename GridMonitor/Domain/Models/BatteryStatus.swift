import Foundation

/// Знімок стану акумулятора.
struct BatteryStatus: Equatable, Sendable {
    let soc: Int            // % заряду (0...100)
    let voltage: Double?    // В
    let current: Double?    // А; + заряд / − розряд (уточнити знак на Етапі M0)
    let timestamp: Date

    /// Зручний прапорець для UI: чи заряд критично низький.
    var isLow: Bool { soc <= 20 }
}
