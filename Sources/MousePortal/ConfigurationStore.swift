import Foundation
import MousePortalCore

enum ConfigurationStore {
    enum ImportError: LocalizedError {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedSchema(let version):
                "Configuration schema \(version) is newer than this version of MousePortal supports."
            }
        }
    }

    private static let defaultsKey = "MousePortal.Configuration.v1"

    static func load() -> AppConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let configuration = try? decoder.decode(AppConfiguration.self, from: data)
        else {
            return AppConfiguration()
        }
        return configuration
    }

    static func save(_ configuration: AppConfiguration) {
        guard let data = try? encoder.encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func export(_ configuration: AppConfiguration, to url: URL) throws {
        let data = try encoder.encode(configuration)
        try data.write(to: url, options: .atomic)
    }

    static func importConfiguration(from url: URL) throws -> AppConfiguration {
        let data = try Data(contentsOf: url)
        let configuration = try decoder.decode(AppConfiguration.self, from: data)
        guard configuration.schemaVersion <= 1 else {
            throw ImportError.unsupportedSchema(configuration.schemaVersion)
        }
        return configuration
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
