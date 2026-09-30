import Foundation
import Security

/// Thin client for the Grinda Supabase backend (Auth + Edge Functions + REST).
/// Configuration comes from Info.plist keys filled by `ios/Config/Secrets.xcconfig`.
final class APIClient {
    struct Config {
        var baseURL: URL
        var anonKey: String
    }

    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userID: String
    }

    enum APIError: LocalizedError {
        case notConfigured
        case server(String)
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Payments aren't set up in this build yet."
            case .server(let m): m
            case .unauthorized: "Please sign in again."
            }
        }
    }

    let config: Config?
    private(set) var session: Session? {
        didSet { Keychain.save(session, key: "grinda.session") }
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(bundle: Bundle = .main) {
        let url = (bundle.object(forInfoDictionaryKey: "GrindaSupabaseURL") as? String) ?? ""
        let key = (bundle.object(forInfoDictionaryKey: "GrindaSupabaseAnonKey") as? String) ?? ""
        if let u = URL(string: url), u.scheme == "https", !key.isEmpty {
            config = Config(baseURL: u, anonKey: key)
        } else {
            config = nil
        }
        session = Keychain.load(Session.self, key: "grinda.session")
    }

    var isConfigured: Bool { config != nil }

    // MARK: Auth

    /// Exchanges a Sign in with Apple identity token for a Supabase session.
    func signInWithApple(idToken: String, nonce: String) async throws {
        struct Body: Encodable { let provider = "apple"; let idToken: String; let nonce: String }
        struct Reply: Decodable {
            let accessToken: String; let refreshToken: String; let expiresIn: Double
            struct User: Decodable { let id: String }
            let user: User
        }
        let r: Reply = try await send("auth/v1/token?grant_type=id_token", body: Body(idToken: idToken, nonce: nonce), auth: false)
        session = Session(accessToken: r.accessToken, refreshToken: r.refreshToken,
                          expiresAt: .now.addingTimeInterval(r.expiresIn), userID: r.user.id)
    }

    func signOut() { session = nil }

    private func refreshIfNeeded() async throws {
        guard let s = session, s.expiresAt < .now.addingTimeInterval(60) else { return }
        struct Body: Encodable { let refreshToken: String }
        struct Reply: Decodable { let accessToken: String; let refreshToken: String; let expiresIn: Double }
        let r: Reply = try await send("auth/v1/token?grant_type=refresh_token", body: Body(refreshToken: s.refreshToken), auth: false)
        session = Session(accessToken: r.accessToken, refreshToken: r.refreshToken,
                          expiresAt: .now.addingTimeInterval(r.expiresIn), userID: s.userID)
    }

    // MARK: Races

    struct CreateStakeRequest: Encodable {
        let templateId: String
        let stakeCents: Int
        let currency: String
        let timezone: String
        let startDate: String // yyyy-MM-dd, local
        let birthYear: Int?
    }

    struct CreateStakeReply: Decodable {
        let raceId: UUID
        let bibNumber: Int
        let paymentIntentClientSecret: String
        let customerId: String
        let ephemeralKey: String
        let publishableKey: String
        let captureMethod: String // "manual" (hold) or "automatic"
    }

    func createStake(_ req: CreateStakeRequest) async throws -> CreateStakeReply {
        try await send("functions/v1/create-stake", body: req)
    }

    struct DaySubmission: Encodable {
        let date: String
        let steps: Int
        let hourly: [Int]
    }

    struct SubmitSteps: Encodable {
        let raceId: UUID
        let days: [DaySubmission]
        let attestation: String?
    }

    func submitSteps(_ body: SubmitSteps) async throws {
        struct Ok: Decodable { let ok: Bool }
        let _: Ok = try await send("functions/v1/submit-steps", body: body)
    }

    struct RemoteRace: Decodable {
        let id: UUID
        let status: String
        let stakeState: String
        let settledAt: Date?
    }

    func races() async throws -> [RemoteRace] {
        try await get("rest/v1/races?select=id,status,stake_state,settled_at&order=created_at.desc")
    }

    struct RemoteLedger: Decodable {
        let id: UUID
        let createdAt: Date
        let raceName: String
        let kind: String
        let amountCents: Int
        let currency: String
        let stripeRef: String
    }

    func ledger() async throws -> [RemoteLedger] {
        try await get("rest/v1/ledger_view?select=*&order=created_at.desc")
    }

    func publicStats() async throws -> PublicStats {
        try await get("functions/v1/public-stats?currency=\(Money.localCurrency)", auth: false)
    }

    func deleteAccount() async throws {
        struct Ok: Decodable { let ok: Bool }
        struct Empty: Encodable {}
        let _: Ok = try await send("functions/v1/delete-account", body: Empty())
        session = nil
    }

    // MARK: Transport

    private func request(_ path: String, auth: Bool) async throws -> URLRequest {
        guard let config else { throw APIError.notConfigured }
        guard let url = URL(string: path, relativeTo: config.baseURL) else { throw APIError.server("Bad URL") }
        var req = URLRequest(url: url)
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth {
            try await refreshIfNeeded()
            guard let token = session?.accessToken else { throw APIError.unauthorized }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func get<T: Decodable>(_ path: String, auth: Bool = true) async throws -> T {
        let req = try await request(path, auth: auth)
        return try await perform(req)
    }

    private func send<B: Encodable, T: Decodable>(_ path: String, body: B, auth: Bool = true) async throws -> T {
        var req = try await request(path, auth: auth)
        req.httpMethod = "POST"
        req.httpBody = try encoder.encode(body)
        return try await perform(req)
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else {
            struct Err: Decodable { let error: String?; let message: String?; let msg: String? }
            let e = try? decoder.decode(Err.self, from: data)
            throw APIError.server(e?.error ?? e?.message ?? e?.msg ?? "Something went wrong (\(code)).")
        }
        return try decoder.decode(T.self, from: data)
    }
}

/// Minimal Keychain wrapper for the auth session.
enum Keychain {
    static func save<T: Encodable>(_ value: T?, key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        guard let value, let data = try? JSONEncoder().encode(value) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
