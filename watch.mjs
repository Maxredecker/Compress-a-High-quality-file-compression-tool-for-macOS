import sharp from 'sharp';
import { optimize } from 'svgo';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { watch } from 'fs';
import { stat, readFile, readdir, unlink, writeFile, mkdir } from 'fs/promises';
import { join } from 'path';

const exec = promisify(execFile);

// --- Configuration ---
const dir = process.argv[2] || '.';
const jpegQuality = 80;
const pngQuality = 85;
const webpQuality = 80;
const jxlQuality = 80;
const avifQuality = 50;
const MAX_MP = 32_000_000; // Miro's 32 megapixel upload limit

// Binary paths (Homebrew on Apple Silicon — change to /usr/local/bin/ for Intel Mac)
const CJXL = '/opt/homebrew/bin/cjxl';
const GS = '/opt/homebrew/bin/gs';
const NOTIFIER = '/opt/homebrew/bin/terminal-notifier';

const outDir = join(dir, 'compressed');
await mkdir(outDir, { recursive: true });

// --- Notifications ---
function notify(title, message) {
  execFile(NOTIFIER, [
    '-title', title,
    '-message', message,
    '-sound', 'Glass',
    '-open', `file://${outDir}`,
  ]);
}

// --- Deduplication ---
const handled = new Set();
function scheduleOnce(file, fn, delay = 2000) {
  if (handled.has(file)) return;
  handled.add(file);
  setTimeout(async () => {
    try { await fn(); } catch {}
  }, delay);
}

