import SwiftUI

struct ResultRowView: View {
    let task: CompressionTask
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            thumbnail
            content
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { if case .done = task.state { onTap() } }
        .animation(.easeInOut(duration: 0.2), value: stateID)
    }

    // MARK: — Thumbnail

    private var thumbnail: some View {
        Group {
            if let image = loadThumbnail() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(iconLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 48, height: 48)
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: — Content

    @ViewBuilder
    private var content: some View {
        switch task.state {
        case .processing(let progress):
            processingView(progress: progress)
        case .done(let result):
            doneView(result: result)
        case .failed(let error):
            failedView(error: error)
        }
    }

    private func processingView(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.filename)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Color(red: 0.2, green: 0.67, blue: 0.87))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }

    private func doneView(result: CompressionTask.Result) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(task.filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(ByteCountFormatter.string(fromByteCount: result.originalSize, countStyle: .file))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                if result.bestSaved > 0 {
                    Text("−\(result.bestSaved)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(savedColor(result.bestSaved))
                } else {
                    Text("—").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                }
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))
            }
            HStack(spacing: 4) {
                ForEach(result.sortedBySize) { fmt in
                    formatChip(fmt, isBest: fmt.id == result.sortedBySize.first?.id)
                }
            }
        }
    }

    private func failedView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.filename)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    private func formatChip(_ fmt: CompressionTask.FormatResult, isBest: Bool) -> some View {
        Text("\(fmt.format) \(fmt.sizeFormatted)")
            .font(.system(size: 10, weight: isBest ? .semibold : .regular))
            .foregroundStyle(isBest ? Color(red: 0, green: 0.47, blue: 0.25) : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                isBest ? Color.green.opacity(0.1) : Color.black.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isBest ? Color.green.opacity(0.22) : Color.black.opacity(0.07), lineWidth: 1)
            )
    }

    // MARK: — Helpers

    private var iconLabel: String {
        let ext = task.filePath.pathExtension.uppercased()
        return ["PDF", "SVG"].contains(ext) ? ext : "···"
    }

    private var stateID: String {
        switch task.state {
        case .processing: return "processing"
        case .done:       return "done"
        case .failed:     return "failed"
        }
    }

    private func loadThumbnail() -> NSImage? {
        let ext = task.filePath.pathExtension.lowercased()
        guard ["jpg", "jpeg", "png", "avif", "webp", "gif", "heic"].contains(ext) else { return nil }
        guard let img = NSImage(contentsOf: task.filePath) else { return nil }
        return img
    }

    private func savedColor(_ pct: Int) -> Color {
        pct > 50 ? Color(red: 0.1, green: 0.5, blue: 0.24)
                 : pct > 20 ? Color(red: 0.5, green: 0.42, blue: 0.1)
                            : Color(red: 0.63, green: 0.5, blue: 0.35)
    }
}
