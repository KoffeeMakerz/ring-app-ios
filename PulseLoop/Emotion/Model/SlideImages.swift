import Photos
import SwiftUI
import UIKit

/// One image in an experience's slideshow, stored in `Experience.imageRefs` as a string:
/// - "img:<asset name>"  a single built-in image (Assets.xcassets/Slideshow)
/// - "file:<name>.jpg"   the user's photo, kept as a private resized copy on this phone (never uploaded)
/// - "photo:<id>"        older builds: a reference into the Photos library
/// Older experiences may also hold "app:<setID>" (a whole set); `normalized` expands it to single images.
enum SlideRef: Hashable {
    case app(String)
    case file(String)
    case photo(String)

    static let maxCount = 30

    init?(ref: String) {
        if ref.hasPrefix("img:") { self = .app(String(ref.dropFirst(4))) }
        else if ref.hasPrefix("file:") { self = .file(String(ref.dropFirst(5))) }
        else if ref.hasPrefix("photo:") { self = .photo(String(ref.dropFirst(6))) }
        else { return nil }
    }

    var ref: String {
        switch self {
        case .app(let name): return "img:\(name)"
        case .file(let name): return "file:\(name)"
        case .photo(let id): return "photo:\(id)"
        }
    }

    var isOwnPhoto: Bool { if case .app = self { return false } else { return true } }

    /// Stored refs as an ordered list of single images, without duplicates.
    static func normalized(_ refs: [String]) -> [String] {
        var out: [String] = []
        for r in refs {
            if r.hasPrefix("app:"), let set = ImageSet.all.first(where: { $0.id == String(r.dropFirst(4)) }) {
                out += set.imageNames.map { "img:\($0)" }
            } else if SlideRef(ref: r) != nil {
                out.append(r)
            }
        }
        var seen = Set<String>()
        return Array(out.filter { seen.insert($0).inserted }.prefix(maxCount))
    }

    static func expand(_ refs: [String]) -> [SlideRef] { normalized(refs).compactMap(SlideRef.init(ref:)) }

    static func label(_ refs: [String]) -> String {
        let slides = expand(refs)
        if slides.isEmpty { return "None yet" }
        let own = slides.filter(\.isOwnPhoto).count
        let app = slides.count - own
        if own == 0 { return "\(app) app image\(app == 1 ? "" : "s")" }
        if app == 0 { return "\(own) of your photo\(own == 1 ? "" : "s")" }
        return "\(slides.count) images · \(own) yours"
    }
}

/// The user's photos as private resized copies in Application Support. Nothing leaves the phone.
enum ExperienceImageStore {
    nonisolated static var folder: URL {
        let url = URL.applicationSupportDirectory.appending(path: "ExperienceImages", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Saves a JPEG copy with the longest side at most 2048 px. Returns the file name.
    nonisolated static func save(_ data: Data) -> String? {
        guard let source = UIImage(data: data) else { return nil }
        let scale = min(1, 2048 / max(source.size.width, source.size.height))
        let size = CGSize(width: (source.size.width * scale).rounded(), height: (source.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in source.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: folder.appending(path: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return name
        } catch { return nil }
    }

    nonisolated static func load(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: folder.appending(path: name).path(percentEncoded: false))
    }
}

/// Loads any slide as a UIImage (app images go straight through `Image(name)` instead).
@MainActor
enum SlideImageLoader {
    private static var cache: [String: UIImage] = [:]

    static func image(for slide: SlideRef, size: CGSize) async -> UIImage? {
        switch slide {
        case .app(let name):
            return UIImage(named: name)
        case .file(let name):
            if let hit = cache[name] { return hit }
            let image = await Task.detached(priority: .userInitiated) { ExperienceImageStore.load(name) }.value
            if let image {
                if cache.count > 40 { cache.removeAll() }
                cache[name] = image
            }
            return image
        case .photo(let id):
            return await PhotoLoader.shared.image(for: id, size: size)
        }
    }
}

/// One slide, filling its frame.
struct SlideImage: View {
    let slide: SlideRef
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if case .app(let name) = slide {
                    Image(name).resizable().scaledToFill()
                } else if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    EColor.card
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .task(id: slide) {
                if case .app = slide { return }
                image = await SlideImageLoader.image(for: slide, size: geo.size)
            }
        }
    }
}
