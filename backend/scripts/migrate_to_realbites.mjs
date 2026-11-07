const API_BASE = 'https://routeflow-api-staging.thisisrakesh21.workers.dev';

const REAL_BITES_PORTFOLIO = [
  // 1. Traditional Namkeen
  {
    id: 'RB-NAM-01',
    name: 'Real Bites Bikaneri Sev 150g',
    hindiName: 'रियल बाइट्स बीकानेरी सेव',
    category: 'Traditional Namkeen',
    pricePaise: 2550,
    mrpPaise: 3000,
    unit: 'Master Carton (60 pouches)',
    stockQuantity: 150,
    sku: 'RB-NAM-01',
    barcode: '8906012440011',
    tracksExpiry: 1
  },
  {
    id: 'RB-NAM-02',
    name: 'Real Bites Aaloo Sev 150g',
    hindiName: 'रियल बाइट्स आलू भुजिया सेव',
    category: 'Traditional Namkeen',
    pricePaise: 2550,
    mrpPaise: 3000,
    unit: 'Master Carton (60 pouches)',
    stockQuantity: 120,
    sku: 'RB-NAM-02',
    barcode: '8906012440028',
    tracksExpiry: 1
  },
  {
    id: 'RB-NAM-03',
    name: 'Real Bites Bhavnagari Ganthiya 200g',
    hindiName: 'रियल बाइट्स भावनगरी गांठिया',
    category: 'Traditional Namkeen',
    pricePaise: 2975,
    mrpPaise: 3500,
    unit: 'Master Carton (48 pouches)',
    stockQuantity: 110,
    sku: 'RB-NAM-03',
    barcode: '8906012440035',
    tracksExpiry: 1
  },
  {
    id: 'RB-NAM-04',
    name: 'Real Bites Papdi Ganthiya 200g',
    hindiName: 'रियल बाइट्स पापड़ी गांठिया',
    category: 'Traditional Namkeen',
    pricePaise: 2975,
    mrpPaise: 3500,
    unit: 'Master Carton (48 pouches)',
    stockQuantity: 95,
    sku: 'RB-NAM-04',
    barcode: '8906012440042',
    tracksExpiry: 1
  },
  {
    id: 'RB-NAM-05',
    name: 'Real Bites Nadiadi Mix 180g',
    hindiName: 'रियल बाइट्स नडियादी मिक्स नमकीन',
    category: 'Traditional Namkeen',
    pricePaise: 2975,
    mrpPaise: 3500,
    unit: 'Master Carton (48 pouches)',
    stockQuantity: 140,
    sku: 'RB-NAM-05',
    barcode: '8906012440059',
    tracksExpiry: 1
  },
  {
    id: 'RB-NAM-06',
    name: 'Real Bites Farali Chiwda 200g',
    hindiName: 'रियल बाइट्स फराली चिवड़ा (उपवास विशेष)',
    category: 'Traditional Namkeen',
    pricePaise: 3400,
    mrpPaise: 4000,
    unit: 'Master Carton (40 pouches)',
    stockQuantity: 85,
    sku: 'RB-NAM-06',
    barcode: '8906012440066',
    tracksExpiry: 1
  },
  {
    id: 'RB-NAM-07',
    name: 'Real Bites Sing Bhujiya 100g',
    hindiName: 'रियल बाइट्स सींग भुजिया (मसाला मूंगफली)',
    category: 'Traditional Namkeen',
    pricePaise: 1700,
    mrpPaise: 2000,
    unit: 'Master Carton (72 pouches)',
    stockQuantity: 160,
    sku: 'RB-NAM-07',
    barcode: '8906012440073',
    tracksExpiry: 1
  },
  {
    id: 'RB-NAM-08',
    name: 'Real Bites Moong Dal 100g',
    hindiName: 'रियल बाइट्स नमकीन मूंग दाल',
    category: 'Traditional Namkeen',
    pricePaise: 1700,
    mrpPaise: 2000,
    unit: 'Master Carton (72 pouches)',
    stockQuantity: 130,
    sku: 'RB-NAM-08',
    barcode: '8906012440080',
    tracksExpiry: 1
  },
  {
    id: 'RB-NAM-09',
    name: 'Real Bites Masala Boondi 150g',
    hindiName: 'रियल बाइट्स रायता एवं चाट मसाला बूंदी',
    category: 'Traditional Namkeen',
    pricePaise: 2125,
    mrpPaise: 2500,
    unit: 'Master Carton (60 pouches)',
    stockQuantity: 90,
    sku: 'RB-NAM-09',
    barcode: '8906012440097',
    tracksExpiry: 1
  },

  // 2. Potato Wafers
  {
    id: 'RB-WAF-01',
    name: 'Real Bites Classic Salted Wafers 40g',
    hindiName: 'रियल बाइट्स क्लासिक साल्टेड वेफर्स',
    category: 'Potato Wafers',
    pricePaise: 850,
    mrpPaise: 1000,
    unit: 'Master Box (96 pouches)',
    stockQuantity: 220,
    sku: 'RB-WAF-01',
    barcode: '8906012440103',
    tracksExpiry: 1
  },
  {
    id: 'RB-WAF-02',
    name: 'Real Bites Chatpata Masala Wafers 40g',
    hindiName: 'रियल बाइट्स चटपटा मसाला वेफर्स',
    category: 'Potato Wafers',
    pricePaise: 850,
    mrpPaise: 1000,
    unit: 'Master Box (96 pouches)',
    stockQuantity: 200,
    sku: 'RB-WAF-02',
    barcode: '8906012440110',
    tracksExpiry: 1
  },
  {
    id: 'RB-WAF-03',
    name: 'Real Bites Cream & Onion Wafers 40g',
    hindiName: 'रियल बाइट्स क्रीम एंड अनियन वेफर्स',
    category: 'Potato Wafers',
    pricePaise: 850,
    mrpPaise: 1000,
    unit: 'Master Box (96 pouches)',
    stockQuantity: 180,
    sku: 'RB-WAF-03',
    barcode: '8906012440127',
    tracksExpiry: 1
  },
  {
    id: 'RB-WAF-04',
    name: 'Real Bites Tangy Tomato Wafers 40g',
    hindiName: 'रियल बाइट्स टैंगी टोमैटो वेफर्स',
    category: 'Potato Wafers',
    pricePaise: 850,
    mrpPaise: 1000,
    unit: 'Master Box (96 pouches)',
    stockQuantity: 175,
    sku: 'RB-WAF-04',
    barcode: '8906012440134',
    tracksExpiry: 1
  },

  // 3. Extruded Snacks & Fryums
  {
    id: 'RB-EXT-01',
    name: 'Real Krackers Masala Wheel 45g',
    hindiName: 'रियल क्रैकर्स मसाला पहिया व्हील',
    category: 'Extruded Snacks & Fryums',
    pricePaise: 850,
    mrpPaise: 1000,
    unit: 'Master Box (80 pouches)',
    stockQuantity: 240,
    sku: 'RB-EXT-01',
    barcode: '8906012440141',
    tracksExpiry: 1
  },
  {
    id: 'RB-EXT-02',
    name: 'Real Bites Cheesy Rings 40g',
    hindiName: 'रियल बाइट्स चीज़ी रिंग्स',
    category: 'Extruded Snacks & Fryums',
    pricePaise: 850,
    mrpPaise: 1000,
    unit: 'Master Box (80 pouches)',
    stockQuantity: 190,
    sku: 'RB-EXT-02',
    barcode: '8906012440158',
    tracksExpiry: 1
  },
  {
    id: 'RB-EXT-03',
    name: 'Real Bites Masala Puff Balls 45g',
    hindiName: 'रियल बाइट्स मसाला पफ बॉल्स',
    category: 'Extruded Snacks & Fryums',
    pricePaise: 850,
    mrpPaise: 1000,
    unit: 'Master Box (80 pouches)',
    stockQuantity: 165,
    sku: 'RB-EXT-03',
    barcode: '8906012440165',
    tracksExpiry: 1
  },
  {
    id: 'RB-EXT-04',
    name: 'Real Bites Italian Pasta Fryums 50g',
    hindiName: 'रियल बाइट्स इटैलियन पास्ता फ्रायम्स',
    category: 'Extruded Snacks & Fryums',
    pricePaise: 850,
    mrpPaise: 1000,
    unit: 'Master Box (80 pouches)',
    stockQuantity: 150,
    sku: 'RB-EXT-04',
    barcode: '8906012440172',
    tracksExpiry: 1
  },

  // 4. Bakery & Confectionery
  {
    id: 'RB-BAK-01',
    name: 'Real Bites Peanut Chikki Bar 100g',
    hindiName: 'रियल बाइट्स गुड़ मूंगफली चिक्की',
    category: 'Bakery & Confectionery',
    pricePaise: 2100,
    mrpPaise: 2500,
    unit: 'Master Carton (50 bars)',
    stockQuantity: 140,
    sku: 'RB-BAK-01',
    barcode: '8906012440189',
    tracksExpiry: 1
  },
  {
    id: 'RB-BAK-02',
    name: 'Real Bites Special Butter Khari 200g',
    hindiName: 'रियल बाइट्स क्रिस्पी बटर खारी',
    category: 'Bakery & Confectionery',
    pricePaise: 3800,
    mrpPaise: 4500,
    unit: 'Master Carton (30 boxes)',
    stockQuantity: 90,
    sku: 'RB-BAK-02',
    barcode: '8906012440196',
    tracksExpiry: 1
  },
  {
    id: 'RB-BAK-03',
    name: 'Real Bites Premium Elaichi Rusk 250g',
    hindiName: 'रियल बाइट्स प्रीमियम इलायची टोस्ट रस्क',
    category: 'Bakery & Confectionery',
    pricePaise: 3400,
    mrpPaise: 4000,
    unit: 'Master Carton (32 packs)',
    stockQuantity: 110,
    sku: 'RB-BAK-03',
    barcode: '8906012440202',
    tracksExpiry: 1
  },
  {
    id: 'RB-BAK-04',
    name: 'Real Bites Vanilla Cream Rolls (6 Pcs)',
    hindiName: 'रियल बाइट्स वैनिला क्रीम रोल्स',
    category: 'Bakery & Confectionery',
    pricePaise: 2500,
    mrpPaise: 3000,
    unit: 'Master Carton (40 packs)',
    stockQuantity: 85,
    sku: 'RB-BAK-04',
    barcode: '8906012440219',
    tracksExpiry: 1
  }
];

