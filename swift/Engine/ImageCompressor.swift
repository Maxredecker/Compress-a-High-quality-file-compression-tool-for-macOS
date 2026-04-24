import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

enum ImageCompressor {

    static func compress(_ input: URL, to outputDir: URL, settings: AppSettings.ImageSettings) async throws -> CompressionTask.Result {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              var image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CompressorError.unsupportedFormat(input.pathExtension) }

        let originalSize = try input.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? 0
        let baseName = input.deletingPathExtension().lastPathComponent
        let hasAlpha = image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast
        let quality = Double(settings.quality) / 100.0
        let avifQuality = quality * 0.625  // AVIF scale matches JS engine

        if let maxDim = settings.maxDimension {
            image = resize(image, maxDimension: maxDim)
        }

        if settings.stripMetadata {
            image = strip(image)
        }

        var formats: [CompressionTask.FormatResult] = []

        // PNG
        if settings.formats.png {
            let out = outputDir.appendingPathComponent("\(baseName).png")
            try write(image, to: out, type: .png, options: [kCGImageDestinationLossyCompressionQuality: quality])
            if let size = fileSize(out), size < originalSize {
                formats.append(.init(format: "PNG", size: size, saved: savings(size, originalSize)))
            } else { try? FileManager.default.removeItem(at: out) }
        }

        // JPEG
        if settings.formats.jpg {
            let out = outputDir.appendingPathComponent("\(baseName).jpg")
            let jpegImage = hasAlpha ? flatten(image) : image
            try write(jpegImage, to: out, type: .jpeg, options: [kCGImageDestinationLossyCompressionQuality: quality])
            if let size = fileSize(out), size < originalSize {
                formats.append(.init(format: "JPG", size: size, saved: savings(size, originalSize)))
            } else { try? FileManager.default.removeItem(at: out) }
        }

        // WebP (macOS 11+)
        if settings.formats.webp {
            let out = outputDir.appendingPathComponent("\(baseName).webp")
            try write(image, to: out, type: UTType("org.webmproject.webp")!, options: [kCGImageDestinationLossyCompressionQuality: quality])
            if let size = fileSize(out) {
                formats.append(.init(format: "WebP", size: size, saved: savings(size, originalSize)))
            }
        }

        // AVIF
        if settings.formats.avif {
            let out = outputDir.appendingPathComponent("\(baseName).avif")
            try write(image, to: out, type: UTType("public.avif")!, options: [kCGImageDestinationLossyCompressionQuality: avifQuality])
            if let size = fileSize(out), size < originalSize {
                formats.append(.init(format: "AVIF", size: size, saved: savings(size, originalSize)))
            } else { try? FileManager.default.removeItem(at: out) }
        }

        // JXL — shell out to cjxl
        if settings.formats.jxl, let cjxl = shellTool(named: "cjxl") {
            let out = outputDir.appendingPathComponent("\(baseName).jxl")
            let effort = max(1, min(9, settings.jxlEffort))
            let isJpeg = ["jpg", "jpeg"].contains(input.pathExtension.lowercased())
            var args = [input.path, out.path, "-q", String(settings.quality), "-e", String(effort)]
            if isJpeg { args += ["--lossless_jpeg=0"] }
            try? await shell(cjxl, args)
            if let size = fileSize(out), size < originalSize {
                formats.append(.init(format: "JXL", size: size, saved: savings(size, originalSize)))
            } else { try? FileManager.default.removeItem(at: out) }
        }

        return CompressionTask.Result(originalSize: originalSize, formats: formats)
    }

    // MARK: — Helpers

    private static func write(_ image: CGImage, to url: URL, type: UTType, options: [CFString: Any]) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw CompressorError.processFailed("CGImageDestination", -1)
        }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CompressorError.processFailed("CGImageDestinationFinalize", -1)
        }
    }

    private static func resize(_ image: CGImage, maxDimension: Int) -> CGImage {
        let w = image.width, h = image.height
        let scale = min(CGFloat(maxDimension) / CGFloat(max(w, h)), 1.0)
        guard scale < 1 else { return image }
        let nw = Int(CGFloat(w) * scale), nh = Int(CGFloat(h) * scale)
        let ctx = CGContext(data: nil, width: nw, height: nh,
                           bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        return ctx.makeImage() ?? image
    }

    private static func flatten(_ image: CGImage) -> CGImage {
        let ctx = CGContext(data: nil, width: image.width, height: image.height,
                           bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    private static func strip(_ image: CGImage) -> CGImage {
        // Stripping metadata is handled automatically by CGImageDestination
        // when not copying source properties — no explicit step needed.
        return image
    }

    private static func fileSize(_ url: URL) -> Int64? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? nil
    }

    private static func savings(_ new: Int64, _ original: Int64) -> Int {
        Int((1.0 - Double(new) / Double(original)) * 100)
    }
}
