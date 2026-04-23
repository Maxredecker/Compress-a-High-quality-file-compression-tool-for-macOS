import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeSettings } from './compress-engine.mjs';

test('normalizeSettings applies safe defaults', () => {
  const s = normalizeSettings({});
  assert.equal(s.images.quality, 80);
  assert.equal(s.images.stripMetadata, true);
  assert.equal(s.images.progressive, true);
  assert.equal(s.images.jxlEffort, 7);
  assert.equal(s.vectors.enabled, true);
  assert.equal(s.vectors.minifyIds, true);
  assert.equal(s.pdfs.preset, 'printer');
  assert.equal(s.pdfs.grayscale, false);
});

test('normalizeSettings clamps and parses values', () => {
  const s = normalizeSettings({
    images: { maxDimension: '2048', jxlEffort: 99, stripMetadata: false, progressive: false },
    vectors: { removeDimensions: true, prefixIds: true, minifyIds: false },
    pdfs: { preset: 'ebook', grayscale: true },
  });
  assert.equal(s.images.maxDimension, 2048);
  assert.equal(s.images.jxlEffort, 9);
  assert.equal(s.images.stripMetadata, false);
  assert.equal(s.images.progressive, false);
  assert.equal(s.vectors.removeDimensions, true);
  assert.equal(s.vectors.prefixIds, true);
  assert.equal(s.vectors.minifyIds, false);
  assert.equal(s.pdfs.preset, 'ebook');
  assert.equal(s.pdfs.grayscale, true);
});
