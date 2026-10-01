import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        GTrackMark(color: .white)
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

                Section("Nudges") {
                    Toggle("Evening pace check", isOn: $model.profile.notificationsEnabled)
                        .onChange(of: model.profile.notificationsEnabled) { _, on in
                            if on { Task { _ = await NotificationService.requestPermission() } }
                        }
                }

                Section {
                    AppIconPicker()
                    Button(model.isPro ? "Manage Grinda Pro" : "Get Grinda Pro") { model.showingPaywall = true }
                } header: { Text("Grinda Pro") }

                Section("The fine print, in large print") {
                    NavigationLink("Race rules") { LegalText(title: "Race rules", text: Legal.rules) }
                    NavigationLink("Privacy") { LegalText(title: "Privacy", text: Legal.privacy) }
                    NavigationLink("Health disclaimer") { LegalText(title: "Health disclaimer", text: Legal.health) }
                    Link("Contact support", destination: URL(string: "mailto:support@grinda.app")!)
                }

                Section {
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("Deletes your account and data. Holds are released; charged stakes on live races are refunded.")
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.persist(); dismiss() } } }
            .confirmationDialog("Delete your Grinda account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { Task { await model.deleteAccount(); dismiss() } }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

private struct TrackersHelp: View {
    var body: some View {
        List {
            Section {
                Text("Grinda reads from Apple Health, so set your tracker's app to share steps with Health and they'll count automatically.")
            }
            Section("How to connect") {
                LabeledContent("Garmin", value: "Garmin Connect › Settings › Apple Health")
                LabeledContent("Fitbit", value: "Use a Health sync app")
                LabeledContent("Oura", value: "Oura › Settings › Apple Health")
                LabeledContent("Withings", value: "Health Mate › Apple Health")
                LabeledContent("Samsung", value: "Use a Health sync app")
            }
            Section {
                Text("If both your iPhone and a watch record steps, Apple Health removes the overlap. Grinda uses Health's total.")
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
    1. A race has a daily step goal, a number of days, and a stake you choose.
    2. A day counts when Apple Health shows at least the goal for that calendar day in the time zone you started in. Manually entered steps are excluded.
    3. Each day closes at midnight. Settlement runs 3 hours after the last day closes so delayed syncs are included.
    4. Grace days, where included, automatically cover missed days, in order.
    5. Races of 5 days or fewer place an authorisation (hold) on your card. If you finish, the hold is released and nothing is charged. If you miss, the hold is captured.
    6. Longer races charge the stake when you enter. If you finish, the full stake is refunded to the original payment method automatically.
    7. If you miss a day beyond your grace days, the stake is kept by Grinda.
    8. Step data that looks physically impossible is reviewed by a person. A day under review is never marked as missed automatically.
    9. If a verified sync problem caused a miss, contact support within 48 hours and we'll fix it.
    10. Staked races are available to adults 18 and over, where permitted by local law.
    """

    static let privacy = """
    Grinda reads steps, walking distance and body weight from Apple Health, only to track races and show progress. Health data is never sold, shared with advertisers, or used for advertising.

    Your account uses Sign in with Apple. Payments are processed by Stripe; Grinda never sees your full card number.

    We keep daily and hourly step totals for your races to settle them and prevent cheating. You can delete your account and data at any time in the app.
    """

    static let health = """
    Grinda is a motivation tool, not a medical device. Calorie and fat figures are estimates based on step count and body weight. Talk to a doctor before starting a new exercise plan, especially if you have a health condition.
    """
}

/// Pro perk: put Grin on the home screen.
private struct AppIconPicker: View {
    @Environment(AppModel.self) private var model
    @State private var current = UIApplication.shared.alternateIconName

    var body: some View {
        HStack(spacing: 18) {
            option(nil, image: "IconPreviewClassic", label: "Classic")
            option("AppIcon-Grin", image: "IconPreviewGrin", label: "Grin")
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
