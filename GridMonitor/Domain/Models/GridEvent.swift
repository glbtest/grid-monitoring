import Foundation
import SwiftData

/// Тип події мережі.
enum GridEventType: String, Codable, Sendable {
    case gridLost       // мережа зникла
    case gridRestored   // мережа з'явилась
}

/// Подія зміни стану мережі. Зберігається в SwiftData для історії.
@Model
final class GridEvent {
    var typeRaw: String
    var date: Date
    var batterySoCAtEvent: Int?
    var deviceID: String?

    var type: GridEventType {
        get { GridEventType(rawValue: typeRaw) ?? .gridLost }
        set { typeRaw = newValue.rawValue }
    }

    init(type: GridEventType, date: Date, batterySoCAtEvent: Int? = nil, deviceID: String? = nil) {
        self.typeRaw = type.rawValue
        self.date = date
        self.batterySoCAtEvent = batterySoCAtEvent
        self.deviceID = deviceID
    }
}
