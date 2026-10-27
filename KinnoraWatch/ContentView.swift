import SwiftUI

enum WatchRoute: Hashable {
    case experiences
    case experience(String)
    case play(String)
    case reminders
    case feelings
    case feel(String)
}

/// Home, in the spirit of Apple's Mindfulness app: big tiles, one thing per tap.
struct ContentView: View {
    @EnvironmentObject var session: WatchSession
    @EnvironmentObject var store: WatchStore
    @EnvironmentObject var keepAwake: KeepAwake
    @State private var path: [WatchRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 10) {
                    Text("KINNORA").font(.system(size: 13, weight: .light)).tracking(5)
                        .foregroundStyle(Color(red: 1, green: 0.93, blue: 0.84))
                    if let next = store.upcoming.first {
                        Text("Next: \(next.title) · \(next.date.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Tile(title: "Experiences", subtitle: store.experiences.isEmpty ? "Make one on your iPhone" : "\(store.experiences.count) to play",
                         icon: "sparkles", colors: [Color(red: 0.95, green: 0.71, blue: 0.35), Color(red: 0.72, green: 0.57, blue: 1.0)]) {
                        path.append(.experiences)
                    }
                    Tile(title: "Feel a touch", subtitle: "Practise one feeling", icon: "hand.tap",
                         colors: [Color(red: 0.95, green: 0.48, blue: 0.61), Color(red: 0.96, green: 0.84, blue: 0.43)]) {
                        path.append(.feelings)
                    }
                    Tile(title: "Reminders", subtitle: store.upcoming.isEmpty ? "None planned" : "\(store.upcoming.count) coming up",
                         icon: "bell", colors: [Color(red: 0.50, green: 0.70, blue: 0.94), Color(red: 0.44, green: 0.84, blue: 0.63)]) {
                        path.append(.reminders)
                    }
                    Button {
                        keepAwake.toggle()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(keepAwake.isOn ? "Listening" : "Listen to iPhone", systemImage: keepAwake.isOn ? "dot.radiowaves.left.and.right" : "iphone.radiowaves.left.and.right")
                                .font(.headline)
                            Text(keepAwake.isOn
                                 ? "Touches arrive with your wrist down\(keepAwake.endsAt.map { " · until \($0.formatted(date: .omitted, time: .shortened))" } ?? ""). Tap to stop."
                                 : "Keep the watch listening while you practise on your iPhone (up to 1 h)")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(session.phoneReachable ? "iPhone connected" : "iPhone not in reach")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .navigationDestination(for: WatchRoute.self) { route in
                switch route {
                case .experiences: ExperiencesView()
                case .experience(let id): ExperienceDetailView(id: id)
                case .play(let id): PlayerView(id: id)
                case .reminders: RemindersView()
                case .feelings: FeelingsView()
                case .feel(let id): FeelView(feeling: WatchFeeling.named(id))
                }
            }
        }
        .onChange(of: store.pending) { _, pending in
            guard let pending else { return }
            switch pending {
            case .experience(let id): path = [.experience(id)]
            case .feeling(let id): path = [.feel(id)]
            }
            store.pending = nil
        }
    }
}

/// A big rounded tile with a soft gradient, like the Mindfulness app's cards.
struct Tile: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.title3).frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption2).opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12).padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: colors.map { $0.opacity(0.55) }, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
