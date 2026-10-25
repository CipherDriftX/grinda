import Foundation
import Security

/// Thin client for the Steppie Supabase backend (Auth + Edge Functions + REST).
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
        didSet { Keychain.save(session, key: "steppie.session") }
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
        let url = (bundle.object(forInfoDictionaryKey: "SteppieSupabaseURL") as? String) ?? ""
        let key = (bundle.object(forInfoDictionaryKey: "SteppieSupabaseAnonKey") as? String) ?? ""
        if let u = URL(string: url), u.scheme == "https", !key.isEmpty {
            config = Config(baseURL: u, anonKey: key)
        } else {
            config = nil
        }
        session = Keychain.load(Session.self, key: "steppie.session")
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
        var shieldsEquipped: Int = 0
        var comebackOf: UUID? = nil
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
        var payoutCents: Int? = nil
        var finishers: Int? = nil
    }

    func races() async throws -> [RemoteRace] {
        try await get("rest/v1/races?select=id,status,stake_state,settled_at,payout_cents,finishers&order=created_at.desc")
    }

    // MARK: Purses

    func purses() async throws -> [Purse] {
        try await get("rest/v1/purse_board?select=*&order=starts_at.asc")
    }

    struct JoinPurseRequest: Encodable {
        let purseId: String
        let timezone: String
        let birthYear: Int?
        var shieldsEquipped: Int = 0
    }

    struct JoinPurseReply: Decodable {
        let raceId: UUID
        let bibNumber: Int
        /// Missing when the Vault balance covered the whole entry.
        let payment: CreateStakeReply?
    }

    func joinPurse(_ req: JoinPurseRequest) async throws -> JoinPurseReply {
        try await send("functions/v1/join-purse", body: req)
    }

    private struct RemoteRunner: Decodable {
        let rank: Int
        let name: String
        let steps: Int
        let state: String
        let isMe: Bool
    }

    func purseBoard(purseID: String) async throws -> [PurseRunner] {
        struct Body: Encodable { let purseId: String }
        let rows: [RemoteRunner] = try await send("rest/v1/rpc/purse_runners", body: Body(purseId: purseID))
        return rows.map { PurseRunner(rank: $0.rank, name: $0.name, steps: $0.steps, state: PurseRunner.State(rawValue: $0.state) ?? .behind, isMe: $0.isMe) }
    }

    private struct RemotePayout: Decodable {
        let name: String
        let purseName: String
        let amountCents: Int
        let profitCents: Int
        let currency: String
        let paidAt: Date
    }

    func payoutFeed() async throws -> [PayoutEvent] {
        let rows: [RemotePayout] = try await get("rest/v1/payout_feed?select=*&order=paid_at.desc&limit=30", auth: false)
        return rows.map {
            PayoutEvent(name: $0.name, purseName: $0.purseName, amount: Money(cents: $0.amountCents, currency: $0.currency),
                        profit: Money(cents: $0.profitCents, currency: $0.currency), at: $0.paidAt)
        }
    }

    func benchTotal() async throws -> Int {
        struct Row: Decodable { let benched: Int }
        let rows: [Row] = try await get("rest/v1/bench_total?select=benched", auth: false)
        return rows.first?.benched ?? 0
    }

    // MARK: Vault

    func cashOut(cents: Int, method: String) async throws {
        struct Body: Encodable { let amountCents: Int; let method: String }
        struct Ok: Decodable { let ok: Bool }
        let _: Ok = try await send("functions/v1/cash-out", body: Body(amountCents: cents, method: method))
    }

    func redeemInvite(code: String) async throws {
        struct Body: Encodable { let code: String }
        struct Ok: Decodable { let ok: Bool }
        let _: Ok = try await send("functions/v1/redeem-invite", body: Body(code: code))
    }

    func submitDispute(raceID: UUID, date: String, note: String, image: Data?) async throws {
        struct Body: Encodable { let raceId: UUID; let date: String; let note: String; let imageBase64: String? }
        struct Ok: Decodable { let ok: Bool }
        let _: Ok = try await send("functions/v1/submit-dispute", body: Body(raceId: raceID, date: date, note: note, imageBase64: image?.base64EncodedString()))
    }

    func submitPost(url: String, platform: String) async throws {
        struct Body: Encodable { let url: String; let platform: String }
        struct Ok: Decodable { let ok: Bool }
        let _: Ok = try await send("functions/v1/submit-post", body: Body(url: url, platform: platform))
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

    struct Me: Decodable {
        let shields: Int
        let league: String
        var vaultCents: Int? = nil
        var creditCents: Int? = nil
        var inviteCode: String? = nil
    }

    func me() async throws -> Me? {
        guard let id = session?.userID else { return nil }
        let rows: [Me] = try await get("rest/v1/profiles?select=shields,league,vault_cents,credit_cents,invite_code&id=eq.\(id)")
        return rows.first
    }

    struct BoardRow: Decodable, Hashable {
        let rank: Int
        let name: String
        let grit: Int
        let isMe: Bool
    }

    func leagueBoard() async throws -> [BoardRow] {
        struct Empty: Encodable {}
        return try await send("rest/v1/rpc/league_board", body: Empty())
    }

    /// Credits Shields bought in the App Store; returns the new locker count.
    func grantShields(transactionID: UInt64) async throws -> Int {
        struct Body: Encodable { let transactionId: String }
        struct Reply: Decodable { let shields: Int }
        let r: Reply = try await send("functions/v1/grant-shields", body: Body(transactionId: String(transactionID)))
        return r.shields
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
            let e = try? decoder.decode(ServerError.self, from: data)
            throw APIError.server(e?.error ?? e?.message ?? e?.msg ?? "Something went wrong (\(code)).")
        }
        return try decoder.decode(T.self, from: data)
    }
}

private struct ServerError: Decodable {
    let error: String?
    let message: String?
    let msg: String?
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
