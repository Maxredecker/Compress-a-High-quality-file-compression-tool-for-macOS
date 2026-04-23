import sharp from 'sharp';
import { optimize } from 'svgo';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { stat, readFile, unlink, writeFile, mkdir } from 'fs/promises';
import { join, basename, extname } from 'path';
import { existsSync } from 'fs';

const exec = promisify(execFile);

// Quality settings
const JPEG_QUALITY = 80;
const PNG_QUALITY = 85;
const WEBP_QUALITY = 80;
const AVIF_QUALITY = 50;
const JXL_QUALITY = 80;

// Try to find binaries
function findBin(name) {
  const paths = [
    `/opt/homebrew/bin/${name}`,    // Apple Silicon Homebrew
    `/usr/local/bin/${name}`,       // Intel Homebrew
    `/usr/bin/${name}`,             // System
  ];
  return paths.find(p => existsSync(p)) || null;
}

const CJXL = findBin('cjxl');
const GS = findBin('gs');

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

async function safeUnlink(path) {
  try { await unlink(path); } catch {}
}

async function toJxl(inputPath, outputPath, options) {
  if (!CJXL) throw new Error('cjxl not found');
  const q = Number(options?.quality) || JXL_QUALITY;
  const effort = Math.max(1, Math.min(9, Number(options?.effort || 7)));
  const isJpeg = /\.jpe?g$/i.test(inputPath);
  const args = isJpeg
    ? [inputPath, outputPath, '-q', String(q), '--lossless_jpeg=0', '-e', String(effort)]
    : [inputPath, outputPath, '-q', String(q), '-e', String(effort)];
  await exec(CJXL, args);
}

export function normalizeSettings(settings) {
  const s = settings || {};
  const images = s.images || {};
  const vectors = s.vectors || {};
  const pdfs = s.pdfs || {};
  const maxDimension = Number(images.maxDimension);
  const jxlEffort = Number(images.jxlEffort);

  return {
    images: {
      quality: Number(images.quality) || JPEG_QUALITY,
      formats: {
        png: images.formats?.png !== false,
        jpg: images.formats?.jpg !== false,
        webp: images.formats?.webp !== false,
        avif: images.formats?.avif !== false,
        jxl: images.formats?.jxl !== false,
      },
      maxDimension: Number.isFinite(maxDimension) && maxDimension > 0 ? maxDimension : null,
      stripMetadata: images.stripMetadata !== false,
      progressive: images.progressive !== false,
      jxlEffort: Number.isFinite(jxlEffort) ? Math.max(1, Math.min(9, jxlEffort)) : 7,
    },
    vectors: {
      enabled: vectors.enabled !== false,
      removeDimensions: !!vectors.removeDimensions,
      prefixIds: !!vectors.prefixIds,
      minifyIds: vectors.minifyIds !== false,
    },
    pdfs: {
      preset: pdfs.preset || 'printer',
      grayscale: !!pdfs.grayscale,
    },
  };
}

// --- Main export: compress a single file ---
export async function compressFile(filePath, outputDir, settings) {
  await mkdir(outputDir, { recursive: true });

  const file = basename(filePath);
  const ext = extname(file).toLowerCase();
  const s = normalizeSettings(settings);

  if (ext === '.pdf') return compressPdf(filePath, file, outputDir, s.pdfs);
  if (ext === '.svg') return compressSvg(filePath, file, outputDir, s.vectors);
  if (['.png', '.jpg', '.jpeg', '.avif'].includes(ext)) return compressImage(filePath, file, outputDir, s.images);

  return { file, error: `Unsupported format: ${ext}` };
}

// --- PDF ---
async function compressPdf(input, file, outputDir, pdfSettings) {
  if (!GS) return { file, error: 'Ghostscript not installed. Run: brew install ghostscript' };
  const preset = (pdfSettings && pdfSettings.preset) || 'printer';
  const grayscale = !!(pdfSettings && pdfSettings.grayscale);
  const originalSize = (await stat(input)).size;
  const baseName = file.replace(/\.pdf$/i, '');
  const output = join(outputDir, `${baseName}.pdf`);

  const gsArgs = [
    '-sDEVICE=pdfwrite',
    '-dCompatibilityLevel=1.5',
    '-dPDFSETTINGS=/' + preset,
    '-dNOPAUSE', '-dBATCH', '-dQUIET',
    '-dEncodeColorImages=true',
    '-dAutoFilterColorImages=true',
    `-sOutputFile=${output}`,
    input,
  ];

  if (grayscale) {
    gsArgs.splice(5, 0, '-sColorConversionStrategy=Gray', '-dProcessColorModel=/DeviceGray');
  } else {
    gsArgs.splice(5, 0, '-dColorConversionStrategy=/LeaveColorUnchanged');
  }

  await exec(GS, gsArgs);

  const newSize = (await stat(output)).size;
  if (newSize >= originalSize) {
    await safeUnlink(output);
    return { file, originalSize, formats: [], bestSaved: 0 };
  }

  const saved = Math.round((1 - newSize / originalSize) * 100);
  return {
    file,
    originalSize,
    formats: [{ format: 'PDF', size: newSize, sizeFormatted: formatSize(newSize), saved }],
    bestSaved: saved,
  };
}

