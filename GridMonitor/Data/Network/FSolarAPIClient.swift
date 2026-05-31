import Foundation
import GridMonitorCore

/// Абстракція над приватним API FSolar. Конкретні реалізації:
/// - `LiveFSolarAPIClient`  — справжні HTTP-запити.
/// - `MockFSolarAPIClient`  — детерміновані фейкові дані для розробки/тестів.
///
/// Значення-типи (`Credentials`, `Session`, `RealtimeSnapshot`) живуть у GridMonitorCore.
protocol FSolarAPIClient: Sendable {
    func login(_ credentials: Credentials) async throws -> Session
    func fetchPlants(session: Session) async throws -> [Plant]
    func fetchDevices(session: Session, plantId: String) async throws -> [Device]
    func fetchRealtime(session: Session, deviceSN: String, deviceType: String) async throws -> RealtimeSnapshot
    /// Журнал тривог за діапазон часу (для виявлення зникнення мережі).
    func fetchAlarms(session: Session, deviceSN: String, from: Date, to: Date) async throws -> [Alarm]
}
