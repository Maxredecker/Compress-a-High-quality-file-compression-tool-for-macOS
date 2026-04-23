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

## Dependencies

- [sharp](https://sharp.pixelplumbing.com/) — image processing
- [svgo](https://svgo.dev/) — SVG optimization
- Optional: `jpeg-xl` (`cjxl`), `ghostscript`, `terminal-notifier`

## License

MIT
