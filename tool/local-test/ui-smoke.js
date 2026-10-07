// Humo de UI en Chromium con la compilación web (ver README). Coordenadas para un viewport de 420x860
// con el diseño guStore (banner, barra superior, cabecera fija y barra inferior).
// Uso: CHROME=/ruta/chrome node tool/local-test/ui-smoke.js [carpeta-capturas]
//   (necesita: npm i playwright-core, la web en :8000 y build/web servido en :8080)
const { chromium } = require('playwright-core');
const API = 'http://localhost:8000/api';
const out = process.argv[2] || '.';

async function api(path, method = 'GET', token, body) {
  const r = await fetch(API + path, {
    method,
    headers: { Accept: 'application/json', 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return r.json();
}

(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROME, args: ['--no-sandbox'] });
  const p = await (await b.newContext({ viewport: { width: 420, height: 860 } })).newPage();
  p.on('pageerror', (e) => console.log('ERROR de la página:', e.message.slice(0, 200)));
  const shot = async (n) => { await p.waitForTimeout(1500); await p.screenshot({ path: `${out}/${n}.png` }); console.log('captura', n); };

  await p.goto('http://localhost:8080'); await p.waitForTimeout(7000);
  await shot('1-inicio');

  // Cuenta (barra inferior) → login embebido
  await p.mouse.click(378, 830); await p.waitForTimeout(1500);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await p.waitForTimeout(1500);
  const inputs = p.locator('input');
  await inputs.nth(0).fill('cust@t.com'); await p.waitForTimeout(300);
  await inputs.nth(1).fill('secret123'); await p.waitForTimeout(300);
  await p.mouse.click(210, 642); await p.waitForTimeout(3000);
  await shot('2-mi-perfil');

  // Inicio → primer producto
  await p.mouse.click(48, 182); await p.waitForTimeout(1200);
  await p.mouse.click(110, 530); await p.waitForTimeout(1500);
  await p.mouse.move(210, 500); await p.mouse.wheel(0, 420); await p.waitForTimeout(800);
  await shot('3-ficha');

  // Tiempo real: el vendedor cambia el stock de M-negro por la API mientras se mira la ficha.
  const st = (await api('/auth/login', 'POST', null, { email: 'seller@t.com', password: 'secret123' })).token;
  const prod = (await api('/seller/products', 'GET', st))[0];
  const m = prod.stocks.find((s) => s.variant === 'M-negro');
  await p.mouse.click(123, 323); await p.waitForTimeout(500); // talla M
  await api('/seller/products/' + prod.id + '/stocks', 'PUT', st, { stocks: [{ id: m.id, qty: 11 }] });
  await p.waitForTimeout(7000); // ciclo de sync de 5 s
  await shot('4-tiempo-real'); // con M elegida debe decir "(11 disponibles)"
  await api('/seller/products/' + prod.id + '/stocks', 'PUT', st, { stocks: [{ id: m.id, qty: m.qty }] });

  // Carrito (círculo verde de la barra inferior)
  await p.mouse.click(210, 805); await shot('5-carrito');
  await b.close();
})().catch((e) => { console.error('FALLO', e.message.split('\n')[0]); process.exit(1); });
