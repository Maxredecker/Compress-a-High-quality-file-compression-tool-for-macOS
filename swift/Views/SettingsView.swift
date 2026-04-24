import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showAdvancedImages = false
    @State private var showAdvancedVectors = false
    @State private var showAdvancedPDF = false

    private var settings: Binding<AppSettings> {
        Binding(get: { appState.settings }, set: { appState.settings = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                header
                outputFolderCard
                imagesCard
                vectorsCard
                pdfCard
                doneButton
            }
            .padding(20)
        }
        .frame(width: 400)
        .background(.ultraThickMaterial)
    }

    // MARK: — Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 15, weight: .bold))
            Spacer()
            Button {
                appState.saveSettings()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 4)
    }

    // MARK: — Output folder

    private var outputFolderCard: some View {
        SettingCard {
            SettingRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Output folder").settingLabel()
                    Text(shortPath(appState.outputDirectory.path)).settingHint()
                }
            } control: {
                Button("Choose") { appState.pickOutputDirectory() }.buttonStyle(.bordered)
            }
        }
    }

    // MARK: — Images

    private var imagesCard: some View {
        SettingCard {
            SectionTitle("🖼 Images")

            SettingRow {
                Text("Compression").settingLabel()
            } control: {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(settings.images.quality.wrappedValue) },
                        set: { settings.images.quality.wrappedValue = Int($0) }
                    ), in: 30...100, step: 1)
                    .frame(width: 120)
                    Text("\(settings.images.quality.wrappedValue)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.accent)
                        .frame(width: 28, alignment: .trailing)
                }
            }

            SettingRow {
                Text("Output formats").settingLabel()
            } control: { EmptyView() }

            HStack(spacing: 5) {
                FormatChip("JPG",  isOn: settings.images.formats.jpg)
                FormatChip("PNG",  isOn: settings.images.formats.png)
                FormatChip("WebP", isOn: settings.images.formats.webp)
                FormatChip("AVIF", isOn: settings.images.formats.avif)
                FormatChip("JXL",  isOn: settings.images.formats.jxl)
            }
            .padding(.bottom, 4)

            AdvancedToggle(label: "Advanced", isExpanded: $showAdvancedImages)

            if showAdvancedImages {
                SettingRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max longest edge").settingLabel()
                        Text("Scales down so neither side exceeds this value (px).").settingHint()
                    }
                } control: {
                    TextField("No limit", value: settings.images.maxDimension, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                SettingRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strip metadata").settingLabel()
                        Text("Removes EXIF, GPS, camera info.").settingHint()
                    }
                } control: {
                    Toggle("", isOn: settings.images.stripMetadata).labelsHidden()
                }

                SettingRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progressive JPEG").settingLabel()
                        Text("Loads blurry preview first, then sharpens.").settingHint()
                    }
                } control: {
                    Toggle("", isOn: settings.images.progressive).labelsHidden()
                }

                SettingRow(isLast: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("JXL effort").settingLabel()
                        Text("Higher = smaller files but slower. 7 is a good balance.").settingHint()
                    }
                } control: {
                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { Double(settings.images.jxlEffort.wrappedValue) },
                            set: { settings.images.jxlEffort.wrappedValue = Int($0) }
                        ), in: 1...9, step: 1)
                        .frame(width: 100)
                        Text("\(settings.images.jxlEffort.wrappedValue)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.accent)
                            .frame(width: 16, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: — Vectors

    private var vectorsCard: some View {
        SettingCard {
            SectionTitle("✏️ Vectors")

            SettingRow {
                Text("Optimize SVG").settingLabel()
            } control: {
                Toggle("", isOn: settings.vectors.enabled).labelsHidden()
            }

            AdvancedToggle(label: "Advanced", isExpanded: $showAdvancedVectors)

            if showAdvancedVectors {
                SettingRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove dimensions").settingLabel()
                        Text("Strips width/height for responsive scaling.").settingHint()
                    }
                } control: {
                    Toggle("", isOn: settings.vectors.removeDimensions).labelsHidden()
                }

                SettingRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prefix IDs").settingLabel()
                        Text("Prevents conflicts when embedding multiple SVGs.").settingHint()
                    }
                } control: {
                    Toggle("", isOn: settings.vectors.prefixIds).labelsHidden()
                }

                SettingRow(isLast: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Minify IDs").settingLabel()
                        Text("Shortens long ID names to save bytes.").settingHint()
                    }
                } control: {
                    Toggle("", isOn: settings.vectors.minifyIds).labelsHidden()
                }
            }
        }
    }

    // MARK: — PDF

    private var pdfCard: some View {
        SettingCard {
            SectionTitle("📄 PDF")

            SettingRow {
                Text("Quality").settingLabel()
            } control: {
                Picker("", selection: settings.pdfs.preset) {
                    ForEach(AppSettings.PDFSettings.Preset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            AdvancedToggle(label: "Advanced", isExpanded: $showAdvancedPDF)

            if showAdvancedPDF {
                SettingRow(isLast: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Convert to grayscale").settingLabel()
                        Text("Removes all color. Good for text-heavy documents.").settingHint()
                    }
                } control: {
                    Toggle("", isOn: settings.pdfs.grayscale).labelsHidden()
                }
            }
        }
    }

    // MARK: — Done button

    private var doneButton: some View {
        Button {
            appState.saveSettings()
            dismiss()
        } label: {
            Text("Done")
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func shortPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

// MARK: — Reusable setting components

private struct SettingCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(14)
            .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.82), lineWidth: 1))
    }
}

private struct SettingRow<Label: View, Control: View>: View {
    var isLast = false
    @ViewBuilder let label: Label
    @ViewBuilder let control: Control
    var body: some View {
        HStack { label; Spacer(minLength: 8); control }
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) {
                if !isLast { Divider().opacity(0.4) }
            }
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 13, weight: .semibold)).padding(.bottom, 6)
    }
}

private struct AdvancedToggle: View {
    let label: String
    @Binding var isExpanded: Bool
    var body: some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } } label: {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }
}

private struct FormatChip: View {
    let label: String
    @Binding var isOn: Bool
    init(_ label: String, isOn: Binding<Bool>) { self.label = label; _isOn = isOn }
    var body: some View {
        Button { isOn.toggle() } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? Color.accentColor : .tertiary)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(isOn ? Color.accentColor.opacity(0.11) : Color.black.opacity(0.055),
                            in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? Color.accentColor.opacity(0.28) : Color.black.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: — View modifiers

private extension Text {
    func settingLabel() -> some View {
        self.font(.system(size: 13))
    }
    func settingHint() -> some View {
        self.font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
