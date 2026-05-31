import Foundation
import GridMonitorCore

/// Справжній клієнт до бекенду FSolar. Каркас готовий; шляхи й мапінг вмикаються
/// після Етапу M0. Поки `API.Path.*` == nil — кидає `APIError.notConfigured`.
actor LiveFSolarAPIClient: FSolarAPIClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(urlSession: URLSession = .shared) {
        self.session = urlSession
    }

    func login(_ credentials: Credentials) async throws -> Session {
        // Пароль шифрується RSA (PKCS#1) публічним ключем FSolar → base64 (як JSEncrypt у вебі).
        let encryptedPassword = try RSACrypto.encrypt(credentials.password)
        var request = makeRequest(path: API.Path.login, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "userName": credentials.username,
            "password": encryptedPassword,
            "version": "1.0",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: LoginData = try await send(request)
        return data.toSession()
    }

    func fetchPlants(session: Session) async throws -> [Plant] {
        // TODO(M0): підтвердити параметри/відповідь /plant/plantDetails живим зразком.
        throw APIError.notConfigured
    }

    func fetchDevices(session: Session, plantId: String) async throws -> [Device] {
        // TODO(M0): підтвердити параметри/відповідь /deviceList живим зразком.
        throw APIError.notConfigured
    }

    func fetchAlarms(session: Session, deviceSN: String, from: Date, to: Date) async throws -> [Alarm] {
        var request = makeRequest(path: API.Path.alarms, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(session, to: &request)
        let body: [String: Any] = [
            "pageNum": 1,
            "pageSize": 50,
            "plantName": "",
            "deviceSn": deviceSN,
            "status": "",
            "warringType": "",
            "userName": "",
            "orgCode": "",
            "faultcode": "",
            "deviceModel": "",
            "deviceAlias": "",
            "leftDate": Int(from.timeIntervalSince1970 * 1000),
            "rightDate": Int(to.timeIntervalSince1970 * 1000),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let page: AlarmListData = try await send(request)
        return (page.dataList ?? []).compactMap { $0.toDomain() }
    }

    func fetchRealtime(session: Session, deviceSN: String, deviceType: String) async throws -> RealtimeSnapshot {
        var request = makeRequest(path: API.Path.snapshot, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(session, to: &request)
        let body: [String: Any] = [
            "deviceSn": deviceSN,
            "deviceType": deviceType,           // напр. "OG" (off-grid)
            "dateStr": Self.snapshotDateFormatter.string(from: .now),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let dto: RealtimeDTO = try await send(request)
        return try dto.toSnapshot(now: .now)
    }

    private static let snapshotDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    // MARK: - Helpers

    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: API.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = API.requestTimeout
        request.setValue("en_US", forHTTPHeaderField: "lang")
        request.setValue("WEB", forHTTPHeaderField: "source")
        return request
    }

    /// Токен FSolar містить префікс `Bearer_` і йде в `Authorization` дослівно (підтверджено по JS).
    private func applyAuth(_ session: Session, to request: inout URLRequest) {
        request.setValue(session.token, forHTTPHeaderField: "Authorization")
    }

    /// Виконати запит і розгорнути конверт `{code, message, data}`.
    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Невідома відповідь")
        }
        // На рівні HTTP теж буває 401/429, але основний статус FSolar віддає у полі code.
        switch http.statusCode {
        case 200...299: break
        case 401:       throw APIError.unauthorized
        case 429:       throw APIError.rateLimited
        default:        throw APIError.server(status: http.statusCode)
        }

        let envelope: APIResponse<T>
        do {
            envelope = try decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }

        switch envelope.code {
        case 200:
            guard let payload = envelope.data else {
                throw APIError.decoding("Порожнє поле data при code=200")
            }
            return payload
        case 998:
            throw APIError.unauthorized          // токен протух → SessionManager релогіниться
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.server(status: envelope.code)
        }
    }
}
