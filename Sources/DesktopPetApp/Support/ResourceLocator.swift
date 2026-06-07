import Foundation

enum ResourceLocator {
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        let fileName = "\(name).\(ext)"
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(fileName),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(fileName)")
        ]

        for candidate in candidates {
            guard let url = candidate else { continue }
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
