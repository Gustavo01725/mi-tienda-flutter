// Humo de UI en Chromium con la compilación web (ver README). Coordenadas calibradas para viewport 420x800.
// Uso: CHROME=/ruta/chrome node tool/local-test/ui-smoke.js  (necesita: npm i playwright-core, web en :8000, build/web servido en :8080)
const { chromium } = require('playwright-core');
const API = 'http://localhost:8000/api';
async function api(path, method='GET', token, body) {
  const r = await fetch(API+path, { method, headers: {Accept:'application/json','Content-Type':'application/json', ...(token?{Authorization:'Bearer '+token}:{})}, body: body?JSON.stringify(body):undefined });
  return r.json();
}
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROME, args: ['--no-sandbox'] });
  const p = await b.newPage({ viewport: { width: 420, height: 800 } });
  await p.goto('http://localhost:8080', { waitUntil: 'load' });
  await p.waitForTimeout(6000);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(1500);
  const txt = async () => (await p.locator('flt-semantics').allInnerTexts()).join(' | ').replace(/\s+/g,' ');
  console.log('1 home:', (await txt()).slice(0,160));

  // login
  await p.getByRole('button', { name: 'Entrar' }).click(); await p.waitForTimeout(1200);
  const inputs = p.locator('input, textarea');
  console.log('inputs on login:', await inputs.count());
  await inputs.nth(0).fill('cust@t.com'); await inputs.nth(1).fill('secret123');
  await p.getByRole('button', { name: 'Entrar' }).click(); await p.waitForTimeout(3000);
  await p.screenshot({ path: 'after-login.png' });
  console.log('2 after login:', (await txt()).slice(0,200));

  // product detail -> pick variant -> add to cart
  await p.mouse.click(108, 280); await p.waitForTimeout(1500);
  await p.screenshot({ path: 'detail.png' });
  console.log('3 detail:', (await txt()).slice(0,260));
  await p.mouse.click(180, 493); await p.waitForTimeout(500);
  await p.mouse.click(210, 542); await p.waitForTimeout(2500);
  await p.screenshot({ path: 'detail-added.png' });
  console.log('4 after add:', (await txt()).slice(0,200));

  // REAL-TIME: seller changes stock M-negro via API while the customer is looking at the detail screen
  const st = (await api('/auth/login','POST',null,{email:'seller@t.com',password:'secret123'})).token;
  const prod = (await api('/seller/products','GET',st))[0];
  const m = prod.stocks.find(s=>s.variant==='M-negro');
  await api('/seller/products/'+prod.id+'/stocks','PUT',st,{stocks:[{id:m.id,qty:11}]});
  await p.waitForTimeout(7000); // el ciclo de sync es de 5 s
  await p.screenshot({ path: 'realtime.png' });
  const after = await txt();
  console.log('5 realtime shows M-negro (11):', /M-negro \(11\)/.test(after), '|', after.match(/M-negro \(\d+\)/)?.[0]);
  await api('/seller/products/'+prod.id+'/stocks','PUT',st,{stocks:[{id:m.id,qty:3}]});

  // cart screen
  // cart screen: back, open cart icon
  await p.mouse.click(28, 28); await p.waitForTimeout(800);
  await p.getByRole('button', { name: /Carrito/ }).click({ timeout: 5000 }).catch(()=>p.mouse.click(330, 28)); await p.waitForTimeout(1500);
  await p.screenshot({ path: 'cart.png' });
  console.log('6 cart:', (await txt()).slice(0,260));
  await b.close();
})().catch(e => { console.error('FAIL', e.message.split('\n')[0]); process.exit(1); });
