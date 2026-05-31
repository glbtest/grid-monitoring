import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let error = model.errorText {
                        errorBanner(error)
                    }
                    gridCard
                    batteryCard
                    if let ts = model.snapshot?.grid.timestamp {
                        Text("Оновлено: \(ts.formatted(date: .omitted, time: .standard))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Стан")
            .refreshable { await model.refresh() }
            .task { await model.start(env: env, context: context) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await model.refresh() }
                } else if phase == .background {
                    GridRefreshTask.schedule()
                }
            }
        }
    }

    // MARK: - Cards

    private var gridCard: some View {
        let present = model.snapshot?.grid.isPresent
        return VStack(spacing: 12) {
            Image(systemName: present == true ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(present == true ? .green : .red)
            Text(present == nil ? "—" : (present! ? "Мережа Є" : "Мережі НЕМАЄ"))
                .font(.title).bold()
            if let grid = model.snapshot?.grid {
                HStack(spacing: 24) {
                    metric("Напруга", grid.voltage.map { "\(Int($0)) В" } ?? "—")
                    metric("Частота", grid.frequency.map { String(format: "%.1f Гц", $0) } ?? "—")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background((present == true ? Color.green : Color.red).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    private var batteryCard: some View {
        let soc = model.snapshot?.battery.soc
        return VStack(spacing: 12) {
            ZStack {
                Circle().stroke(.secondary.opacity(0.2), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(soc ?? 0) / 100)
                    .stroke(socColor(soc), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(soc.map { "\($0)%" } ?? "—").font(.largeTitle).bold()
            }
            .frame(width: 160, height: 160)
            Text("Заряд батареї").font(.headline)
            if let battery = model.snapshot?.battery {
                HStack(spacing: 24) {
                    metric("Напруга", battery.voltage.map { String(format: "%.1f В", $0) } ?? "—")
                    metric("Струм", battery.current.map { String(format: "%.1f А", $0) } ?? "—")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title3).bold().monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange, in: RoundedRectangle(cornerRadius: 12))
    }

    private func socColor(_ soc: Int?) -> Color {
        guard let soc else { return .gray }
        if soc <= 20 { return .red }
        if soc <= 50 { return .orange }
        return .green
    }
}
