import Foundation

final class SettingsStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> AppSettings {
        let url = settingsURL()

        guard
            let data = try? Data(contentsOf: url),
            let settings = try? decoder.decode(AppSettings.self, from: data)
        else {
            return .defaultValue
        }

        return settings
    }

    func save(_ settings: AppSettings) {
        let url = settingsURL()
        let directoryURL = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let data = try encoder.encode(settings)
            try data.write(to: url, options: [.atomic])
        } catch {
            fputs("Failed to save settings: \(error)\n", stderr)
        }
    }

    private func settingsURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return applicationSupport
            .appendingPathComponent("Purrsor", isDirectory: true)
            .appendingPathComponent("settings.json")
    }
}