// --- Helpers ---
function shortName(file) {
  if (file.length <= 35) return file;
  const ext = file.match(/\.[^.]+$/)?.[0] || '';
  const maxName = 35 - ext.length - 1;
  const start = file.slice(0, Math.ceil(maxName / 2));
  const end = file.slice(file.length - ext.length - Math.floor(maxName / 2), file.length - ext.length);
  return `${start}…${end}${ext}`;
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

async function toJxl(inputPath, outputPath) {
  const isJpeg = /\.jpe?g$/i.test(inputPath);
  const args = isJpeg
    ? [inputPath, outputPath, '-q', String(jxlQuality), '--lossless_jpeg=0', '-e', '7']
    : [inputPath, outputPath, '-q', String(jxlQuality), '-e', '7'];
  await exec(CJXL, args);
}

async function safeUnlink(path) {
  try { await unlink(path); } catch {}
}

// --- PDF compression ---
async function compressPdf(file) {
  try {
    const input = join(dir, file);
    const originalSize = (await stat(input)).size;
    const baseName = file.replace(/\.pdf$/i, '');
    const output = join(outDir, `${baseName}.pdf`);

    await exec(GS, [
      '-sDEVICE=pdfwrite',
      '-dCompatibilityLevel=1.5',
      '-dPDFSETTINGS=/printer',
      '-dNOPAUSE',
      '-dBATCH',
      '-dQUIET',
      '-dColorConversionStrategy=/LeaveColorUnchanged',
      '-dEncodeColorImages=true',
      '-dAutoFilterColorImages=true',
      `-sOutputFile=${output}`,
      input,
    ]);

    const newSize = (await stat(output)).size;
    if (newSize < originalSize) {
      const saved = Math.round((1 - newSize / originalSize) * 100);
      console.log(`✓ ${file}  │  PDF ${formatSize(newSize)} (−${saved}%)`);
      notify(shortName(file), `PDF ${formatSize(newSize)} (−${saved}%)`);
    } else {
      await safeUnlink(output);
      console.log(`⊘ ${file} — PDF niet kleiner, overgeslagen`);
    }
    await unlink(input);
  } catch (e) {
    console.error(`✗ ${file} (PDF) — ${e.message}`);
  }
}

// --- SVG compression ---
async function compressSvg(file) {
  try {
    const input = join(dir, file);
    const svg = await readFile(input, 'utf8');
    const result = optimize(svg, {
      path: input,
      multipass: true,
      plugins: [
        'preset-default',
        'sortAttrs',
        { name: 'removeAttrs', params: { attrs: ['data-name'] } },
      ],
    });

    if (result.data.length < svg.length) {
      const output = join(outDir, file);
      await writeFile(output, result.data);
      const saved = Math.round((1 - result.data.length / svg.length) * 100);
      console.log(`✓ ${file} (SVG −${saved}%)`);
      notify(shortName(file), `SVG −${saved}%`);
    } else {
      console.log(`⊘ ${file} — SVG niet kleiner, overgeslagen`);
    }
    await unlink(input);
  } catch (e) {
    console.error(`✗ ${file} (SVG) — ${e.message}`);
  }
}

// --- Image compression ---
async function compress(file) {
  try {
    const input = join(dir, file);
    const image = sharp(input);
    const metadata = await image.metadata();
    const pixels = metadata.width * metadata.height;
    const baseName = file.replace(/\.(png|jpg|jpeg|avif)$/i, '');
    const isPng = /\.png$/i.test(file);
    const hasAlpha = metadata.hasAlpha && isPng;
    const isScreencapture = file.toLowerCase().includes('screencapture');
    const originalSize = (await stat(input)).size;

    if (isScreencapture && pixels > MAX_MP) {
      const maxHeight = Math.floor(MAX_MP / metadata.width);
      const parts = Math.ceil(metadata.height / maxHeight);

      for (let i = 0; i < parts; i++) {
        const top = i * maxHeight;
        const height = Math.min(maxHeight, metadata.height - top);
        const partName = `${baseName}_${i + 1}`;
        const extract = { left: 0, top, width: metadata.width, height };

        const results = await compressToFormats(input, partName, hasAlpha, originalSize, isScreencapture, extract);
        logResults(file, results, originalSize, `part ${i + 1}/${parts}`);
      }
    } else {
      const results = await compressToFormats(input, baseName, hasAlpha, originalSize, isScreencapture);
      logResults(file, results, originalSize);
    }

    await unlink(input);
  } catch (e) {
    console.error(`✗ ${file} — ${e.message}`);
  }
}

async function compressToFormats(input, baseName, hasAlpha, originalSize, isScreencapture, extract) {
  const results = [];

  // Screencaptures: JPG only
  if (isScreencapture) {
    const jpgOut = join(outDir, `${baseName}.jpg`);
    let img = sharp(input);
    if (extract) img = img.extract(extract);
    await img.jpeg({ quality: jpegQuality, mozjpeg: true }).toFile(jpgOut);
    const size = (await stat(jpgOut)).size;
    if (size < originalSize) {
      results.push({ format: 'JPG', path: jpgOut, size });
    } else {
      await safeUnlink(jpgOut);
    }
    return results;
  }

  // PNG (only if transparency)
  if (hasAlpha) {
    const pngOut = join(outDir, `${baseName}.png`);
    let img = sharp(input);
    if (extract) img = img.extract(extract);
    await img.png({ palette: true, quality: pngQuality, compressionLevel: 9, effort: 10 }).toFile(pngOut);
    const size = (await stat(pngOut)).size;
    if (size < originalSize) {
      results.push({ format: 'PNG', path: pngOut, size });
    } else {
      await safeUnlink(pngOut);
    }
  }

  // JPEG (only if no transparency)
  if (!hasAlpha) {
    const jpgOut = join(outDir, `${baseName}.jpg`);
    let img = sharp(input);
    if (extract) img = img.extract(extract);
    await img.jpeg({ quality: jpegQuality, mozjpeg: true }).toFile(jpgOut);
    const size = (await stat(jpgOut)).size;
    if (size < originalSize) {
      results.push({ format: 'JPG', path: jpgOut, size });
    } else {
      await safeUnlink(jpgOut);
    }
  }

  // WebP (always saved — universal browser support)
  const webpOut = join(outDir, `${baseName}.webp`);
  let img = sharp(input);
  if (extract) img = img.extract(extract);
  await img.webp({ quality: webpQuality, effort: 6 }).toFile(webpOut);
  const webpSize = (await stat(webpOut)).size;
  results.push({ format: 'WebP', path: webpOut, size: webpSize });

  // AVIF
  const avifOut = join(outDir, `${baseName}.avif`);
  let imgAvif = sharp(input);
  if (extract) imgAvif = imgAvif.extract(extract);
  await imgAvif.avif({ quality: avifQuality, effort: 6 }).toFile(avifOut);
  const avifSize = (await stat(avifOut)).size;
  if (avifSize < originalSize) {
    results.push({ format: 'AVIF', path: avifOut, size: avifSize });
  } else {
    await safeUnlink(avifOut);
  }

  // JPEG XL via cjxl (direct on source file)
  try {
    const jxlOut = join(outDir, `${baseName}.jxl`);
    await toJxl(input, jxlOut);
    const jxlSize = (await stat(jxlOut)).size;
    if (jxlSize < originalSize) {
      results.push({ format: 'JXL', path: jxlOut, size: jxlSize });
    } else {
      await safeUnlink(jxlOut);
    }
  } catch {
    // cjxl not available — skip JXL
  }

  return results;
}

// --- Logging ---
function logResults(file, results, originalSize, suffix) {
  const prefix = suffix ? `${file} → ${suffix}` : file;
  if (results.length === 0) {
    console.log(`⊘ ${prefix} — no format smaller than original (${formatSize(originalSize)})`);
    return;
  }

  const comparison = results
    .map(r => {
      const saved = Math.round((1 - r.size / originalSize) * 100);
      return `${r.format} ${formatSize(r.size)} (−${saved}%)`;
    })
    .join('  │  ');
  console.log(`✓ ${prefix}  │  ${comparison}`);

  const bestSaved = Math.max(...results.map(r => Math.round((1 - r.size / originalSize) * 100)));
  const formats = results.map(r => `${r.format} ${formatSize(r.size)}`).join(', ');
  notify(shortName(file), `${formats} (−${bestSaved}%)`);
}

// --- Startup: process existing files ---
const existingSvg = (await readdir(dir)).filter(f => /\.svg$/i.test(f));
for (const file of existingSvg) {
  handled.add(file);
  await compressSvg(file);
}

const existingPdf = (await readdir(dir)).filter(f => /\.pdf$/i.test(f));
for (const file of existingPdf) {
  handled.add(file);
  await compressPdf(file);
}

const existing = (await readdir(dir)).filter(f => /\.(png|jpg|jpeg|avif)$/i.test(f));
for (const file of existing) {
  handled.add(file);
  await compress(file);
}

// --- Watch for new files ---
console.log(`Watching ${dir}...`);
watch(dir, (event, filename) => {
  if (!filename) return;
  if (/\.svg$/i.test(filename)) {
    scheduleOnce(filename, () => compressSvg(filename));
  } else if (/\.pdf$/i.test(filename)) {
    scheduleOnce(filename, () => compressPdf(filename));
  } else if (/\.(png|jpg|jpeg|avif)$/i.test(filename)) {
    scheduleOnce(filename, () => compress(filename));
  }
});
