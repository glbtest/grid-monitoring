import Foundation

/// Фейковий клієнт для розробки UI та тестів, поки Етап M0 не завершено.
/// Симулює коливання заряду й періодичне зникнення/появу мережі.
actor MockFSolarAPIClient: FSolarAPIClient {
    private var tick = 0

    func login(_ credentials: Credentials) async throws -> Session {
        guard !credentials.username.isEmpty, !credentials.password.isEmpty else {
            throw APIError.unauthorized
        }
        return Session(token: "mock-token", expiresAt: nil)
    }

    func fetchPlants(session: Session) async throws -> [Plant] {
        [Plant(id: "plant-1", name: "Дім")]
    }

    func fetchDevices(session: Session, plantId: String) async throws -> [Device] {
        [Device(id: "MOCK-SN-0001", name: "Інвертор (демо)", plantId: plantId, isOnline: true)]
    }

    func fetchAlarms(session: Session, deviceSN: String, from: Date, to: Date) async throws -> [Alarm] {
        // Демо: одна тривога зникнення мережі ~10 хв тому.
        [Alarm(
            id: "mock-alarm-1",
            deviceSN: deviceSN,
            code: "4",
            name: "Abnormal Mains Power Supply",
            type: "W",
            date: Date().addingTimeInterval(-600),
            level: 1
        )]
    }

    func fetchRealtime(session: Session, deviceSN: String, deviceType: String) async throws -> RealtimeSnapshot {
        tick += 1
        // Мережа «зникає» кожні ~4 виклики — щоб бачити переходи й сповіщення.
        let gridPresent = (tick % 8) >= 4
        let now = Date()
        let grid = GridStatus(
            isPresent: gridPresent,
            voltage: gridPresent ? 231.0 : 0.0,
            frequency: gridPresent ? 50.0 : 0.0,
            workMode: gridPresent ? .line : .battery,
            timestamp: now
        )
        let soc = max(10, 95 - (tick % 8) * 5)
        let battery = BatteryStatus(
            soc: soc,
            voltage: 52.0,
            current: gridPresent ? 8.0 : -12.0,
            timestamp: now
        )
        return RealtimeSnapshot(grid: grid, battery: battery)
    }
}
