import Foundation

/// Помилки мережевого шару з людськими повідомленнями для UI.
public enum APIError: Error, LocalizedError, Equatable {
    case notConfigured          // ендпоінти ще не задокументовані (Етап M0)
    case unauthorized           // 401 — токен протух / невірні дані
    case rateLimited            // 429
    case server(status: Int)
    case decoding(String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API ще не налаштовано. Завершіть Етап M0 (docs/fsolar-api.md)."
        case .unauthorized:
            return "Невірний логін або сесія застаріла."
        case .rateLimited:
            return "Забагато запитів. Спробуйте пізніше."
        case .server(let status):
            return "Помилка сервера (\(status))."
        case .decoding(let detail):
            return "Не вдалося обробити відповідь сервера. \(detail)"
        case .transport(let detail):
            return "Проблема з мережею. \(detail)"
        }
    }
}
