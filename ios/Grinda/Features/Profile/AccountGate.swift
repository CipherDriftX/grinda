import SwiftUI
import AuthenticationServices
import CryptoKit

/// Shown before the first staked race: Sign in with Apple and an 18+ check.
struct AccountGate: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var nonce = AccountGate.randomNonce()
    @State private var birthYear = Calendar.current.component(.year, from: .now) - 30
    @State private var error: String?

    private var years: [Int] {
        let now = Calendar.current.component(.year, from: .now)
        return Array((now - 100)...(now - 10)).reversed()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Staked races are real money, so we need to know it's you and that you're 18 or over.")
                    .font(.body)
                    .foregroundStyle(Palette.inkSecondary)
                Picker("Year of birth", selection: $birthYear) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)
                if let error {
                    Text(error).font(.footnote).foregroundStyle(Palette.risk)
                }
                Spacer()
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    Task { await handle(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("Grinda never posts anything or shares your data.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
            .navigationTitle("One quick check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func handle(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code != .canceled { error = e.localizedDescription }
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            model.profile.birthYear = birthYear
            guard model.profile.isAdult else {
                error = "Staked races are for adults 18 and over. Practice laps are open to everyone."
                return
            }
            if model.api.isConfigured, let tokenData = cred.identityToken, let token = String(data: tokenData, encoding: .utf8) {
                do { try await model.api.signInWithApple(idToken: token, nonce: nonce) } catch {
                    self.error = error.localizedDescription
                    return
                }
            }
            let name = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            model.signedIn(appleUserID: cred.user, name: name)
            dismiss()
        }
    }

    static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var gen = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars.randomElement(using: &gen)! })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
