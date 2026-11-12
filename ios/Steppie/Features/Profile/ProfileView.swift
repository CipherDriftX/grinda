import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var vaultChoice: Money?
    @State private var deleteError: String?
    @State private var claimURL: URL?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        StrideMark(color: .white)
                            .padding(10)
                            .frame(width: 56, height: 56)
                            .background(Palette.cobalt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.profile.displayName ?? "Walker").font(.headline)
                            Text(model.profile.isSignedIn ? "Signed in with Apple" : "Not signed in")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isPro { ProBadge() }
                    }
                    .padding(.vertical, 4)
                }

                Section("Goal") {
                    Stepper(value: $model.profile.dailyGoal, in: 3_000...25_000, step: 500) {
                        LabeledContent("Daily steps", value: model.profile.dailyGoal.formatted())
                    }
                    if let why = model.profile.why {
                        LabeledContent("Why you walk", value: why.title)
                    }
                    Toggle("Metric units", isOn: $model.profile.usesMetric)
                }

                Section {
                    LabeledContent("Apple Health") {
                        Text(model.healthConnected ? "Connected" : "Not connected")
                            .foregroundStyle(model.healthConnected ? Palette.cobalt : .secondary)
                    }
                    if !model.healthConnected {
                        Button("Connect Apple Health") { Task { await model.connectHealth() } }
                    }
                    NavigationLink("Garmin, Fitbit, Oura and others") { TrackersHelp() }
                } header: { Text("Step sources") } footer: {
                    Text("Anything that syncs to Apple Health counts. Manually entered steps don't.")
                }

                Section {
                    Toggle("Evening pace check", isOn: $model.profile.notificationsEnabled)
                        .onChange(of: model.profile.notificationsEnabled) { _, on in
                            if on { Task { _ = await NotificationService.requestPermission() } }
                            model.persist()
                        }
                    Toggle("Race invites from Pip", isOn: $model.profile.invitesEnabled)
                        .disabled(!model.profile.notificationsEnabled)
                        .onChange(of: model.profile.invitesEnabled) { model.persist() }
                } header: {
                    Text("Nudges")
                } footer: {
                    Text("Pace check: one evening note while a race is on, only if you're behind. Race invites: at most one a day between races, fewer over time.")
                }

                Section {
                    AppIconPicker()
                    Button(model.isPro ? "Manage Steppie Pro" : "Get Steppie Pro") { model.showingPaywall = true }
                } header: { Text("Steppie Pro") }

                Section("The fine print, in large print") {
                    NavigationLink("Race rules") { LegalText(title: "Race rules", text: Legal.rules) }
                    NavigationLink("Privacy") { LegalText(title: "Privacy", text: Legal.privacy) }
                    NavigationLink("Health disclaimer") { LegalText(title: "Health disclaimer", text: Legal.health) }
                    Link("Contact support", destination: URL(string: "mailto:support@steppie.app")!)
                }

                Section {
                    if deleting {
                        ProgressView()
                    } else {
                        Button("Delete account", role: .destructive) { confirmDelete = true }
                    }
                } footer: {
                    Text("Deletes your account and data. Races still running have to settle first. Money in your Vault is cashed out through Whop or given up; entry credit ends with the account. Payment records stay in our books without your name.")
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.persist(); dismiss() } } }
            .confirmationDialog("Delete your Steppie account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { Task { await delete(vault: nil) } }
            } message: {
                Text("This can't be undone.")
            }
            .confirmationDialog("Your Vault holds \(vaultChoice?.formatted ?? "money")", isPresented: Binding(get: { vaultChoice != nil }, set: { if !$0 { vaultChoice = nil } }), titleVisibility: .visible) {
                Button("Cash it out, then delete") { vaultChoice = nil; Task { await delete(vault: "cash_out") } }
                Button("Give it up and delete", role: .destructive) { vaultChoice = nil; Task { await delete(vault: "give_up") } }
                Button("Cancel", role: .cancel) { vaultChoice = nil }
            } message: {
                Text("Cashing out sends it through Whop before the account goes. Given up, it stays with Steppie.")
            }
            .alert("Can't delete yet", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: { Text(deleteError ?? "") }
            .alert("Claim your Vault", isPresented: .constant(claimURL != nil)) {
                Button("Open claim link") {
                    if let claimURL { openURL(claimURL) }
                    claimURL = nil
                    model.wipeLocal()
                }
            } message: {
                Text("Your account is deleted. Your Vault went out as a Whop claim link, and this is the only time you'll see it. Open it now to claim the money.")
            }
        }
    }
}

extension ProfileView {
    private func delete(vault: String?) async {
        deleting = true
        defer { deleting = false }
        switch await model.deleteAccount(vault: vault) {
        case .deleted(let url):
            if let url {
                claimURL = url
            } else {
                model.wipeLocal()
                dismiss()
            }
        case .vaultChoice(let money):
            vaultChoice = money
        case .blocked(let message):
            deleteError = message
        }
    }
}

