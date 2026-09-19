import Foundation
import Observation

struct LibraryRecording: Identifiable, Hashable {
    let url: URL
    let identity: FileIdentity?
    let createdAt: Date
    let duration: Double

    var id: URL { url }
    var name: String { ProjectStore.name(of: url) }
}

enum LibraryPeriod: CaseIterable {
    case today
    case yesterday
    case previousWeek
    case older

    var title: String {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .previousWeek: "Previous 7 Days"
        case .older: "Older"
        }
    }

    static func containing(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> LibraryPeriod {
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date > weekAgo { return .previousWeek }
        return .older
    }
}

struct LibraryGroup: Identifiable {
    let period: LibraryPeriod
    let recordings: [LibraryRecording]

    var id: LibraryPeriod { period }
}

@MainActor
@Observable
final class StudioLibrary {
    private(set) var recordings: [LibraryRecording] = []
    var selection: URL?
    @ObservationIgnored private var folderWatcher: DispatchSourceFileSystemObject?

    var current: LibraryRecording? {
        selection.flatMap(recording(at:))
    }

    func recording(at url: URL) -> LibraryRecording? {
        recordings.first { $0.url.standardizedFileURL.path == url.standardizedFileURL.path }
    }

    var groups: [LibraryGroup] {
        let byPeriod = Dictionary(grouping: recordings) { LibraryPeriod.containing($0.createdAt) }
        return LibraryPeriod.allCases.compactMap { period in
            guard let items = byPeriod[period], !items.isEmpty else { return nil }
            return LibraryGroup(period: period, recordings: items)
        }
    }

    func refresh() {
        let previous = current
        recordings = ProjectStore.listPackages()
            .compactMap { url in
                guard let project = try? ProjectStore.load(from: url) else { return nil }
                return LibraryRecording(url: url, identity: ProjectStore.fileIdentity(of: url), createdAt: project.createdAt, duration: project.recording.duration)
            }
            .sorted { $0.createdAt > $1.createdAt }
        selection = selection.flatMap(recording(at:))?.url
            ?? previous.flatMap(recording(matching:))?.url
            ?? recordings.first?.url
        watchLibraryFolder()
    }

    private func recording(matching previous: LibraryRecording) -> LibraryRecording? {
        guard let identity = previous.identity else { return nil }
        return recordings.first { $0.identity == identity }
    }

    private func watchLibraryFolder() {
        guard folderWatcher == nil else { return }
        let descriptor = Darwin.open(ProjectStore.libraryURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        watcher.setEventHandler { [weak self] in self?.refresh() }
        watcher.setCancelHandler { Darwin.close(descriptor) }
        watcher.resume()
        folderWatcher = watcher
    }

    func open(_ url: URL) {
        refresh()
        selection = recording(at: url)?.url ?? url
    }

    @discardableResult
    func rename(_ url: URL, to name: String) throws -> URL {
        let renamed = try ProjectStore.rename(url, to: name)
        if selection == url { selection = renamed }
        refresh()
        return renamed
    }

    func moveToTrash(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        refresh()
    }
}
