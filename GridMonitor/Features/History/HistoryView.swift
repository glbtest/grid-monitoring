import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \GridEvent.date, order: .reverse) private var events: [GridEvent]

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "Поки немає подій",
                        systemImage: "clock",
                        description: Text("Тут з'являться зникнення та поява мережі.")
                    )
                } else {
                    List(events) { event in
                        HStack(spacing: 12) {
                            Image(systemName: event.type == .gridLost ? "bolt.slash.fill" : "bolt.fill")
                                .foregroundStyle(event.type == .gridLost ? .red : .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.type == .gridLost ? "Зникла мережа" : "З'явилась мережа")
                                    .font(.headline)
                                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let soc = event.batterySoCAtEvent {
                                Text("\(soc)%").font(.subheadline).monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Історія")
        }
    }
}
