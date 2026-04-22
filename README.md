# Compress

A local file compression toolkit for macOS. Drop files into a folder and get optimized versions automatically — with native macOS notifications.

## What it does

Drop an image, SVG, or PDF into a watch folder. Compress generates optimized versions in multiple formats and notifies you when done.

### Supported formats

| Input | Output | Engine |
|-------|--------|--------|
| JPG / JPEG | JPG (MozJPEG), WebP, AVIF, JXL | sharp, cjxl |
| PNG | PNG (palette quantization), WebP, AVIF, JXL | sharp, cjxl |
| AVIF | JPG, WebP, AVIF, JXL | sharp, cjxl |
| SVG | SVG (optimized) | SVGO |
| PDF | PDF (compressed) | Ghostscript |

### Smart defaults

- **Only keeps smaller files** — if a compressed format is larger than the original, it's discarded (except WebP, which is always generated for web compatibility)
- **Screencapture detection** — files with "screencapture" in the name are only compressed to JPG (no need for multi-format output)
- **Large image splitting** — screenshots exceeding 32 megapixels (e.g. Miro board captures) are automatically split into parts
- **Transparency detection** — PNGs with alpha channels get palette-quantized PNG output; opaque images get JPG
- **Color preservation** — PDF compression preserves original color profiles

## Installation

### Prerequisites

- **Node.js** ≥ 18
- **Homebrew** (macOS)

### Setup

```bash
git clone https://github.com/user/compress.git
cd compress
npm install
```

Install optional system dependencies for full format support:

```bash
# JPEG XL encoder (optional — skipped gracefully if not installed)
brew install jpeg-xl

# PDF compression (optional — skipped gracefully if not installed)
brew install ghostscript

# macOS notifications with click-to-open (optional — falls back to console output)
brew install terminal-notifier
```

### Configure paths

The scripts use hardcoded paths for Homebrew binaries (`/opt/homebrew/bin/`) which is the default on Apple Silicon. If you're on Intel Mac, update the paths in `watch.mjs`:

```javascript
// Apple Silicon (default)
'/opt/homebrew/bin/cjxl'
'/opt/homebrew/bin/gs'
'/opt/homebrew/bin/terminal-notifier'

// Intel Mac
'/usr/local/bin/cjxl'
'/usr/local/bin/gs'
'/usr/local/bin/terminal-notifier'
```

## Usage

### Watch mode (recommended)

Watches a folder and compresses new files automatically:

```bash
node watch.mjs ~/Downloads/compress
```

Compressed files appear in `~/Downloads/compress/compressed/`. Original files are removed after processing.

### Batch mode

Compress all files in a folder once:

```bash
node compress.mjs ~/Downloads/compress
```

### Run at startup (macOS LaunchAgent)

Create `~/Library/LaunchAgents/com.compress.watch.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.compress.watch</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/node</string>
        <string>/path/to/compress/watch.mjs</string>
        <string>/path/to/watch/folder</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/path/to/compress/watch.log</string>
    <key>StandardErrorPath</key>
    <string>/path/to/compress/watch-error.log</string>
</dict>
</plist>
```

Then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.compress.watch.plist
```

To restart after code changes:

```bash
launchctl stop com.compress.watch && launchctl start com.compress.watch
```

## Output example

Console output after dropping a photo:

```
✓ photo.jpg  │  JPG 564.9 KB (−56%)  │  WebP 475.8 KB (−63%)  │  AVIF 312.4 KB (−76%)  │  JXL 580.8 KB (−55%)
```

macOS notification:

```
photo.jpg
JPG 564.9 KB, WebP 475.8 KB, AVIF 312.4 KB, JXL 580.8 KB (−76%)
```

Clicking the notification opens the `compressed/` folder in Finder.

## Quality settings

Defaults are tuned for visually lossless compression at significant size reduction:

| Format | Quality | Notes |
|--------|---------|-------|
| JPEG | 80 | MozJPEG encoder — sharper than standard JPEG at same size |
| WebP | 80 | Always generated for universal browser support |
| AVIF | 50 | AVIF scale differs — 50 ≈ JPEG 80 perceptual quality |
| JXL | 80 | Supports progressive decoding (loads preview before full image) |
| PNG | 85 | Palette quantization with max compression effort |
| PDF | printer | Ghostscript 300dpi — good balance of quality and size |
| SVG | — | SVGO multipass with preset-default |

## Dependencies

### npm

- [sharp](https://sharp.pixelplumbing.com/) — image processing (JPG, PNG, WebP, AVIF)
- [svgo](https://svgo.dev/) — SVG optimization

### System (via Homebrew, all optional)

- [jpeg-xl](https://jpeg.org/jpegxl/) — JPEG XL encoding via `cjxl`
- [ghostscript](https://www.ghostscript.com/) — PDF compression
- [terminal-notifier](https://github.com/julienXX/terminal-notifier) — macOS notifications

## License

MIT
