import Foundation
import UniformTypeIdentifiers

enum Compressor {

    static let allowedTypes: [UTType] = [.jpeg, .png, .heic, .gif, .svg, .pdf,
                                          UTType("public.avif"), UTType("org.webmproject.webp")]
        .compactMap { $0 }

    static func supports(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "avif", "webp", "svg", "pdf"].contains(ext)
    }

    static func compress(task: CompressionTask, outputDir: URL, settings: AppSettings) async {
        let url = task.filePath
        let ext = url.pathExtension.lowercased()

        do {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let result: CompressionTask.Result = switch ext {
            case "pdf":
                try await PDFCompressor.compress(url, to: outputDir, settings: settings.pdfs)
            case "svg":
                try await SVGOptimizer.optimize(url, to: outputDir, settings: settings.vectors)
            default:
                try await ImageCompressor.compress(url, to: outputDir, settings: settings.images)
            }

            await MainActor.run { task.state = .done(result) }

        } catch {
            await MainActor.run { task.state = .failed(error.localizedDescription) }
        }
    }
}

// MARK: — Helpers

func fileByteCount(_ url: URL) -> Int64 {
    Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? nil ?? 0)
}

func shellTool(named name: String) -> String? {
    let candidates = [
        "/opt/homebrew/bin/\(name)",
        "/usr/local/bin/\(name)",
        "/usr/bin/\(name)",
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
}

func shell(_ executable: String, _ args: [String]) async throws {
    try await withCheckedThrowingContinuation { continuation in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                continuation.resume()
            } else {
                continuation.resume(throwing: CompressorError.processFailed(executable, Int(process.terminationStatus)))
            }
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

enum CompressorError: LocalizedError {
    case toolNotFound(String)
    case processFailed(String, Int)
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):   return "\(tool) not found. Install with: brew install \(tool)"
        case .processFailed(let t, let c): return "\(t) exited with code \(c)"
        case .unsupportedFormat(let ext): return "Unsupported format: \(ext)"
        }
    }
}
