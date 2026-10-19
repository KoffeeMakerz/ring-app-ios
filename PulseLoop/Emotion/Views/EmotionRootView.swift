import SwiftData
import SwiftUI
import UserNotifications

enum ETab: Hashable { case home, library, train, meditate, ring }

enum ERoute: Hashable {
    case trainIntro(Feeling)
    case reminders
    case learn
    case builder(UUID?)
    case stressCue
    case simPanel
    case ringSettings
    case pairRing
}

struct TrainingRequest: Identifiable, Hashable {
    let id = UUID()
    let feeling: Feeling
    let experienceID: UUID?
}

enum MeditationKind: String, Identifiable, CaseIterable {
    case journey, relax, coherence
    var id: String { rawValue }
    var title: String {
        switch self {
        case .journey: "Relax, find coherence, reflect"
        case .relax: "Deep relax"
        case .coherence: "Coherence"
        }
    }
    /// (phase name, seconds)
    var phases: [(name: String, seconds: Int)] {
        switch self {
        case .journey: [("Relax", 300), ("Coherence breathing", 480), ("Reflect", 120)]
        case .relax: [("Body scan", 600)]
        case .coherence: [("Coherence breathing", 300)]
        }
    }
    var totalSeconds: Int { phases.map(\.seconds).reduce(0, +) }
}

struct CueRequest: Identifiable, Hashable {
    let id = UUID()
    let feeling: Feeling
    let eventID: UUID?
}

/// App-wide navigation and modal presentation.
@MainActor
@Observable
final class EmotionRouter {
    var tab: ETab = .home
    var homePath = NavigationPath()
    var libraryPath = NavigationPath()
    var trainPath = NavigationPath()
    var meditatePath = NavigationPath()
    var ringPath = NavigationPath()
    var training: TrainingRequest?
    var experienceToPlay: Experience?
    var meditation: MeditationKind?
    var cue: CueRequest?

    func push(_ route: ERoute) {
        switch tab {
        case .home: homePath.append(route)
        case .library: libraryPath.append(route)
        case .train: trainPath.append(route)
        case .meditate: meditatePath.append(route)
        case .ring: ringPath.append(route)
        }
    }
}

struct EmotionRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(EmotionServices.self) private var services
    @Query private var profiles: [EmotionProfile]
    @State private var router = EmotionRouter()
    @State private var notificationBridge = CueNotificationBridge()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if profiles.first?.onboardingCompleted == true {
                EmotionTabView()
            } else {
                EmotionOnboardingView()
            }
            if services.simulator.isEnabled && services.simulator.showOverlay {
                SimRingOverlay()
                    .padding(.top, 120)
                    .padding(.trailing, 10)
            }
        }
        .environment(router)
        .preferredColorScheme(.dark)
        .tint(EColor.accent)
        .task {
            _ = context.emotionProfile()
            notificationBridge.install { feeling in router.cue = CueRequest(feeling: feeling, eventID: nil) }
        }
        .fullScreenCover(item: $router.training) { request in
            TrainingSessionView(request: request)
        }
        .fullScreenCover(item: $router.experienceToPlay) { experience in
            ExperiencePlayerView(experience: experience)
        }
        .fullScreenCover(item: $router.meditation) { kind in
            MeditationSessionView(kind: kind)
        }
        .sheet(item: $router.cue) { cue in
            CueReceivedView(request: cue)
        }
    }
}

/// Routes taps on cue notifications into the cue-received screen.
@MainActor
final class CueNotificationBridge: NSObject, UNUserNotificationCenterDelegate {
    private var onCue: ((Feeling) -> Void)?
    private weak var previous: UNUserNotificationCenterDelegate?

