import Foundation

enum PDFCompressor {

    static func compress(_ input: URL, to outputDir: URL, settings: AppSettings.PDFSettings) async throws -> CompressionTask.Result {
        guard let gs = shellTool(named: "gs") else {
            throw CompressorError.toolNotFound("ghostscript")
        }

        let originalSize = fileByteCount(input)
        let baseName = input.deletingPathExtension().lastPathComponent
        let output = outputDir.appendingPathComponent("\(baseName).pdf")

        var args: [String] = [
            "-sDEVICE=pdfwrite",
            "-dCompatibilityLevel=1.5",
            "-dPDFSETTINGS=/\(settings.preset.rawValue)",
            "-dNOPAUSE", "-dBATCH", "-dQUIET",
            "-dEncodeColorImages=true",
            "-dAutoFilterColorImages=true",
        ]

        if settings.grayscale {
            args += ["-sColorConversionStrategy=Gray", "-dProcessColorModel=/DeviceGray"]
        } else {
            args += ["-dColorConversionStrategy=/LeaveColorUnchanged"]
        }

        args += ["-sOutputFile=\(output.path)", input.path]

        try await shell(gs, args)

        let newSize = fileByteCount(output)

        if newSize >= originalSize {
            try? FileManager.default.removeItem(at: output)
            return CompressionTask.Result(originalSize: originalSize, formats: [])
        }

        let saved = Int((1.0 - Double(newSize) / Double(originalSize)) * 100)
        return CompressionTask.Result(
            originalSize: originalSize,
            formats: [.init(format: "PDF", size: newSize, saved: saved)]
        )
    }
}
