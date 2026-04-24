import Foundation

// SVG optimization shells out to the system Node.js + the bundled svgo binary.
// If Node.js is not available on the user's machine, SVG is skipped.
// Future option: run SVGO via JavaScriptCore to eliminate the Node.js dependency.

enum SVGOptimizer {

    private static var node: String? { shellTool(named: "node") }

    // Path to the svgo binary bundled with the app (placed in Resources/svgo)
    private static var svgo: String? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let path = resources.appendingPathComponent("svgo").path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    static var isAvailable: Bool { node != nil && svgo != nil }

    static func optimize(_ input: URL, to outputDir: URL, settings: AppSettings.VectorSettings) async throws -> CompressionTask.Result {
        guard settings.enabled else {
            return CompressionTask.Result(originalSize: 0, formats: [])
        }
        guard let node, let svgo else {
            throw CompressorError.toolNotFound("node (required for SVG optimization)")
        }

        let originalSize = Int64((try? input.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? nil ?? 0)
        let output = outputDir.appendingPathComponent(input.lastPathComponent)

        var args = [svgo, input.path, "-o", output.path, "--multipass"]

        if settings.removeDimensions { args += ["--config", #"{"plugins":["removeDimensions"]}"#] }

        try await shell(node, args)

        let newSize = Int64((try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? nil ?? 0)

        if newSize >= originalSize {
            try? FileManager.default.removeItem(at: output)
            return CompressionTask.Result(originalSize: originalSize, formats: [])
        }

        let saved = Int((1.0 - Double(newSize) / Double(originalSize)) * 100)
        return CompressionTask.Result(
            originalSize: originalSize,
            formats: [.init(format: "SVG", size: newSize, saved: saved)]
        )
    }
}
