import SwiftUI
import AuthenticationServices
import CryptoKit

/// Shown before the first money move: Sign in with Apple, date of birth and
/// where you live. Age and place decide whether paid races are open (some
/// states block them or set the age above 18). Both are kept once saved; a
/// move is a support request, so nobody switches state one tap before paying.
struct AccountGate: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var nonce = AccountGate.randomNonce()
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var country = Place.phoneCountry ?? "US"
    @State private var region = ""
    @State private var error: String?
    @State private var working = false

    private static let gregorian = Calendar(identifier: .gregorian)

    private var birthRange: ClosedRange<Date> {
        let cal = Self.gregorian
        return (cal.date(byAdding: .year, value: -100, to: .now) ?? .distantPast)...(cal.date(byAdding: .year, value: -10, to: .now) ?? .now)
    }

    /// The server already has these, so they're shown, not asked.
    private var savedBirthDate: String? { model.profile.birthDate }
    private var savedPlace: String? {
        guard let c = model.profile.country, !model.profile.needsPlace else { return nil }
        return [model.profile.region.map(Place.regionName), Place.countryName(c)].compactMap { $0 }.joined(separator: ", ")
    }
    private var askCountry: Bool { model.profile.country == nil }
    private var regionCountry: String { model.profile.country ?? country }
    private var askRegion: Bool { savedPlace == nil && Place.needsRegion.contains(regionCountry) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Paid races are real money, so we need to know it's you, that you're old enough, and that paid races are allowed where you live.")
                        .font(.body)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Section("Date of birth") {
                    if let saved = savedBirthDate {
                        LabeledContent("Born", value: saved)
                    } else {
                        DatePicker("Date of birth", selection: $birthDate, in: birthRange, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                }
                Section {
                    if let saved = savedPlace {
                        LabeledContent("Lives in", value: saved)
                    } else {
                        if askCountry {
                            Picker("Country", selection: $country) {
                                ForEach(Place.countries) { Text($0.name).tag($0.code) }
                            }
                            .pickerStyle(.navigationLink)
                            .onChange(of: country) { region = "" }
                        }
                        if askRegion {
                            Picker(regionCountry == "US" ? "State" : "State or territory", selection: $region) {
                                Text("Choose").tag("")
                                ForEach(Place.regions(of: regionCountry)) { Text($0.name).tag($0.code) }
                            }
                        }
                    }
                } header: {
                    Text("Where you live")
                } footer: {
                    Text("Saved once. If you move, write to support and a person updates it.")
                }
                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(Palette.risk)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ground)
            .safeAreaInset(edge: .bottom) { bottom }
            .navigationTitle("One quick check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private var bottom: some View {
        VStack(spacing: 10) {
            if working {
                ProgressView().frame(height: 56)
            } else if model.profile.isSignedIn {
                Button("Save") { Task { await save() } }
                    .buttonStyle(.primary)
            } else {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    Task { await handle(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text("Steppie never posts anything or shares your data.")
                .font(.caption)
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Palette.ground)
    }

    /// Puts the answers on the profile (only what wasn't saved before) and
    /// checks the age here, so an underage date never leaves the phone.
    private func applyAnswers() -> Bool {
        var p = model.profile
        if p.birthDate == nil {
            p.birthDate = AppModel.dayFormatter.string(from: birthDate)
            p.birthYear = Self.gregorian.component(.year, from: birthDate)
        }
        if p.country == nil {
            p.country = country
            p.region = nil
        }
        if p.region == nil, let c = p.country, Place.needsRegion.contains(c), !region.isEmpty {
            p.region = "\(c)-\(region)"
        }
        if p.needsPlace {
            error = "Choose your state or territory."
            return false
        }
        guard p.isAdult else {
            error = "Paid races are for adults 18 and over. Free races are open to everyone."
            return false
        }
        model.profile = p
        model.persist()
        return true
    }

    private func save() async {
        error = nil
        guard applyAnswers() else { return }
        await finish { try await model.saveProfile() }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) async {
        error = nil
        switch result {
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code != .canceled { error = e.localizedDescription }
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            guard applyAnswers() else { return }
            working = true
            defer { working = false }
            if model.api.isConfigured, let tokenData = cred.identityToken, let token = String(data: tokenData, encoding: .utf8) {
                do { try await model.api.signInWithApple(idToken: token, nonce: nonce) } catch {
                    self.error = error.localizedDescription
                    return
                }
            }
            let name = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            await finish { try await model.signedIn(appleUserID: cred.user, name: name) }
        }
    }

    private func finish(_ work: () async throws -> Void) async {
        working = true
        defer { working = false }
        do {
            try await work()
            if let e = model.moneyGate(), e != .needsSignIn {
                error = e.localizedDescription
                return
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
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
