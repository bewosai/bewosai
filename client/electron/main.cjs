// Electron main process. Named .cjs deliberately — client/package.json has
// "type": "module" for Vite's sake, and Electron's main process needs
// CommonJS (app/BrowserWindow require()). The .cjs extension forces that
// regardless of the parent package.json's module type.
const { app, BrowserWindow, shell } = require("electron");
const path = require("path");
const serve = require("electron-serve");
const { autoUpdater } = require("electron-updater");

// Serves the built dist/ folder over a local "app://" protocol instead of
// raw file:// — react-router's BrowserRouter needs a server-like origin to
// fall back to index.html on deep links/refreshes, which file:// can't do.
const loadApp = serve({ directory: path.join(__dirname, "..", "dist") });

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 960,
    minHeight: 600,
    icon: path.join(__dirname, "..", "public", "icons", "icon-512.png"),
    backgroundColor: "#0A2540",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
    show: false,
  });

  mainWindow.once("ready-to-show", () => mainWindow.show());

  // Keep external links (e.g. anything opened with target="_blank") in the
  // user's real browser instead of spawning them inside the app window.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: "deny" };
  });

  loadApp(mainWindow).then(() => {
    if (!app.isPackaged) mainWindow.webContents.openDevTools({ mode: "detach" });
  });
}

app.whenReady().then(() => {
  createWindow();
  if (app.isPackaged) autoUpdater.checkForUpdatesAndNotify();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
