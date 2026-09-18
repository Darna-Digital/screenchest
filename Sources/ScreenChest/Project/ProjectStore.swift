import Foundation

enum ProjectStore {
    static let packageExtension = "screenchest"
    static let projectFileName = "project.json"
    static let screenFileName = "screen.mov"
    static let cameraFileName = "camera.mov"
    static let mouseFileName = "mouse.json"

    static var libraryURL: URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
        return movies.appendingPathComponent("ScreenChest", isDirectory: true)
    }

    static func newPackageURL(date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "Recording \(formatter.string(from: date))"
        return libraryURL.appendingPathComponent(name).appendingPathExtension(packageExtension)
    }

    static func createPackage(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func save(_ project: Project, to packageURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        try data.write(to: packageURL.appendingPathComponent(projectFileName), options: .atomic)
    }

    static func load(from packageURL: URL) throws -> Project {
        let data = try Data(contentsOf: packageURL.appendingPathComponent(projectFileName))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Project.self, from: data)
    }

    static func saveMouseTrack(_ track: MouseTrack, to packageURL: URL) throws {
        let data = try JSONEncoder().encode(track)
        try data.write(to: packageURL.appendingPathComponent(mouseFileName), options: .atomic)
    }

    static func loadMouseTrack(from packageURL: URL, fileName: String) -> MouseTrack {
        let url = packageURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let track = try? JSONDecoder().decode(MouseTrack.self, from: data) else { return .empty }
        return track
    }

    static func listPackages() -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: libraryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let packages = items.filter { $0.pathExtension == packageExtension && fm.fileExists(atPath: $0.appendingPathComponent(projectFileName).path) }
        return packages.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l > r
        }
    }
}
