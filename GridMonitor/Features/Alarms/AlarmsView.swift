import SwiftUI

struct AlarmsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = AlarmsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let error = model.errorText, model.alarms.isEmpty {
                    ContentUnavailableView {
                        Label("Не вдалося завантажити", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if model.alarms.isEmpty && !model.isLoading {
                    ContentUnavailableView(
                        "Тривог немає",
                        systemImage: "checkmark.shield",
                        description: Text("За останній тиждень тривог не зафіксовано.")
                    )
                } else {
                    List(model.alarms) { alarm in
                        row(alarm)
                    }
                }
            }
            .overlay {
                if model.isLoading && model.alarms.isEmpty { ProgressView() }
            }
            .navigationTitle("Тривоги")
            .refreshable { await model.load(env: env) }
            .task { await model.load(env: env) }
        }
    }

    private func row(_ alarm: Alarm) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(alarm))
                .font(.title3)
                .foregroundStyle(color(alarm))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(alarm)).font(.headline)
                Text(alarm.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(alarm.type == "F" ? "Збій" : "Увага")
                .font(.caption2).bold()
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color(alarm).opacity(0.15), in: Capsule())
                .foregroundStyle(color(alarm))
        }
        .padding(.vertical, 2)
    }

    private func displayName(_ alarm: Alarm) -> String {
        alarm.isMainsFailure ? "Зникнення мережі" : (alarm.name.isEmpty ? "Тривога \(alarm.code)" : alarm.name)
    }

    private func icon(_ alarm: Alarm) -> String {
        if alarm.isMainsFailure { return "bolt.slash.fill" }
        return alarm.type == "F" ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    private func color(_ alarm: Alarm) -> Color {
        if alarm.isMainsFailure { return .red }
        return alarm.type == "F" ? .red : .orange
    }
}
