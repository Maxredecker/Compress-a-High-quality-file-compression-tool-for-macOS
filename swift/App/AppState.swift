import SwiftUI
import AppKit

@Observable
final class AppState {
    var tasks: [CompressionTask] = []
    var settings: AppSettings = .load()

    var outputDirectory: URL {
        if let saved = settings.outputDirectory {
            return URL(fileURLWithPath: saved)
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("compressed")
    }

    // MARK: — Files

    func processFiles(_ urls: [URL]) {
        let supported = urls.filter { Compressor.supports($0) }
        guard !supported.isEmpty else { return }

        for url in supported {
            let task = CompressionTask(filePath: url)
            tasks.append(task)

            Task {
                await Compressor.compress(task: task, outputDir: outputDirectory, settings: settings)
            }
        }
    }

    func clearAll() {
        tasks.removeAll()
    }

    // MARK: — Settings

    func saveSettings() {
        settings.save()
    }

    // MARK: — Panels

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Compressor.allowedTypes

        if panel.runModal() == .OK {
            processFiles(panel.urls)
        }
    }

    func pickOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url.path
            saveSettings()
        }
    }

    func openOutputDirectory() {
        NSWorkspace.shared.open(outputDirectory)
    }
}
