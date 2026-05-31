import Foundation

/// Знімок стану акумулятора.
public struct BatteryStatus: Equatable, Sendable {
    public let soc: Int            // % заряду (0...100)
    public let voltage: Double?    // В
    public let current: Double?    // А; + заряд / − розряд
    public let timestamp: Date

    public init(soc: Int, voltage: Double?, current: Double?, timestamp: Date) {
        self.soc = soc
        self.voltage = voltage
        self.current = current
        self.timestamp = timestamp
    }

    /// Зручний прапорець для UI: чи заряд критично низький.
    public var isLow: Bool { soc <= 20 }
}
