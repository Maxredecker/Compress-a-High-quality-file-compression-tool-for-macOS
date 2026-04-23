const { contextBridge, ipcRenderer, webUtils } = require('electron');

contextBridge.exposeInMainWorld('compress', {
  selectFiles: () => ipcRenderer.invoke('select-files'),
  compressFile: (filePath, outputDir, settings) => ipcRenderer.invoke('compress-file', filePath, outputDir, settings),
  getThumbnail: (filePath) => ipcRenderer.invoke('get-thumbnail', filePath),
  openFolder: (folderPath) => ipcRenderer.invoke('open-folder', folderPath),
  selectOutputDir: () => ipcRenderer.invoke('select-output-dir'),
  getDefaultOutputDir: () => ipcRenderer.invoke('get-default-output-dir'),
  getPathForFile: (file) => webUtils.getPathForFile(file),
  loadSettings: () => ipcRenderer.invoke('load-settings'),
  saveSettings: (settings) => ipcRenderer.invoke('save-settings', settings),
});
