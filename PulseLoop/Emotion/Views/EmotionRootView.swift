import SwiftData
import SwiftUI
import UIKit
import UserNotifications

enum ETab: Hashable { case home, library, train, meditate, ring }

enum ERoute: Hashable {
    case trainIntro(Feeling)
    case reminders
    case learn
    case builder(UUID?)
    case newFromTemplate(String)
    case deliveryTest
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
    /// Short session opened from a calm cue: 4 in / 7 out with the ring guiding each breath.
    case calmBreath
    var id: String { rawValue }
    var title: String {
        switch self {
        case .journey: "Relax, find coherence, reflect"
        case .relax: "Deep relax"
        case .coherence: "Coherence"
        case .calmBreath: "Calm breath"
        }
    }
    /// (phase name, seconds)
    var phases: [(name: String, seconds: Int)] {
        switch self {
        case .journey: [("Relax", 300), ("Coherence breathing", 480), ("Reflect", 120)]
        case .relax: [("Body scan", 600)]
        case .coherence: [("Coherence breathing", 300)]
        case .calmBreath: [("Calm breathing", 99)]
        }
    }
    var totalSeconds: Int { phases.map(\.seconds).reduce(0, +) }
}

struct CueRequest: Identifiable, Hashable {
    let id = UUID()
    let feeling: Feeling
    let eventID: UUID?
    var experienceID: UUID? = nil
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = EmotionRouter()
    @State private var notificationBridge = CueNotificationBridge()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if profiles.first?.onboardingCompleted == true {
                EmotionTabView()
            } else {
                EmotionOnboardingView()
            }
        }
        .simRingOverlay()
        .environment(router)
        .preferredColorScheme(.dark)
        .tint(EColor.accent)
        .task {
            _ = context.emotionProfile()
            let router = self.router, services = self.services
            notificationBridge.install(
                onCue: { feeling, expID in router.cue = CueRequest(feeling: feeling, eventID: nil, experienceID: expID) },
                onDeliver: { _, _ in services.dispatcher?.check(.notification) },
                onCalm: { router.meditation = .calmBreath },
                onPlay: { id in
                    router.experienceToPlay = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first
                })
            // "Play on iPhone" from the watch: open the player now if Kinnora is on screen,
            // otherwise a notification that opens it (iOS can't start the player in the background).
            services.watch.onStartExperience = { id in
                guard let exp = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first else { return }
                if UIApplication.shared.applicationState == .active {
                    router.experienceToPlay = exp
                } else {
                    let content = UNMutableNotificationContent()
                    content.title = "Play \(exp.title)"
                    content.body = "Started from your Apple Watch. Tap to play it here."
                    content.sound = .default
                    content.userInfo = ["experience": exp.id.uuidString, "play": true]
                    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "emotion.watchplay.\(exp.id.uuidString)", content: content, trigger: nil))
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                ReminderScheduler.rebuild(context: context)
                services.dispatcher?.check(.foreground)
            case .background:
                ReminderBackgroundRefresh.schedule()
            default: break
            }
        }
        .fullScreenCover(item: $router.training) { request in
            TrainingSessionView(request: request).simRingOverlay().environment(router)
        }
        .fullScreenCover(item: $router.experienceToPlay) { experience in
            ExperiencePlayerView(experience: experience).simRingOverlay().environment(router)
        }
        .fullScreenCover(item: $router.meditation) { kind in
            MeditationSessionView(kind: kind).simRingOverlay().environment(router)
        }
        .sheet(item: $router.cue) { cue in
            CueReceivedView(request: cue).environment(router)
        }
    }


}

/// Routes taps on cue notifications into the cue-received screen.
@MainActor
final class CueNotificationBridge: NSObject, UNUserNotificationCenterDelegate {
    private var onCue: ((Feeling, UUID?) -> Void)?
    private var onDeliver: ((Feeling, UUID?) -> Void)?
    private var onCalm: (() -> Void)?
    private var onPlay: ((UUID) -> Void)?
    private weak var previous: UNUserNotificationCenterDelegate?