    func install(onCue: @escaping (Feeling) -> Void) {
        self.onCue = onCue
        let center = UNUserNotificationCenter.current()
        if center.delegate !== self { previous = center.delegate; center.delegate = self }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let raw = info["feeling"] as? String
        Task { @MainActor in
            if let raw, let feeling = Feeling(rawValue: raw) { self.onCue?(feeling) }
            else { self.previous?.userNotificationCenter?(center, didReceive: response, withCompletionHandler: {}) }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

struct EmotionTabView: View {
    @Environment(EmotionRouter.self) private var router

    var body: some View {
        @Bindable var router = self.router
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.homePath) { HomeView().emotionDestinations() }
                .tabItem { Label("Home", systemImage: "house") }.tag(ETab.home)
            NavigationStack(path: $router.libraryPath) { LibraryView().emotionDestinations() }
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }.tag(ETab.library)
            NavigationStack(path: $router.trainPath) { TrainHubView().emotionDestinations() }
                .tabItem { Label("Train", systemImage: "circle.dotted.circle") }.tag(ETab.train)
            NavigationStack(path: $router.meditatePath) { MeditateSelectView().emotionDestinations() }
                .tabItem { Label("Meditate", systemImage: "water.waves") }.tag(ETab.meditate)
            NavigationStack(path: $router.ringPath) { RingSettingsView().emotionDestinations() }
                .tabItem { Label("Ring", systemImage: "circle.circle") }.tag(ETab.ring)
        }
        .toolbarBackground(EColor.tabBar, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

extension View {
    func emotionDestinations() -> some View {
        navigationDestination(for: ERoute.self) { route in
            switch route {
            case let .trainIntro(feeling): TrainIntroView(feeling: feeling)
            case .reminders: RemindersView()
            case .learn: LearnView()
            case let .builder(id): ExperienceBuilderView(experienceID: id)
            case .stressCue: StressCueView()
            case .simPanel: SimulatorPanelView()
            case .ringSettings: RingSettingsView()
            case .pairRing: PairRingScreen(onDone: nil)
            }
        }
    }
}

/// Floating simulated ring bubble shown over every screen in debug (6.3).
struct SimRingOverlay: View {
    @Environment(EmotionServices.self) private var services
    @Environment(EmotionRouter.self) private var router
    @State private var open = false

    var body: some View {
        let sim = services.simulator
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if open {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SIMULATED RING · \(sim.profile.name)").font(EFont.mono(11)).foregroundStyle(EColor.debug)
                            .padding(.horizontal, 10).padding(.top, 6)
                        overlayButton("Play last touch") { services.haptics.play(services.haptics.lastPlayed ?? Feeling.gratitude.touch) }
                        overlayButton("Heart: \(sim.scenario.name)") {
                            let all = HeartScenario.allCases
                            sim.scenario = all[(all.firstIndex(of: sim.scenario)! + 1) % all.count]
                        }
                        overlayButton(sim.connected ? "Disconnect" : "Reconnect", color: sim.connected ? EColor.danger : EColor.success) { sim.setConnected(!sim.connected) }
                        overlayButton("Open simulator panel", color: EColor.debug) { open = false; router.push(.simPanel) }
                    }
                    .padding(8)
                    .frame(width: 220)
                    .background(Color(hex: "#08060C"), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(EColor.line))
                }
                Button { open.toggle() } label: {
                    Circle()
                        .strokeBorder(sim.isBuzzing ? EColor.debug : Color(hex: "#4A4160"), lineWidth: 7)
                        .frame(width: 34, height: 34)
                        .shadow(color: sim.isBuzzing ? EColor.debug : .clear, radius: 10)
                        .frame(width: 60, height: 60)
                        .background(Color(hex: "#08060C"), in: Circle())
                        .overlay(Circle().strokeBorder(EColor.debug, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Simulated ring controls")
            }
            if let bpm = sim.currentBPM {
                Text("\(bpm) bpm").font(EFont.mono(11)).foregroundStyle(Color(hex: "#7FB2F0"))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(hex: "#08060C"), in: Capsule())
            }
        }
    }

    private func overlayButton(_ title: String, color: Color = EColor.text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(EFont.body(14, .semibold)).foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .background(EColor.card, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