async function main() {
  console.log('1. Authenticating as OWNER on Cloudflare Staging...');
  const loginRes = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'owner', password: 'RouteFlow@2026!' })
  });
  const { access_token } = await loginRes.json();
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + access_token,
    'X-Automated-Test': 'true'
  };

  console.log('2. Fetching current products from API...');
  const existingRes = await fetch(`${API_BASE}/products?include_inactive=true`, { headers });
  const existing = await existingRes.json();
  console.log(`Found ${existing.length} existing products in DB.`);

  console.log('3. Deleting non-RealBites products via API...');
  for (const p of existing) {
    if (!p.id.startsWith('RB-')) {
      const delRes = await fetch(`${API_BASE}/products/${p.id}`, { method: 'DELETE', headers });
      const delData = await delRes.json();
      console.log(`  - Deleted ${p.id} (${p.name}):`, delData.message || delData.success);
    }
  }

  console.log('\n4. Adding Real Bites portfolio items via POST /products API...');
  for (const item of REAL_BITES_PORTFOLIO) {
    const createRes = await fetch(`${API_BASE}/products`, {
      method: 'POST',
      headers,
      body: JSON.stringify(item)
    });
    const createData = await createRes.json();
    if (createData.success) {
      console.log(`  + Created: ${item.id} - ${item.name} (${item.category}) | Stock: ${item.stockQuantity} | ₹${(item.pricePaise / 100).toFixed(2)}`);
    } else {
      console.error(`  x Failed to create ${item.id}:`, createData);
    }
  }

  console.log('\n5. Verifying active products via GET /products API...');
  const finalRes = await fetch(`${API_BASE}/products`, { headers });
  const activeProducts = await finalRes.json();
  console.log(`\n========================================`);
  console.log(`SUCCESS: ${activeProducts.length} REAL BITES PRODUCTS ARE LIVE`);
  console.log(`========================================`);
  activeProducts.forEach((p, idx) => {
    console.log(`  ${(idx + 1).toString().padStart(2, ' ')}. [${p.id}] ${p.name}`);
    console.log(`      Hindi: ${p.hindiName} | Category: ${p.category} | Barcode: ${p.barcode}`);
    console.log(`      Wholesale: ₹${(p.pricePaise / 100).toFixed(2)} | MRP: ₹${(p.mrpPaise / 100).toFixed(2)} | Stock: ${p.stockQuantity} ${p.unit}`);
  });
}

main().catch(console.error);
