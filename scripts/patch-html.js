#!/usr/bin/env node
// Injects iOS PWA meta tags and dark background into the Expo-built dist/index.html.
// Run after `npx expo export --platform web`.

const fs = require("fs");
const path = require("path");

const htmlPath = path.join(__dirname, "..", "dist", "index.html");
if (!fs.existsSync(htmlPath)) {
  console.error("dist/index.html not found — run expo export first");
  process.exit(1);
}

let html = fs.readFileSync(htmlPath, "utf8");

// 1. Replace viewport to add viewport-fit=cover (needed for iOS safe-area-inset)
html = html.replace(
  /(<meta\s+name=["']viewport["']\s+content=["'])[^"']*["']/,
  '$1width=device-width, initial-scale=1, viewport-fit=cover"'
);

// 2. Inject PWA + theme meta tags right after the charset meta
const pwaMetas = [
  '<meta name="mobile-web-app-capable" content="yes" />',
  '<meta name="apple-mobile-web-app-capable" content="yes" />',
  '<meta name="apple-mobile-web-app-title" content="Committee" />',
  '<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />',
  '<meta name="theme-color" content="#020817" />',
].join("\n    ");

if (!html.includes("apple-mobile-web-app-capable")) {
  html = html.replace(
    /(<meta\s+charset[^>]+>)/i,
    `$1\n    ${pwaMetas}`
  );
}

// 3. Prepend dark background + safe-area CSS to the expo-reset <style>
//    so these apply before any JS runs — prevents white flash and footer gap on iOS PWA
const bgStyle = [
  "html,body{background:#020817 !important;}",
  // Fill the iOS home-indicator gap with the tab bar surface colour
  "#tab-bar-safe{padding-bottom:env(safe-area-inset-bottom,0px) !important;}",
  "#ios-safe-bottom{height:env(safe-area-inset-bottom,0px) !important;flex-shrink:0;}",
].join("\n      ") + "\n      ";

if (!html.includes("background:#020817")) {
  html = html.replace(/<style id="expo-reset">/, `<style id="expo-reset">${bgStyle}`);
}

fs.writeFileSync(htmlPath, html, "utf8");
console.log("✓ Patched dist/index.html with iOS PWA meta tags, dark background, and safe-area CSS");
