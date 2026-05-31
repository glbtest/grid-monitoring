import Foundation

/// Облікові дані FSolar.
public struct Credentials: Sendable, Equatable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// Сесія після успішного логіну.
public struct Session: Sendable, Equatable {
    public let token: String
    public let expiresAt: Date?

    public init(token: String, expiresAt: Date?) {
        self.token = token
        self.expiresAt = expiresAt
    }
}

/// Об'єднаний знімок real-time даних інвертора (мережа + батарея).
public struct RealtimeSnapshot: Sendable, Equatable {
    public let grid: GridStatus
    public let battery: BatteryStatus

    public init(grid: GridStatus, battery: BatteryStatus) {
        self.grid = grid
        self.battery = battery
    }
}
