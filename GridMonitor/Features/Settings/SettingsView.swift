import SwiftUI
import GridMonitorCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("pollInterval") private var pollInterval: Double = 45

    @State private var notificationsAuthorized = false

    var body: some View {
        @Bindable var env = env
        return NavigationStack {
            Form {
                Section("Пристрій") {
                    TextField("Серійник (deviceSn)", text: Binding(
                        get: { env.selectedDeviceSN ?? "" },
                        set: { env.selectedDeviceSN = $0.isEmpty ? nil : $0 }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    Picker("Тип", selection: $env.selectedDeviceType) {
                        Text("Off-grid (OG)").tag("OG")
                        Text("Hybrid (HB)").tag("HB")
                        Text("On-grid (ON)").tag("ON")
                    }
                }

                Section("Опитування (коли застосунок відкритий)") {
                    Picker("Інтервал", selection: $pollInterval) {
                        Text("30 c").tag(30.0)
                        Text("45 c").tag(45.0)
                        Text("60 c").tag(60.0)
                        Text("120 c").tag(120.0)
                    }
                }

                Section("Сповіщення") {
                    Button("Запитати дозвіл на сповіщення") {
                        Task { notificationsAuthorized = await env.notifier.requestAuthorization() }
                    }
                    Button("Надіслати тестове сповіщення") {
                        Task { await env.notifier.notify(.gridLost, soc: 64) }
                    }
                    Text("У фоні iOS не гарантує миттєвість сповіщень. Для миттєвих push потрібен власний серверний реле (див. план).")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section {
                    Button("Вийти", role: .destructive) {
                        Task { await env.logOut() }
                    }
                }
            }
            .navigationTitle("Налаштування")
        }
    }
}