    func install(onCue: @escaping (Feeling, UUID?) -> Void, onDeliver: @escaping (Feeling, UUID?) -> Void, onCalm: @escaping () -> Void, onPlay: @escaping (UUID) -> Void) {
        self.onPlay = onPlay
        self.onCue = onCue
        self.onDeliver = onDeliver
        self.onCalm = onCalm
        let center = UNUserNotificationCenter.current()
        if center.delegate !== self { previous = center.delegate; center.delegate = self }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let raw = info["feeling"] as? String
        let expID = (info["experience"] as? String).flatMap(UUID.init(uuidString:))
        let calm = info["calm"] != nil
        let play = info["play"] != nil
        Task { @MainActor in
            if play, let expID {
                self.onPlay?(expID)
            } else if calm {
                self.onCalm?()
            } else if let raw, let feeling = Feeling(rawValue: raw) {
                self.onDeliver?(feeling, expID)
                self.onCue?(feeling, expID)
            }
            else { self.previous?.userNotificationCenter?(center, didReceive: response, withCompletionHandler: {}) }
            completionHandler()
        }
    }

    /// App in the foreground at cue time: send the touch to the ring right away.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let info = notification.request.content.userInfo
        let raw = info["feeling"] as? String
        let expID = (info["experience"] as? String).flatMap(UUID.init(uuidString:))
        Task { @MainActor in
            if let raw, let feeling = Feeling(rawValue: raw) { self.onDeliver?(feeling, expID) }
            completionHandler([.banner, .sound])
        }
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
                .tabItem { Label("Experiences", systemImage: "photo.on.rectangle") }.tag(ETab.library)
            NavigationStack(path: $router.trainPath) { TrainHubView().emotionDestinations() }
                .tabItem { Label("Practice", systemImage: "circle.dotted.circle") }.tag(ETab.train)
            NavigationStack(path: $router.meditatePath) { MeditateSelectView().emotionDestinations() }
                .tabItem { Label("Meditate", systemImage: "water.waves") }.tag(ETab.meditate)
            NavigationStack(path: $router.ringPath) { RingSettingsView().emotionDestinations() }
                .tabItem { Label("Devices", systemImage: "dot.radiowaves.left.and.right") }.tag(ETab.ring)
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
            case let .newFromTemplate(templateID): ExperienceBuilderView(experienceID: nil, templateID: templateID)
            case .stressCue: StressCueView()
            case .simPanel: SimulatorPanelView()
            case .ringSettings: RingSettingsView()
            case .pairRing: PairRingScreen(onDone: nil)
            case .deliveryTest:
                #if DEBUG
                ReminderDeliveryTestView()
                #else
                EmptyView()
                #endif
            }
        }
    }
}

/// Floating simulated ring bubble shown over every screen in debug (6.3).
extension View {
    /// Shows the floating simulated-ring control when the simulator and its overlay are on (debug use).
    func simRingOverlay() -> some View { modifier(SimRingOverlayHost()) }
}

struct SimRingOverlayHost: ViewModifier {
    @Environment(EmotionServices.self) private var services
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if services.simulator.isEnabled && services.simulator.showOverlay {
                SimRingOverlay().padding(.trailing, 10).padding(.bottom, 150)
            }
        }
    }
}

struct SimRingOverlay: View {
    @Environment(EmotionServices.self) private var services
    @Environment(EmotionRouter.self) private var router
    @State private var open = false
    /// The overlay can be dragged out of the way; position is kept for the app session.
    @State private var offset: CGSize = SimRingOverlay.savedOffset
    @GestureState private var drag: CGSize = .zero
    private static var savedOffset: CGSize = .zero

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
        .offset(x: offset.width + drag.width, y: offset.height + drag.height)
        .gesture(
            DragGesture(minimumDistance: 8)
                .updating($drag) { value, state, _ in state = value.translation }
                .onEnded { value in
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                    SimRingOverlay.savedOffset = offset
                }
        )
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
