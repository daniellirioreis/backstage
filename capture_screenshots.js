// capture_screenshots.js
// Uso: node capture_screenshots.js
// Requer: npm install puppeteer  (na primeira vez)

const puppeteer = require("puppeteer");
const path = require("path");
const fs = require("fs");

const PORTFOLIO = path.join(__dirname, "public", "portfolio");
const BASE = "http://localhost:3000";

const PAGES = [
  { url: "/",                          file: "screen-home.png" },
  { url: "/events",                    file: "screen-events.png" },
  { url: "/events/13",                 file: "screen-evento-overview.png",  wait: 1500 },
  { url: "/events/13#financeiro",      file: "screen-financeiro.png",       wait: 2000 },
  { url: "/events/13#equipes",         file: "screen-equipes.png",          wait: 1500 },
  { url: "/events/13#setores",         file: "screen-setores.png",          wait: 1500 },
  { url: "/shifts/timeline",           file: "screen-timeline.png",         wait: 2000 },
  { url: "/attendances",               file: "screen-presencas.png" },
  { url: "/reports/closing",           file: "screen-fechamento.png",       wait: 2000 },
  { url: "/reports/sector_summary",    file: "screen-setor-resumo.png",     wait: 1500 },
  { url: "/events/14/edit",            file: "screen-evento-edit.png" },
  { url: "/events/14/setup/sectors",   file: "screen-setup-setores.png" },
  { url: "/events/14/setup/teams",     file: "screen-setup-equipes.png" },
  { url: "/events/14/setup/schedules", file: "screen-setup-escalas.png",   wait: 2000 },
];

(async () => {
  fs.mkdirSync(PORTFOLIO, { recursive: true });

  const browser = await puppeteer.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
    defaultViewport: { width: 1280, height: 800 },
  });

  const page = await browser.newPage();

  // ── Login ──────────────────────────────────────────────────────────────────
  console.log("🔐 Fazendo login...");
  await page.goto(`${BASE}/users/sign_in`, { waitUntil: "networkidle0" });

  await page.type('input[name="user[email]"]',    "admin@backstage.com");
  await page.type('input[name="user[password]"]', "senha123");
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForNavigation({ waitUntil: "networkidle0" });
  console.log("✅ Login OK\n");

  // ── Screenshots ────────────────────────────────────────────────────────────
  for (const { url, file, wait } of PAGES) {
    try {
      await page.goto(`${BASE}${url}`, { waitUntil: "networkidle0", timeout: 15000 });

      if (wait) await new Promise(r => setTimeout(r, wait));

      // Scroll até o topo
      await page.evaluate(() => window.scrollTo(0, 0));

      const dest = path.join(PORTFOLIO, file);
      await page.screenshot({ path: dest, fullPage: false });
      console.log(`📸 ${file}`);
    } catch (e) {
      console.error(`❌ Erro em ${url}: ${e.message}`);
    }
  }

  await browser.close();

  const saved = fs.readdirSync(PORTFOLIO).filter(f => f.startsWith("screen-")).length;
  console.log(`\n✅ ${saved} screenshots salvos em public/portfolio/`);
})();