// --- SVG ---
async function compressSvg(input, file, outputDir, vecSettings) {
  if (vecSettings && vecSettings.enabled === false) {
    return { file, originalSize: 0, formats: [], bestSaved: 0, error: 'SVG compression disabled' };
  }
  const svg = await readFile(input, 'utf8');
  const originalSize = Buffer.byteLength(svg);

  const plugins = [
    'preset-default',
    'sortAttrs',
    { name: 'removeAttrs', params: { attrs: ['data-name'] } },
  ];
  if (vecSettings?.removeDimensions) plugins.push('removeDimensions');
  if (vecSettings?.prefixIds) plugins.push('prefixIds');
  if (vecSettings?.minifyIds === false) {
    plugins.push({ name: 'cleanupIds', params: { minify: false } });
  }

  const result = optimize(svg, {
    path: input,
    multipass: true,
    plugins,
  });

  if (result.data.length >= svg.length) {
    return { file, originalSize, formats: [], bestSaved: 0 };
  }

  const output = join(outputDir, file);
  await writeFile(output, result.data);
  const saved = Math.round((1 - result.data.length / svg.length) * 100);

  return {
    file,
    originalSize,
    formats: [{ format: 'SVG', size: result.data.length, sizeFormatted: formatSize(result.data.length), saved }],
    bestSaved: saved,
  };
}

// --- Images ---
async function compressImage(input, file, outputDir, imgSettings) {
  const quality = (imgSettings && imgSettings.quality) || 80;
  const enabledFormats = (imgSettings && imgSettings.formats) || { png: true, jpg: true, webp: true, avif: true, jxl: true };
  const maxDimension = imgSettings?.maxDimension || null;
  const keepMetadata = imgSettings?.stripMetadata === false;
  const progressive = imgSettings?.progressive !== false;
  const jxlEffort = imgSettings?.jxlEffort || 7;
  const avifQ = Math.round(quality * 0.625); // AVIF scale: 80 -> 50

  const metadata = await sharp(input).metadata();
  const baseName = file.replace(/\.(png|jpg|jpeg|avif)$/i, '');
  const hasAlpha = !!metadata.hasAlpha;
  const originalSize = (await stat(input)).size;
  const formats = [];
  const basePipeline = sharp(input).rotate();
  const maybeResize = maxDimension
    ? basePipeline.resize({
        width: maxDimension,
        height: maxDimension,
        fit: 'inside',
        withoutEnlargement: true,
      })
    : basePipeline;

  function withOutputPipeline() {
    return keepMetadata ? maybeResize.clone().withMetadata() : maybeResize.clone();
  }

  // PNG
  if (enabledFormats.png) {
    const pngOut = join(outputDir, `${baseName}.png`);
    await withOutputPipeline().png({ palette: true, quality, compressionLevel: 9, effort: 10, progressive }).toFile(pngOut);
    const size = (await stat(pngOut)).size;
    if (size < originalSize) {
      formats.push({ format: 'PNG', size, sizeFormatted: formatSize(size), saved: Math.round((1 - size / originalSize) * 100) });
    } else {
      await safeUnlink(pngOut);
    }
  }

  // JPEG
  // For images with alpha, flatten onto white so JPG output still works when selected.
  if (enabledFormats.jpg) {
    const jpgOut = join(outputDir, `${baseName}.jpg`);
    const jpgPipeline = hasAlpha ? withOutputPipeline().flatten({ background: '#ffffff' }) : withOutputPipeline();
    await jpgPipeline.jpeg({ quality, mozjpeg: true, progressive }).toFile(jpgOut);
    const size = (await stat(jpgOut)).size;
    if (size < originalSize) {
      formats.push({ format: 'JPG', size, sizeFormatted: formatSize(size), saved: Math.round((1 - size / originalSize) * 100) });
    } else {
      await safeUnlink(jpgOut);
    }
  }

  // WebP (always if enabled)
  if (enabledFormats.webp) {
    const webpOut = join(outputDir, `${baseName}.webp`);
    await withOutputPipeline().webp({ quality, effort: 6 }).toFile(webpOut);
    const webpSize = (await stat(webpOut)).size;
    formats.push({ format: 'WebP', size: webpSize, sizeFormatted: formatSize(webpSize), saved: Math.round((1 - webpSize / originalSize) * 100) });
  }

  // AVIF
  if (enabledFormats.avif) {
    const avifOut = join(outputDir, `${baseName}.avif`);
    await withOutputPipeline().avif({ quality: avifQ, effort: 6 }).toFile(avifOut);
    const avifSize = (await stat(avifOut)).size;
    if (avifSize < originalSize) {
      formats.push({ format: 'AVIF', size: avifSize, sizeFormatted: formatSize(avifSize), saved: Math.round((1 - avifSize / originalSize) * 100) });
    } else {
      await safeUnlink(avifOut);
    }
  }

  // JXL
  if (enabledFormats.jxl && CJXL) {
    try {
      const jxlOut = join(outputDir, `${baseName}.jxl`);
      await toJxl(input, jxlOut, { quality, effort: jxlEffort });
      const jxlSize = (await stat(jxlOut)).size;
      if (jxlSize < originalSize) {
        formats.push({ format: 'JXL', size: jxlSize, sizeFormatted: formatSize(jxlSize), saved: Math.round((1 - jxlSize / originalSize) * 100) });
      } else {
        await safeUnlink(jxlOut);
      }
    } catch {}
  }

  const bestSaved = formats.length > 0 ? Math.max(...formats.map(f => f.saved)) : 0;

  return {
    file,
    originalSize,
    originalSizeFormatted: formatSize(originalSize),
    formats,
    bestSaved,
  };
}
