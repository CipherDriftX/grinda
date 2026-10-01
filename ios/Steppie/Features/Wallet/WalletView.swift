import SwiftUI

/// The Vault: every cent, accounted for, with Bo standing guard. Reads like a
/// passbook, not a dashboard.
struct WalletView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VaultHeader().arrive(0)
                    Passbook().arrive(0)
                    MoneyPath().arrive(1)
                    LedgerList().arrive(2)
                    CommunityLedger().arrive(3)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Palette.ground)
            .navigationTitle("Vault")
        }
    }
}

/// Bo at the vault door, with the one line that matters.
private struct VaultHeader: View {
    @Environment(AppModel.self) private var model
    @State private var hop = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            CharacterView(who: .bo, mood: model.onTheLine.cents > 0 ? .happy : .wink, pose: .wave, hop: hop)
                .frame(width: 100, height: 115)
                .onTapGesture { hop += 1; Haptics.soft() }
            SpeechBubble(text: model.onTheLine.cents > 0
                         ? "I'm Bo. Your \(model.onTheLine.formatted) is in the vault. Finish, and I hand back every cent."
                         : "I'm Bo. I guard the vault. Nothing's in it right now. Back yourself and I'll keep it safe.")
                .padding(.bottom, 40)
            Spacer(minLength: 0)
        }
    }
}

private struct Passbook: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Guilloche(lines: 9, waves: 4).stroke(.white.opacity(0.35), lineWidth: 0.6)
                HStack {
                    Text("STEPPIE VAULT").font(BrandFont.label(13)).kerning(1)
                    Spacer()
                    Image(systemName: "lock.shield.fill")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
            }
            .frame(height: 46)
            .background(Palette.field)

            VStack(alignment: .leading, spacing: 4) {
                Text("On the line now")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                Text(model.onTheLine.formatted)
                    .font(BrandFont.numerals(64))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
            }
            .padding(18)

            VStack(spacing: 10) {
                LeaderLine(label: "Back to you, all time", value: model.returnedTotal.formatted, emphasis: true)
                LeaderLine(label: "Kept from misses", value: model.keptTotal.formatted, emphasis: false)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(Palette.tyvek)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
    }
}

/// "Label ........ value", the way a receipt or passbook lines up money.
private struct LeaderLine: View {
    let label: String
    let value: String
    let emphasis: Bool

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(label).font(.body).foregroundStyle(Palette.ink)
            Line().stroke(Palette.hairline, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.5, 5]))
                .frame(height: 1)
            HStack(spacing: 6) {
                if emphasis { Circle().fill(Palette.volt).frame(width: 8, height: 8) }
                Text(value).font(.system(.body, weight: .semibold)).monospacedDigit().foregroundStyle(Palette.ink)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

private struct MoneyPath: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How your money moves").font(.system(.title3, weight: .bold))
            PathRow(steps: ["Hold placed", "You walk", "Hold released"],
                    caption: "Races up to 5 days. Your money never leaves your account if you finish.")
            PathRow(steps: ["Stake paid", "You walk", "Refunded in full"],
                    caption: "Longer races. Refunds go out automatically within minutes of settling.")
        }
    }
}

private struct PathRow: View {
    let steps: [String]
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    Text(s)
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(i == steps.count - 1 ? Palette.onVolt : Palette.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(i == steps.count - 1 ? Palette.volt : Palette.tyvek, in: Capsule())
                        .lineLimit(1)
                        .fixedSize()
                    if i < steps.count - 1 {
                        Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
            Text(caption).font(.subheadline).foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LedgerList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ledger").font(.system(.title3, weight: .bold)).padding(.bottom, 8)
            if model.ledger.isEmpty {
                HStack(spacing: 12) {
                    SteppieView(mood: .sleep, mane: model.maneLevel)
                        .frame(width: 80, height: 92)
                    Text("Nothing yet. When you pin a bib, every hold, charge, release and refund shows up here with its Stripe reference.")
                        .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                }
            }
            ForEach(Array(model.ledger.enumerated()), id: \.element.id) { i, e in
                LedgerRow(entry: e)
                if i < model.ledger.count - 1 { Divider().overlay(Palette.hairline) }
            }
        }
    }
}

private struct LedgerRow: View {
    let entry: LedgerEntry

    private var symbol: String {
        switch entry.kind {
        case .held: "lock"
        case .charged: "creditcard"
        case .released: "lock.open"
        case .refunded: "arrow.uturn.backward"
        case .kept: "xmark"
        case .comeback: "arrow.uturn.backward.circle"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(entry.kind.isReturn ? Palette.onVolt : Palette.ink)
                .frame(width: 36, height: 36)
                .background(entry.kind.isReturn ? Palette.volt : Palette.tyvek, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind.title).font(.headline).foregroundStyle(Palette.ink)
                Text("\(entry.raceName) · \(entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))")
                    .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                Text(entry.reference)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Palette.inkSecondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Text(amountText)
                .font(.system(.body, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(entry.kind == .kept ? Palette.inkSecondary : Palette.ink)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var amountText: String {
        switch entry.kind {
        case .released, .refunded, .comeback: "+\(entry.amount.formatted)"
        case .held: entry.amount.formatted
        case .charged, .kept: "−\(entry.amount.formatted)"
        }
    }
}

/// Steppie's own books, from the public stats endpoint. Honest about how we earn.
private struct CommunityLedger: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Steppie's books").font(.system(.title3, weight: .bold))
                Spacer()
                if model.publicStats?.isSample == true {
                    Text("Sample data").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
                }
            }
            if let s = model.publicStats {
                VStack(spacing: 10) {
                    LeaderLine(label: "Returned to walkers", value: Money(cents: Int(s.returnedCents), currency: s.currency).formatted, emphasis: true)
                    LeaderLine(label: "Kept from misses", value: Money(cents: Int(s.keptCents), currency: s.currency).formatted, emphasis: false)
                    LeaderLine(label: "Races finished", value: s.racesFinished.formatted(), emphasis: false)
                    LeaderLine(label: "Finish rate", value: s.completionRate.formatted(.percent.precision(.fractionLength(0))), emphasis: false)
                }
                .padding(18)
                .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text("We make money from stakes on missed races, Shields and Steppie Pro. We'd rather you finish, so everything in the app is built to get you over the line, and we publish these numbers live.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
