// Mağaza ekran görüntüleri: store/ekran/ekran.html sayfasını gerçek yazı tipleriyle çizer.
// iPhone 6.7"/6.9": 1290×2796 → app-store/ekran-goruntuleri/N.png
// Google Play telefon (en fazla 2:1): 1080×2160 → store/play-ekran/N.png
// Play öne çıkan görsel 1024×500 → store/play-one-cikan-1024x500.png
import { chromium } from 'playwright';
import fs from 'node:fs';
const kok = process.cwd();
fs.mkdirSync('out/app-store/ekran-goruntuleri', { recursive: true });
fs.mkdirSync('out/store/play-ekran', { recursive: true });
const b = await chromium.launch();
async function cek(url, w, h, dpr, dosya) {
  const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: dpr });
  await p.goto(url, { waitUntil: 'networkidle' });
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(800);
  await p.screenshot({ path: dosya });
  await p.close();
}
for (let i = 1; i <= 6; i++) {
  const u = `file://${kok}/store/ekran/ekran.html?s=${i}`;
  await cek(u, 430, 932, 3, `out/app-store/ekran-goruntuleri/${i}.png`);
  await cek(u, 432, 864, 2.5, `out/store/play-ekran/${i}.png`);
}
await cek(`file://${kok}/store/ekran/one-cikan.html`, 1024, 500, 1, 'out/store/play-one-cikan-1024x500.png');
await b.close();
console.log('tamam');
