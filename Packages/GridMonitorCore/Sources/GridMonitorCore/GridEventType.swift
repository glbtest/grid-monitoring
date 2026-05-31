import Foundation

/// Тип події мережі. Чистий тип у Core (модель `@Model GridEvent` лишається в застосунку).
public enum GridEventType: String, Codable, Sendable {
    case gridLost       // мережа зникла
    case gridRestored   // мережа з'явилась
}
