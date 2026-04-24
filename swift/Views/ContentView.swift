import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            titlebar
            main
        }
        .background(background)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(appState)
        }
        .onDrop(of: Compressor.allowedTypes, isTargeted: $isDragOver) { providers in
            Task {
                let urls = await resolveDroppedItems(providers)
                appState.processFiles(urls)
            }
            return true
        }
    }

    // MARK: — Titlebar

    private var titlebar: some View {
        HStack {
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .regular))
            }
            Button {
                // info sheet
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .regular))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 52)
    }

    // MARK: — Main

    private var main: some View {
        VStack(spacing: 10) {
            if appState.tasks.isEmpty {
                dropZoneFull
            } else {
                dropZoneCompact
                resultsList
            }
            footer
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: — Drop zones

    private var dropZoneFull: some View {
        Button(action: appState.pickFiles) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
                VStack(spacing: 4) {
                    Text("Drop files or click to select").fontWeight(.semibold)
                    Text("Add more anytime")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 14))
                Text("JPG · PNG · AVIF · SVG · PDF")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(isDragOver ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1.5, dash: isDragOver ? [] : [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private var dropZoneCompact: some View {
        Button(action: appState.pickFiles) {
            HStack(spacing: 9) {
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Add more files")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: — Results

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(appState.tasks) { task in
                    ResultRowView(task: task) {
                        appState.openOutputDirectory()
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    // MARK: — Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: appState.openOutputDirectory) {
                Text(shortPath(appState.outputDirectory.path))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .buttonStyle(.plain)

            if !appState.tasks.isEmpty {
                Button("Clear all") { appState.clearAll() }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: — Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.84, green: 0.91, blue: 0.97),
                Color(red: 0.93, green: 0.88, blue: 0.97),
                Color(red: 0.82, green: 0.93, blue: 0.89),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: — Helpers

    private func shortPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func resolveDroppedItems(_ providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for provider in providers {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        _ = provider.loadFileRepresentation(forTypeIdentifier: "public.file-url") { url, _ in
                            continuation.resume(returning: url)
                        }
                    }
                }
            }
            return await group.reduce(into: []) { if let url = $1 { $0.append(url) } }
        }
    }
}
