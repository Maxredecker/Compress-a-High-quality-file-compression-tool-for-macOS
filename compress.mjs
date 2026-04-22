import sharp from 'sharp';
import { optimize } from 'svgo';
import { execFile } from 'child_process';
import { promisify } from 'util';
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

// Binary paths (Homebrew on Apple Silicon — change to /usr/local/bin/ for Intel Mac)
const CJXL = '/opt/homebrew/bin/cjxl';
const GS = '/opt/homebrew/bin/gs';

const outDir = join(dir, 'compressed');
await mkdir(outDir, { recursive: true });

// --- Helpers ---
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
const pdfFiles = (await readdir(dir)).filter(f => /\.pdf$/i.test(f));
for (const file of pdfFiles) {
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
    } else {
      await safeUnlink(output);
      console.log(`⊘ ${file} — PDF not smaller, skipped`);
    }
    await unlink(input);
  } catch (e) {
    console.error(`✗ ${file} (PDF) — ${e.message}`);
  }
}

// --- SVG compression ---
const svgFiles = (await readdir(dir)).filter(f => /\.svg$/i.test(f));
for (const file of svgFiles) {
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
    } else {
      console.log(`⊘ ${file} — SVG not smaller, skipped`);
    }
    await unlink(input);
  } catch (e) {
    console.error(`✗ ${file} (SVG) — ${e.message}`);
  }
}

// --- Image compression ---
const files = (await readdir(dir)).filter(f => /\.(png|jpg|jpeg|avif)$/i.test(f));

if (files.length === 0 && svgFiles.length === 0 && pdfFiles.length === 0) {
  console.log('No files to compress.');
} else {
  for (const file of files) {
    try {
      const input = join(dir, file);
      const metadata = await sharp(input).metadata();
      const isPng = /\.png$/i.test(file);
      const hasAlpha = metadata.hasAlpha && isPng;
      const baseName = file.replace(/\.(png|jpg|jpeg|avif)$/i, '');
      const originalSize = (await stat(input)).size;
      const results = [];

      // PNG (only if transparency)
      if (hasAlpha) {
        const pngOut = join(outDir, `${baseName}.png`);
        await sharp(input).png({ palette: true, quality: pngQuality, compressionLevel: 9, effort: 10 }).toFile(pngOut);
        const size = (await stat(pngOut)).size;
        if (size < originalSize) {
          results.push({ format: 'PNG', size });
        } else {
          await safeUnlink(pngOut);
        }
      }

      // JPEG (only if no transparency)
      if (!hasAlpha) {
        const jpgOut = join(outDir, `${baseName}.jpg`);
        await sharp(input).jpeg({ quality: jpegQuality, mozjpeg: true }).toFile(jpgOut);
        const size = (await stat(jpgOut)).size;
        if (size < originalSize) {
          results.push({ format: 'JPG', size });
        } else {
          await safeUnlink(jpgOut);
        }
      }

      // WebP (always saved)
      const webpOut = join(outDir, `${baseName}.webp`);
      await sharp(input).webp({ quality: webpQuality, effort: 6 }).toFile(webpOut);
      const webpSize = (await stat(webpOut)).size;
      results.push({ format: 'WebP', size: webpSize });

      // AVIF
      const avifOut = join(outDir, `${baseName}.avif`);
      await sharp(input).avif({ quality: avifQuality, effort: 6 }).toFile(avifOut);
      const avifSize = (await stat(avifOut)).size;
      if (avifSize < originalSize) {
        results.push({ format: 'AVIF', size: avifSize });
      } else {
        await safeUnlink(avifOut);
      }

      // JPEG XL via cjxl
      try {
        const jxlOut = join(outDir, `${baseName}.jxl`);
        await toJxl(input, jxlOut);
        const jxlSize = (await stat(jxlOut)).size;
        if (jxlSize < originalSize) {
          results.push({ format: 'JXL', size: jxlSize });
        } else {
          await safeUnlink(jxlOut);
        }
      } catch {
        // cjxl not available — skip JXL
      }

      if (results.length === 0) {
        console.log(`⊘ ${file} — no format smaller than original (${formatSize(originalSize)})`);
      } else {
        const comparison = results
          .map(r => {
            const saved = Math.round((1 - r.size / originalSize) * 100);
            return `${r.format} ${formatSize(r.size)} (−${saved}%)`;
          })
          .join('  │  ');
        console.log(`✓ ${file}  │  ${comparison}`);
      }

      await unlink(input);
    } catch (e) {
      console.error(`✗ ${file} — ${e.message}`);
    }
  }
}
