import Foundation

/// Облікові дані FSolar.
struct Credentials: Sendable, Equatable {
    let username: String
    let password: String
}

/// Сесія після успішного логіну.
struct Session: Sendable, Equatable {
    let token: String
    let expiresAt: Date?
}

/// Абстракція над приватним API FSolar. Конкретні реалізації:
/// - `LiveFSolarAPIClient`  — справжні HTTP-запити (вмикається після Етапу M0).
/// - `MockFSolarAPIClient`  — детерміновані фейкові дані для розробки/тестів.
protocol FSolarAPIClient: Sendable {
    func login(_ credentials: Credentials) async throws -> Session
    func fetchPlants(session: Session) async throws -> [Plant]
    func fetchDevices(session: Session, plantId: String) async throws -> [Device]
    func fetchRealtime(session: Session, deviceSN: String, deviceType: String) async throws -> RealtimeSnapshot
    /// Журнал тривог за діапазон часу (для виявлення зникнення мережі).
    func fetchAlarms(session: Session, deviceSN: String, from: Date, to: Date) async throws -> [Alarm]
}

/// Об'єднаний знімок real-time даних інвертора (мережа + батарея).
struct RealtimeSnapshot: Sendable, Equatable {
    let grid: GridStatus
    let battery: BatteryStatus
}
