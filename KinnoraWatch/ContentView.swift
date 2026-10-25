import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: WatchSession
    @EnvironmentObject var keepAwake: KeepAwake

    private let colors: [String: Color] = [
        "Gratitude": Color(red: 0.95, green: 0.71, blue: 0.35), "Joy": Color(red: 0.96, green: 0.84, blue: 0.43),
        "Love": Color(red: 0.95, green: 0.48, blue: 0.61), "Confidence": Color(red: 0.44, green: 0.84, blue: 0.63),
        "Bliss": Color(red: 0.72, green: 0.57, blue: 1.0), "Calm": Color(red: 0.50, green: 0.70, blue: 0.94),
    ]

    var body: some View {
        List {
            VStack(spacing: 4) {
                Text("KINNORA").font(.system(size: 14, weight: .light)).tracking(5)
                Text(session.phoneReachable ? "Listening to your iPhone" : "iPhone not in reach")
                    .font(.footnote).foregroundStyle(.secondary)
                if let last = session.lastTouch {
                    Text("Last: \(last.name) · \(last.at.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)

            Button {
                keepAwake.toggle()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(keepAwake.isOn ? "End session" : "Start session").font(.headline)
                    Text(keepAwake.isOn
                         ? "Touches arrive with your wrist down\(keepAwake.endsAt.map { " · until \($0.formatted(date: .omitted, time: .shortened))" } ?? "")"
                         : "Keep listening while you practise (up to 1 h)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Feel a touch") {
                ForEach(Pattern.feelings, id: \.0) { name, durations in
                    Button {
                        HapticPlayer.play(Pattern(name: name, durationsMs: durations))
                    } label: {
                        HStack {
                            Circle().fill(colors[name] ?? .gray).frame(width: 10, height: 10)
                            Text(name)
                        }
                    }
                }
            }
        }
    }
}
