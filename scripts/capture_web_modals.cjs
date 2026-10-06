const puppeteer = require('../web/node_modules/puppeteer-core');
const path = require('path');

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const SCREENSHOT_DIR = 'D:\\app\\docs\\screenshots';

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function run() {
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--window-size=1440,900']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });

  await page.goto('http://localhost:3000/login', { waitUntil: 'networkidle0' });
  await page.click('button[type="submit"]');
  await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 }).catch(() => {});
  await sleep(2000);

  // Switch to Retailers tab & open Add Retailer modal
  console.log('Opening Retailers tab...');
  const buttons = await page.$$('button');
  for (const btn of buttons) {
    const text = await page.evaluate(el => el.textContent, btn);
    if (text && text.includes('Retailers')) {
      await btn.click();
      await sleep(1000);
      break;
    }
  }

  // Click "+ Add Retailer" button
  console.log('Clicking Add Retailer button...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button'));
    const target = btns.find(b => b.textContent && b.textContent.includes('Add Retailer'));
    if (target) target.click();
  });
  await sleep(1000);
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '19_web_add_retailer_modal.png') });
  console.log('Saved 19_web_add_retailer_modal.png');

  // Close modal
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button'));
    const target = btns.find(b => b.textContent && b.textContent.includes('Cancel'));
    if (target) target.click();
  });
  await sleep(800);

  // Switch to Products tab & open Add Product modal
  console.log('Opening Products tab...');
  const buttons2 = await page.$$('button');
  for (const btn of buttons2) {
    const text = await page.evaluate(el => el.textContent, btn);
    if (text && text.includes('Products')) {
      await btn.click();
      await sleep(1000);
      break;
    }
  }

  // Click "+ Add Product"
  console.log('Clicking Add Product button...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button'));
    const target = btns.find(b => b.textContent && b.textContent.includes('Add Product'));
    if (target) target.click();
  });
  await sleep(1000);
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '20_web_add_product_modal.png') });
  console.log('Saved 20_web_add_product_modal.png');

  await browser.close();
  console.log('Web modal screenshots done successfully!');
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
