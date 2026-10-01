import SwiftUI

@main
struct SteppieApp: App {
    @State private var model: AppModel
    private let launchScreen: String?

    init() {
        let defaults = UserDefaults.standard
        let demo = defaults.bool(forKey: "demo")
        launchScreen = defaults.string(forKey: "screen")
        _model = State(initialValue: AppModel(demo: demo))
    }

    var body: some Scene {
        WindowGroup {
            RootView(launchScreen: launchScreen)
                .environment(model)
                .task { await model.bootstrap() }
                .onOpenURL { _ in } // Stripe redirect return
        }
    }
}

/// Decides between onboarding and the main tabs, and routes demo `-screen`
/// launch arguments to a specific scene for screenshots.
struct RootView: View {
    let launchScreen: String?
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let screen = launchScreen, model.isDemo {
                DemoRouter(screen: screen)
            } else if model.profile.onboarded {
                MainTabs()
            } else {
                OnboardingFlow()
            }
        }
        .tint(Palette.cobalt)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "figure.walk") }
                .tag(AppTab.today)
            RacesView()
                .tabItem { Label("Races", systemImage: "flag.checkered") }
                .tag(AppTab.races)
            LeagueView()
                .tabItem { Label("League", systemImage: "trophy.fill") }
                .tag(AppTab.league)
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.line.downtrend.xyaxis") }
                .tag(AppTab.progress)
            WalletView()
                .tabItem { Label("Vault", systemImage: "lock.shield") }
                .tag(AppTab.wallet)
        }
        .sheet(isPresented: $model.showingProfile) { ProfileView() }
        .sheet(isPresented: $model.showingPaywall) { PaywallView() }
        .sheet(isPresented: $model.showingShields) { ShieldShopView() }
        .fullScreenCover(isPresented: $model.showingShoeBox) { ShoeBoxSheet() }
        .fullScreenCover(item: $model.celebrating) { race in FinishView(race: race) }
        .fullScreenCover(item: $model.newMilestone) { m in MilestoneSheet(milestone: m) }
    }
}

/// Screenshot routes. Only reachable with `-demo YES -screen <name>`.
struct DemoRouter: View {
    let screen: String
    @Environment(AppModel.self) private var model

    var body: some View {
        switch screen {
        case "onboarding-welcome": OnboardingFlow(start: .welcome)
        case "onboarding-baseline": OnboardingFlow(start: .baseline)
        case "onboarding-how": OnboardingFlow(start: .how)
        case "onboarding-invites": OnboardingFlow(start: .notifications)
        case "races": MainTabs().onAppear { model.tab = .races }
        case "league": MainTabs().onAppear { model.tab = .league }
        case "today-new": MainTabs().onAppear { model.races.removeAll { $0.status.isLive } }
        case "comeback": MainTabs().onAppear {
            model.races.removeAll { $0.status.isLive }
            model.races.insert(DemoSeed.missedYesterday(), at: 0)
        }
        case "comeback-contract": NavigationStack { ContractView(template: RaceTemplate.comeback(for: DemoSeed.missedYesterday()), initialStake: 20) }
            .onAppear { model.races.insert(DemoSeed.missedYesterday(), at: 0) }
        case "shields": ShieldShopView()
        case "shoebox": ShoeBoxSheet()
        case "shoebox-open": ShoeBoxSheet(preview: ShoeStyle.all[7])
        case "cast": CastStage()
        case "progress": MainTabs().onAppear { model.tab = .progress }
        case "wallet": MainTabs().onAppear { model.tab = .wallet }
        case "contract": NavigationStack { ContractView(template: RaceTemplate.board[1], initialStake: 20) }
        case "pinning": PinningStage(previewPins: 2)
        case "pinning-demo": PinningStage(autoplay: true)
        case "finish": FinishView(race: DemoSeed.races()[1])
        case "milestone": MilestoneSheet(milestone: Milestone.all[1])
        case "entered": NavigationStack { ContractView(template: RaceTemplate.board[0], initialStake: 20, showEntered: true) }
        case "paywall": PaywallView()
        case "profile": ProfileView()
        default: MainTabs()
        }
    }
}
