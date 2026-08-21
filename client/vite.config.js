import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";
import path from "path";

export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "@assets": path.resolve(__dirname, "./src/assessts"),
    },
  },
  server: {
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
        secure: false,
      },
      "/media": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
        secure: false,
      },
    },
  },
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["favicon.ico", "robots.txt"],
      manifest: {
        name: "Bewosai – Business Management",
        short_name: "Bewosai",
        description: "Sales, inventory, expenses, staff and reports for small businesses",
        theme_color: "#f59e0b",
        background_color: "#ffffff",
        display: "standalone",
        orientation: "any",
        start_url: "/",
        scope: "/",
        lang: "ne",
        dir: "ltr",
        categories: ["business", "finance", "productivity"],
        icons: [
          { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any maskable" },
        ],
        shortcuts: [
          { name: "New Invoice", short_name: "Invoice", description: "Create a new sales invoice", url: "/sales", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
          { name: "Add Expense", short_name: "Expense", description: "Record an expense", url: "/expenses", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
        ],
      },
      workbox: {
        // Cache all JS/CSS/HTML assets
        globPatterns: ["**/*.{js,css,html,ico,png,svg,woff2}"],
        // API calls always go to the network, never the cache. Business
        // data (stock, balances, invoices) must be correct across devices —
        // a NetworkFirst strategy would silently serve a stale cached
        // response whenever the request is slow, e.g. the Render free-tier
        // backend waking from an idle cold start (can take 30-60s, far past
        // any timeout short enough to still feel responsive). Every page
        // already has its own loading/error UI, so there's nothing gained
        // by the service worker papering over a slow or failed request with
        // out-of-date numbers.
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.startsWith("/api/"),
            handler: "NetworkOnly",
          },
        ],
      },
    }),
  ],
});
