# Compress

High-quality file compression tool for macOS.

## Two versions in this repository

This project intentionally keeps both variants:

- **CLI (non-GUI)**: terminal-based workflow via `watch.mjs` and `compress.mjs`.
- **GUI (Electron app)**: drag-and-drop desktop app with settings and previews.

The non-GUI version remains supported and is preserved alongside the GUI version.

## GUI quick start

```bash
npm install
npm start
```

## Build (GUI)

```bash
npm run build
```

Additional build targets:

- `npm run build:dmg`
- `npm run build:dir`

## Test

```bash
npm test
```

## CLI usage

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

## Supported formats

| Input | Output | Engine |
|-------|--------|--------|
| JPG / JPEG | JPG (MozJPEG), WebP, AVIF, JXL | sharp, cjxl |
| PNG | PNG (palette quantization), WebP, AVIF, JXL | sharp, cjxl |
| AVIF | JPG, WebP, AVIF, JXL | sharp, cjxl |
| SVG | SVG (optimized) | SVGO |
| PDF | PDF (compressed) | Ghostscript |

## Open-source modules and licenses

| Module | Usage in this project | License | Links |
|-------|------------------------|---------|-------|
| `sharp` | Image conversion and compression (JPG/PNG/WebP/AVIF) | Apache-2.0 | [Project](https://sharp.pixelplumbing.com/), [License](https://github.com/lovell/sharp/blob/main/LICENSE) |
| `svgo` | SVG optimization | MIT | [Project](https://svgo.dev/), [License](https://github.com/svg/svgo/blob/main/LICENSE) |
| `electron` | Desktop app runtime for the GUI | MIT | [Project](https://www.electronjs.org/), [License](https://github.com/electron/electron/blob/main/LICENSE) |
| `electron-builder` | Packaging the app for macOS builds | MIT | [Project](https://www.electron.build/), [License](https://github.com/electron-userland/electron-builder/blob/master/LICENSE) |
| `jpeg-xl` (`cjxl`) *(optional system dependency)* | JPEG XL encoding output | BSD-3-Clause | [Project](https://jpeg.org/jpegxl/), [License](https://github.com/libjxl/libjxl/blob/main/LICENSE) |
| `ghostscript` *(optional system dependency)* | PDF compression | AGPL-3.0-or-later | [Project](https://www.ghostscript.com/), [License](https://ghostscript.com/licensing/) |
| `terminal-notifier` *(optional system dependency)* | Native macOS notifications in CLI flow | MIT | [Project](https://github.com/julienXX/terminal-notifier), [License](https://github.com/julienXX/terminal-notifier/blob/master/LICENSE) |
| `DM Sans` | UI typeface in GUI | OFL-1.1 | [Project](https://fonts.google.com/specimen/DM+Sans), [License](https://openfontlicense.org/) |

## License

MIT
