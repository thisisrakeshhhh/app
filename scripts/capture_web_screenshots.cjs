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

  console.log('Navigating to login...');
  await page.goto('http://localhost:3000/login', { waitUntil: 'networkidle0' });
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '13_web_login_portal.png') });
  console.log('Saved 13_web_login_portal.png');

  // Click login
  console.log('Submitting login form for Owner...');
  await page.click('button[type="submit"]');
  await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 }).catch(() => {});
  await sleep(2500);

  // Check if we are on dashboard
  console.log('Current URL:', page.url());
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '14_web_owner_dashboard.png') });
  console.log('Saved 14_web_owner_dashboard.png');

  // Switch to Orders tab
  console.log('Switching to Orders tab...');
  const buttons = await page.$$('button');
  for (const btn of buttons) {
    const text = await page.evaluate(el => el.textContent, btn);
    if (text && text.includes('Orders')) {
      await btn.click();
      await sleep(1500);
      break;
    }
  }
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '15_web_orders_management.png') });
  console.log('Saved 15_web_orders_management.png');

  // Switch to Products / Godown tab
  console.log('Switching to Products tab...');
  const buttons2 = await page.$$('button');
  for (const btn of buttons2) {
    const text = await page.evaluate(el => el.textContent, btn);
    if (text && text.includes('Products')) {
      await btn.click();
      await sleep(1500);
      break;
    }
  }
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '16_web_godown_inventory.png') });
  console.log('Saved 16_web_godown_inventory.png');

  // Switch to Retailers tab
  console.log('Switching to Retailers tab...');
  const buttons3 = await page.$$('button');
  for (const btn of buttons3) {
    const text = await page.evaluate(el => el.textContent, btn);
    if (text && text.includes('Retailers')) {
      await btn.click();
      await sleep(1500);
      break;
    }
  }
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '17_web_retailer_directory.png') });
  console.log('Saved 17_web_retailer_directory.png');

  // Switch to Cash Handovers tab
  console.log('Switching to Handovers tab...');
  const buttons4 = await page.$$('button');
  for (const btn of buttons4) {
    const text = await page.evaluate(el => el.textContent, btn);
    if (text && text.includes('Handovers')) {
      await btn.click();
      await sleep(1500);
      break;
    }
  }
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '18_web_cash_reconciliation.png') });
  console.log('Saved 18_web_cash_reconciliation.png');

  await browser.close();
  console.log('All Web screenshots captured successfully!');
}

run().catch(err => {
  console.error('Error capturing web screenshots:', err);
  process.exit(1);
});
