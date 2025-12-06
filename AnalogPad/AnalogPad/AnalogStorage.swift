import Foundation

struct AnalogBoardState: Codable {
    var activeCards: [CardTab: AnalogCard]
    var archive: [AnalogCard]
    var selectedTab: CardTab
}

@MainActor
final class AnalogBoardStorage {
    private let fileURL: URL

    init(filename: String = "analog-board.json") {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = support?.appendingPathComponent("AnalogPad", isDirectory: true)
        if let directory, !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        fileURL = (directory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent(filename)
    }

    func load() -> AnalogBoardState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(AnalogBoardState.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ state: AnalogBoardState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // If persistence fails, we let the app continue; errors can be logged later.
        }
    }
}
