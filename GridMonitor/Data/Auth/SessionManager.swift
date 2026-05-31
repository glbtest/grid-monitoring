import Foundation

/// Керує життєвим циклом сесії: логін, зберігання токена в Keychain, авто-релогін при 401.
/// Облікові дані зберігаються в Keychain, щоб мовчки оновлювати сесію при потребі.
actor SessionManager {
    private let client: FSolarAPIClient
    private let keychain: KeychainStore

    private var session: Session?

    private let tokenAccount = "fsolar.token"
    private let userAccount = "fsolar.username"
    private let passAccount = "fsolar.password"

    init(client: FSolarAPIClient, keychain: KeychainStore = KeychainStore()) {
        self.client = client
        self.keychain = keychain
    }

    var isLoggedIn: Bool {
        get throws { try keychain.get(userAccount) != nil }
    }

    func logIn(_ credentials: Credentials) async throws {
        let session = try await client.login(credentials)
        self.session = session
        try keychain.set(session.token, for: tokenAccount)
        try keychain.set(credentials.username, for: userAccount)
        try keychain.set(credentials.password, for: passAccount)
    }

    func logOut() throws {
        session = nil
        try keychain.delete(tokenAccount)
        try keychain.delete(userAccount)
        try keychain.delete(passAccount)
    }

    /// Поточна сесія; за потреби тихо релогіниться зі збережених облікових даних.
    func currentSession() async throws -> Session {
        if let session { return session }
        if let token = try keychain.get(tokenAccount) {
            let restored = Session(token: token, expiresAt: nil)
            session = restored
            return restored
        }
        return try await reLogin()
    }

    /// Виконує `operation`; при `APIError.unauthorized` релогіниться один раз і повторює.
    func withValidSession<T: Sendable>(
        _ operation: @Sendable (Session) async throws -> T
    ) async throws -> T {
        let session = try await currentSession()
        do {
            return try await operation(session)
        } catch APIError.unauthorized {
            let fresh = try await reLogin()
            return try await operation(fresh)
        }
    }

    private func reLogin() async throws -> Session {
        guard let username = try keychain.get(userAccount),
              let password = try keychain.get(passAccount) else {
            throw APIError.unauthorized
        }
        let session = try await client.login(Credentials(username: username, password: password))
        self.session = session
        try keychain.set(session.token, for: tokenAccount)
        return session
    }
}
