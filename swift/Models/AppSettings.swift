import Foundation

struct AppSettings: Codable, Equatable {

    var outputDirectory: String?

    var images = ImageSettings()
    var vectors = VectorSettings()
    var pdfs = PDFSettings()

    // MARK: — Images

    struct ImageSettings: Codable, Equatable {
        var quality: Int = 80
        var formats = FormatSettings()
        var maxDimension: Int? = nil
        var stripMetadata: Bool = true
        var progressive: Bool = true
        var jxlEffort: Int = 7

        struct FormatSettings: Codable, Equatable {
            var jpg:  Bool = true
            var png:  Bool = true
            var webp: Bool = true
            var avif: Bool = true
            var jxl:  Bool = true
        }
    }

    // MARK: — Vectors

    struct VectorSettings: Codable, Equatable {
        var enabled: Bool = true
        var removeDimensions: Bool = false
        var prefixIds: Bool = false
        var minifyIds: Bool = true
    }

    // MARK: — PDF

    struct PDFSettings: Codable, Equatable {
        var preset: Preset = .printer
        var grayscale: Bool = false

        enum Preset: String, Codable, CaseIterable, Identifiable {
            case screen, ebook, printer, prepress
            var id: String { rawValue }
            var label: String {
                switch self {
                case .screen:   return "Screen — 72dpi"
                case .ebook:    return "Ebook — 150dpi"
                case .printer:  return "Print — 300dpi"
                case .prepress: return "Prepress"
                }
            }
        }
    }

    // MARK: — Persistence

    private static let key = "appSettings"

    static func load() -> AppSettings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: AppSettings.key)
    }
}
