import Foundation
import SwiftUI

/// One feeling as the watch shows it. Same names, colours and touches as the iPhone app.
struct WatchFeeling: Identifiable, Hashable {
    let id: String          // "gratitude"
    let name: String        // "Gratitude"
    let color: Color
    let durationsMs: [Int]  // on, off, on, … starting with on

    static let all: [WatchFeeling] = [
        WatchFeeling(id: "gratitude", name: "Gratitude", color: Color(red: 0.95, green: 0.71, blue: 0.35),
                     durationsMs: [350, 300, 350, 1200, 350, 300, 350, 1200, 500]),
        WatchFeeling(id: "love", name: "Love", color: Color(red: 0.95, green: 0.48, blue: 0.61),
                     durationsMs: [300, 300, 450, 1000, 300, 300, 450, 1000, 300, 300, 450]),
        WatchFeeling(id: "joy", name: "Joy", color: Color(red: 0.96, green: 0.84, blue: 0.43),
                     durationsMs: [250, 350, 250, 350, 250, 900, 250, 350, 250, 350, 250, 900, 250, 350, 250, 350, 250]),
        WatchFeeling(id: "bliss", name: "Bliss", color: Color(red: 0.72, green: 0.57, blue: 1.0),
                     durationsMs: [300, 1300, 300, 1000, 300, 750, 300, 550, 700]),
        WatchFeeling(id: "calm", name: "Calm", color: Color(red: 0.50, green: 0.70, blue: 0.94),
                     durationsMs: [700, 1300, 700, 1300, 700, 1300, 700]),
        WatchFeeling(id: "confidence", name: "Confidence", color: Color(red: 0.44, green: 0.84, blue: 0.63),
                     durationsMs: [450, 900, 450, 900, 300, 300, 300, 300, 600]),
    ]

    static func named(_ id: String?) -> WatchFeeling {
        all.first { $0.id == id?.lowercased() } ?? all[0]
    }

    var pattern: Pattern { Pattern(name: name, durationsMs: durationsMs) }
}

/// An experience synced from the iPhone: title, feelings in order, and when each touch plays.
struct WatchExperience: Codable, Identifiable, Hashable {
    struct Cue: Codable, Hashable {
        let at: Int              // seconds from the start
        let feeling: String
        let durations: [Int]
    }
    let id: String
    let title: String
    let feelings: [String]
    let durationS: Int
    let cues: [Cue]

    var colors: [Color] { feelings.map { WatchFeeling.named($0).color } }
    /// The feeling for a moment of the experience: the parts split the time evenly, like on the iPhone.
    func feeling(at seconds: Double) -> WatchFeeling {
        guard !feelings.isEmpty, durationS > 0 else { return WatchFeeling.all[0] }
        let index = min(feelings.count - 1, Int(seconds / Double(durationS) * Double(feelings.count)))
        return WatchFeeling.named(feelings[max(0, index)])
    }
}

/// An upcoming reminder synced from the iPhone.
struct WatchReminder: Codable, Identifiable, Hashable {
    let id: String
    let at: Double               // ms since 1970
    let title: String
    let body: String
    let feeling: String
    let experienceID: String?
    let durations: [Int]

    var date: Date { Date(timeIntervalSince1970: at / 1000) }
}
