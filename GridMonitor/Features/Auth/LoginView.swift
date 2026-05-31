import SwiftUI
import GridMonitorCore

@MainActor
@Observable
final class LoginViewModel {
    var username = ""
    var password = ""
    var isLoading = false
    var errorText: String?

    func logIn(env: AppEnvironment) async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            try await env.session.logIn(Credentials(username: username, password: password))
            env.isAuthenticated = true
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct LoginView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = LoginViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Логін FSolar", text: $model.username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Пароль", text: $model.password)
                        .textContentType(.password)
                }
                if let error = model.errorText {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
                Section {
                    Button {
                        Task { await model.logIn(env: env) }
                    } label: {
                        if model.isLoading { ProgressView() }
                        else { Text("Увійти").frame(maxWidth: .infinity) }
                    }
                    .disabled(model.isLoading || model.username.isEmpty || model.password.isEmpty)
                }
                if AppEnvironment.useMock {
                    Section {
                        Text("Демо-режим: будь-який непорожній логін/пароль. Реальний API вмикається після Етапу M0.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Моніторинг мережі")
        }
    }
}
