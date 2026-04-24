import Foundation

@Observable
final class CompressionTask: Identifiable {
    let id = UUID()
    let filePath: URL
    var state: State = .processing(progress: 0.08)

    init(filePath: URL) {
        self.filePath = filePath
    }

    var filename: String { filePath.lastPathComponent }

    enum State {
        case processing(progress: Double)
        case done(Result)
        case failed(String)
    }

    struct Result {
        let originalSize: Int64
        let formats: [FormatResult]

        var bestSaved: Int {
            formats.map(\.saved).max() ?? 0
        }

        var sortedBySize: [FormatResult] {
            formats.sorted { $0.size < $1.size }
        }
    }

    struct FormatResult: Identifiable {
        let id = UUID()
        let format: String
        let size: Int64
        let saved: Int

        var sizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
}