private struct TrackersHelp: View {
    var body: some View {
        List {
            Section {
                Text("Steppie reads from Apple Health, so set your tracker's app to share steps with Health and they'll count automatically.")
            }
            Section("How to connect") {
                LabeledContent("Garmin", value: "Garmin Connect › Settings › Apple Health")
                LabeledContent("Fitbit", value: "Use a Health sync app")
                LabeledContent("Oura", value: "Oura › Settings › Apple Health")
                LabeledContent("Withings", value: "Health Mate › Apple Health")
                LabeledContent("Samsung", value: "Use a Health sync app")
            }
            Section {
                Text("If both your iPhone and a watch record steps, Apple Health removes the overlap. Steppie uses Health's total.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Trackers")
    }
}

private struct LegalText: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.body)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
    }
}

enum Legal {
    static let rules = """
    1. A solo race has a daily step goal, a number of days, and a stake you choose (5 to 500).
    2. A day counts when Apple Health shows at least the goal for that calendar day in the time zone you entered in. Manually entered steps are excluded. In a purse with a time window, only steps inside the window count.
    3. Each day closes at midnight. Solo races settle 3 hours after the last day closes, purses a day after, so delayed syncs are included.
    4. Grace days, where included, cover missed days first, then Shields you equipped (up to 2 per race). Unused Shields return to your locker after settlement.
    5. You pay from your Vault first, then by card through Whop. Solo stakes have no fee. A checkout you don't finish within an hour is called off and anything taken from your Vault goes back.
    6. Finish a solo race and the whole stake comes back when it settles: card payments are refunded to the card, Vault money goes back to your Vault.
    7. If you miss a day beyond your grace days and Shields, the stake is kept by Steppie.
    7a. Comeback: within 72 hours of a missed solo race, you may enter one 5-day Comeback race at the same daily goal with a stake at least equal to the missed one. If you finish it, your Comeback stake comes back in full and so does half of the missed stake, the same way it was paid. A Comeback cannot itself have a Comeback.
    7b. Whether money comes back depends only on your steps. Grit, leagues, tables and Shoe Boxes are cosmetic and have no cash value.
    8. Purses: you pay the entry plus a service fee (from your balance 0.50 + 4%, by card 0.99 + 5%; with Pro, nothing from your balance and 0.49 + 3% by card). Every entry goes into the purse and the people who finish split it equally. If nobody finishes, every entry goes back where it came from. Host purses add 5% of each entry for the host.
    9. Step data that looks physically impossible, and screenshots you send for a missed day, are reviewed by a person. A day under review is never marked as missed automatically. In a purse only the share of an entry under review is held back; everyone else is paid on time.
    10. Cash-outs leave your Vault from 5, up to 500 a day, to the Whop account you paid with, or as a claim link valid 7 days. A cash-out that fails or isn't claimed goes back to your Vault. A chargeback pauses cash-outs until a person has looked at it.
    11. If a verified sync problem caused a miss, contact support within 48 hours and we'll fix it.
    12. Paid races are for adults 18 and over (older where local law says so) and are not offered where paid contests aren't allowed. Money already in your Vault can always be cashed out.
    """

    static let privacy = """
    Steppie reads steps, walking distance and body weight from Apple Health, only to track races and show progress. Health data is never sold, shared with advertisers, or used for advertising.

    Your account uses Sign in with Apple. Card payments and cash-outs are processed by Whop; Steppie never sees your card number. We store your date of birth and where you live (country, and state where it matters) to check that paid races are allowed for you.

    We keep daily and hourly step totals for your races to settle them and prevent cheating. You can delete your account and data at any time in the app.
    """

    static let health = """
    Steppie is a motivation tool, not a medical device. Calorie and fat figures are estimates based on step count and body weight. Talk to a doctor before starting a new exercise plan, especially if you have a health condition.
    """
}

/// Pro perk: the Stride S on the home screen.
private struct AppIconPicker: View {
    @Environment(AppModel.self) private var model
    @State private var current = UIApplication.shared.alternateIconName

    var body: some View {
        HStack(spacing: 18) {
            option(nil, image: "IconPreviewClassic", label: "Steppie")
            option("AppIcon-Stride", image: "IconPreviewStride", label: "Stride S")
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func option(_ name: String?, image: String, label: String) -> some View {
        let selected = current == name
        return Button {
            guard model.isPro || name == nil else { model.showingPaywall = true; return }
            Task {
                try? await UIApplication.shared.setAlternateIconName(name)
                current = UIApplication.shared.alternateIconName
                Haptics.tick()
            }
        } label: {
            VStack(spacing: 6) {
                Image(image)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(selected ? Palette.cobalt : .clear, lineWidth: 3))
                HStack(spacing: 3) {
                    Text(label).font(.caption.weight(.semibold))
                    if name != nil && !model.isPro { Image(systemName: "lock.fill").font(.caption2) }
                }
                .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(label) app icon\(selected ? ", selected" : "")")
    }
}
