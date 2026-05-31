import Foundation

/// Виявлення нових тривог зникнення мережі серед свіжого журналу.
/// Чисте й тестоване: повертає лише ті mains-failure тривоги, чий `id` ще не бачили,
/// відсортовані за часом (старіші → новіші).
public enum DetectNewAlarms {
    public static func newMainsFailures(seenIDs: Set<String>, fresh: [Alarm]) -> [Alarm] {
        fresh
            .filter { $0.isMainsFailure && !seenIDs.contains($0.id) }
            .sorted { $0.date < $1.date }
    }
}
