const { app, BrowserWindow, ipcMain, dialog, Notification, shell } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow;

// --- Settings persistence ---
const settingsPath = path.join(app.getPath('userData'), 'settings.json');
const defaultSettings = {
  images: {
    quality: 80,
    formats: { png: true, jpg: true, webp: true, avif: true, jxl: true },
    maxDimension: null,
    stripMetadata: true,
    progressive: true,
    jxlEffort: 7,
  },
  vectors: {
    enabled: true,
    removeDimensions: false,
    prefixIds: false,
    minifyIds: true,
  },
  pdfs: {
    preset: 'printer',
    grayscale: false,
  }
};

function loadSettings() {
  try {
    if (fs.existsSync(settingsPath)) {
      const data = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
      return {
        ...defaultSettings,
        ...data,
        images: {
          ...defaultSettings.images,
          ...(data.images || {}),
          formats: {
            ...defaultSettings.images.formats,
            ...((data.images && data.images.formats) || {}),
          },
        },
        vectors: {
          ...defaultSettings.vectors,
          ...(data.vectors || {}),
        },
        pdfs: {
          ...defaultSettings.pdfs,
          ...(data.pdfs || {}),
        },
      };
    }
  } catch {}
  return { ...defaultSettings };
}

function saveSettings(settings) {
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 620,
    height: 560,
    minWidth: 480,
    minHeight: 400,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 16, y: 16 },
    backgroundColor: '#f5f0eb',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  mainWindow.loadFile('index.html');

  // Drag-and-drop: intercept at webContents level to get real file paths
  mainWindow.webContents.on('will-navigate', (e) => e.preventDefault());
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());

ipcMain.handle('select-files', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openFile', 'multiSelections'],
    filters: [{ name: 'Images & Documents', extensions: ['jpg','jpeg','png','avif','svg','pdf'] }],
    title: 'Select files to compress',
  });
  return result.canceled ? [] : result.filePaths;
});

ipcMain.handle('compress-file', async (event, filePath, outputDir, settings) => {
  const engine = await import('./compress-engine.mjs');
  try {
    const result = await engine.compressFile(filePath, outputDir, settings);
    return result;
  } catch (e) {
    return { file: path.basename(filePath), error: e.message };
  }
});

ipcMain.handle('get-thumbnail', async (event, filePath) => {
  try {
    const ext = path.extname(filePath).toLowerCase();
    if (['.jpg','.jpeg','.png','.avif'].includes(ext)) {
      const sharp = (await import('sharp')).default;
      const buf = await sharp(filePath).resize(80, 80, { fit: 'cover' }).jpeg({ quality: 60 }).toBuffer();
      return 'data:image/jpeg;base64,' + buf.toString('base64');
    }
    return null;
  } catch { return null; }
});

ipcMain.handle('open-folder', async (event, folderPath) => {
  shell.openPath(folderPath);
});

ipcMain.handle('select-output-dir', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory', 'createDirectory'],
    title: 'Choose output folder',
  });
  return result.canceled ? null : result.filePaths[0];
});

ipcMain.handle('get-default-output-dir', () => {
  return path.join(app.getPath('downloads'), 'compressed');
});

ipcMain.handle('load-settings', () => loadSettings());
ipcMain.handle('save-settings', (event, settings) => {
  saveSettings(settings);
  return true;
});
