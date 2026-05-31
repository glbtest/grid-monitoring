import Foundation

/// Чисте (тестоване) правило виявлення переходу стану мережі.
///
/// Порівнює попередній відомий стан із новим знімком. Якщо `isPresent` змінився —
/// повертає відповідну подію. Якщо стан не змінився (або попереднього стану ще немає) —
/// повертає `nil`.
enum DetectGridTransition {

    /// - Parameters:
    ///   - previous: попередній відомий стан мережі (`nil`, якщо це перший знімок).
    ///   - current: новий знімок.
    /// - Returns: тип події, якщо стався перехід, інакше `nil`.
    static func transition(previous: GridStatus?, current: GridStatus) -> GridEventType? {
        guard let previous else { return nil }   // перший знімок — базова лінія, не подія
        guard previous.isPresent != current.isPresent else { return nil }
        return current.isPresent ? .gridRestored : .gridLost
    }
}
