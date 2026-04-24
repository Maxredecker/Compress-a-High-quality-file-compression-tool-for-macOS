# Xcode project setup

## New project

1. Open Xcode → File → New → Project
2. Choose **macOS → App**
3. Product name: `Feather`
4. Bundle identifier: `nl.studiomaxredecker.Feather`
5. Interface: **SwiftUI**, Language: **Swift**
6. Uncheck "Include Tests" (add later)

## Add source files

Delete the default `ContentView.swift` and `<AppName>App.swift` Xcode generates, then drag in all files from this `swift/` directory — keeping the group structure:

```
App/        → FeatherApp.swift, AppState.swift
Models/     → AppSettings.swift, FeatherionTask.swift
Engine/     → Featheror.swift, ImageFeatheror.swift, PDFFeatheror.swift, SVGOptimizer.swift
Views/      → ContentView.swift, ResultRowView.swift, SettingsView.swift
```

## Minimum deployment target

Set to **macOS 26** in the project target settings.  
macOS 26 gives native `.glassEffect()`, the latest `@Observable`, `.windowStyle(.hiddenTitleBar)`, and full WebP/AVIF via ImageIO.

> Note: macOS 14 (Sonoma) and 15 (Sequoia) do exist — Apple jumped from 15 to 26 in 2025 to align version numbers with the calendar year.

## Entitlements

The app shells out to `gs` and `cjxl`. If distributing outside the Mac App Store, no sandbox is needed. If targeting the App Store, the sandbox will block `Process` — in that case, bundle the binaries as app resources instead.

Add to `Feather.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

Or for sandboxed App Store distribution:
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```
(And bundle `gs`/`cjxl` as resources — sandboxed apps cannot call arbitrary system binaries.)

## SVG: bundling svgo

SVGOptimizer shells out to `node + svgo`. To bundle svgo as a resource:

```bash
cd <project root>
npx svgo --help   # confirms svgo is installed
# Copy node_modules/.bin/svgo to Resources/svgo in the Xcode project
```

Or skip SVG support for the first release and add it later.

## Dependencies

None. All image compression uses `ImageIO` (built-in). JXL and PDF still rely on system tools.

| Feature | Dependency | Status |
|---------|-----------|--------|
| JPG / PNG / WebP / AVIF | `ImageIO` (built-in) | ✓ No install needed |
| JPEG XL | `cjxl` via Homebrew | Optional: `brew install jpeg-xl` |
| PDF | `gs` via Homebrew | Optional: `brew install ghostscript` |
| SVG | `node` + bundled `svgo` | Optional — see above |
