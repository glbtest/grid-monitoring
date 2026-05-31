import Foundation
import SwiftData

@MainActor
@Observable
final class DashboardViewModel {
    var snapshot: RealtimeSnapshot?
    var isLoading = false
    var errorText: String?
    var lastTransition: GridEventType?

    private var service: MonitoringService?
    private var deviceSN: String?
    private var deviceType = "OG"
    private var pollTask: Task<Void, Never>?

    var pollInterval: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "pollInterval")
        return stored > 0 ? stored : 45
    }

    /// Налаштувати залежності (раз) і запустити foreground-опитування.
    func start(env: AppEnvironment, context: ModelContext) async {
        if service == nil {
            service = env.makeMonitoringService(context: context)
        }
        deviceType = env.selectedDeviceType
        await resolveDevice(env: env)
        startPolling()
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        guard let service, let deviceSN else {
            errorText = APIError.notConfigured.errorDescription
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let previousPresent = snapshot?.grid.isPresent
            let fresh = try await service.checkOnce(deviceSN: deviceSN, deviceType: deviceType, notifyOnTransition: false)
            if let previousPresent, previousPresent != fresh.grid.isPresent {
                lastTransition = fresh.grid.isPresent ? .gridRestored : .gridLost
            }
            snapshot = fresh
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func resolveDevice(env: AppEnvironment) async {
        if let sn = env.selectedDeviceSN { deviceSN = sn; return }
        // Перший запуск: підтягнути перший пристрій першої станції.
        do {
            let client = env.client   // Sendable; не звертаємось до @MainActor env у акторному замиканні
            let device = try await env.session.withValidSession { session -> Device? in
                let plants = try await client.fetchPlants(session: session)
                guard let plant = plants.first else { return nil }
                return try await client.fetchDevices(session: session, plantId: plant.id).first
            }
            if let device {
                deviceSN = device.id
                env.selectedDeviceSN = device.id
            }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.pollInterval))
            }
        }
    }
}
