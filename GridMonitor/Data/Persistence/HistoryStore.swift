import Foundation
import GridMonitorCore
import SwiftData

/// Запис і читання історії подій мережі через SwiftData.
@MainActor
struct HistoryStore {
    let context: ModelContext

    func record(_ event: GridEvent) throws {
        context.insert(event)
        try context.save()
    }

    func recentEvents(limit: Int = 100) throws -> [GridEvent] {
        var descriptor = FetchDescriptor<GridEvent>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// Тривалість поточного/останнього відключення: час від останнього `gridLost`
    /// до наступного `gridRestored` (або до зараз, якщо мережа ще відсутня).
    func lastOutageDuration(now: Date = .now) throws -> TimeInterval? {
        let events = try recentEvents(limit: 2)
        guard let latest = events.first else { return nil }
        switch latest.type {
        case .gridLost:
            return now.timeIntervalSince(latest.date)
        case .gridRestored:
            guard events.count > 1, events[1].type == .gridLost else { return nil }
            return latest.date.timeIntervalSince(events[1].date)
        }
    }
}
