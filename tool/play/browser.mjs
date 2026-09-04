// browser.mjs — Play Console'u sürmek için CDP köprüsü.
//
// İçerik derecelendirme anketi Play Developer API'de YOK; yalnızca konsoldan
// doldurulabiliyor. Bu yüzden tarayıcı sürülür.
//
// Aynı Google hesabı (gokcerodop@gmail.com) hiz_radar için zaten açık ve login
// olmuş bir Chrome oturumunu (port 9333) YENİDEN KULLANIR — yeni bir profile
// için tekrar Google girişi gerekmesin diye.
import { chromium } from "/opt/homebrew/lib/node_modules/playwright/index.mjs";

export const PORT = 9333;
export const CDP = `http://127.0.0.1:${PORT}`;

export async function baglan() {
  const browser = await chromium.connectOverCDP(CDP);
  const ctx = browser.contexts()[0];
  const page = ctx.pages().find((p) => !p.url().startsWith("about:") && !p.url().startsWith("chrome")) ?? ctx.pages()[0];
  return { browser, ctx, page };
}

export async function metin(page, sinir = 4000) {
  const t = await page.evaluate(() => {
    const gorunur = (el) => {
      const s = getComputedStyle(el);
      return s.display !== "none" && s.visibility !== "hidden" && s.opacity !== "0";
    };
    const out = [];
    document.querySelectorAll("h1,h2,h3,h4,label,button,a,p,li,span,div").forEach((el) => {
      if (el.children.length) return;
      const txt = (el.textContent || "").trim();
      if (!txt || txt.length > 300) return;
      if (!gorunur(el)) return;
      out.push(txt);
    });
    return [...new Set(out)].join("\n");
  });
  return t.slice(0, sinir);
}

export async function ekran(page, ad) {
  const yol = `/tmp/play-visaradar-${ad}.png`;
  await page.screenshot({ path: yol, fullPage: false });
  return yol;
}
