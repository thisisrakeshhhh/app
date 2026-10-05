# RouteFlow Web Management Console (Admin & Owner)

This is the Next.js web dashboard for **RouteFlow**, built to manage operations for **Admin** and **Owner** identically to the mobile app.

---

## 🚀 Features

- **Owner & Admin Authentication**:
  - Secure JWT authentication with role authorization (`OWNER` or `ADMIN`).
  - Staging credentials: `owner` / `RouteFlow@2026!` and `admin` / `RouteFlow@2026!`.
  - Pre-filled quick login chips for rapid credential selection during testing.
- **Business Overview KPIs**:
  - Pending Approvals count with direct link to approvals.
  - Delivered Sales Today (total INR and count).
  - Orders in Picking / Packing.
  - Retailer Outstanding Receivables sum.
- **Orders Management**:
  - Live order filter tabs (`All`, `Pending Approval`, `Approved`, `Dispatched`, `Delivered`).
  - Order details: Retailer name, order code, total amount, items list, date.
  - **One-click Owner Approval**: Approves orders directly in the Cloudflare D1 database.
- **Cash Handover Settlements**:
  - Real-time review of delivery agent cash collections.
  - Verification of collected vs. reported cash amounts.
  - **One-click Owner Cash Acceptance**: Settles and reconciles cash collections instantly.
- **Products Catalog**:
  - Visual product listing with SKU, price, wholesale rates, and active status.
- **Retailers Directory**:
  - Directory of registered shops with phone, address, and live outstanding balances.

---

## 🛠 Local Development

```bash
# Navigate to web directory
cd web

# Install dependencies (if not already done)
npm install

# Run development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## 🌐 Deploy to Vercel

### Option 1: Automatic via Vercel GitHub Dashboard (Recommended)

1. Go to [https://vercel.com/new](https://vercel.com/new).
2. Select your repository: `thisisrakeshhhh/app`.
3. In **Project Settings**:
   - **Root Directory**: Click `Edit` and select `web`.
   - **Framework Preset**: `Next.js` (detected automatically).
4. In **Environment Variables**:
   - Key: `NEXT_PUBLIC_API_URL`
   - Value: `https://routeflow-api-staging.thisisrakesh21.workers.dev`
5. Click **Deploy**.

Vercel will automatically build and deploy `web/` with each push to `main`.

---

### Option 2: Deploy via Vercel CLI

From the `web/` folder:

```bash
cd web
npx vercel
```

- When prompted for project settings, link or create your project.
- Set `NEXT_PUBLIC_API_URL` to `https://routeflow-api-staging.thisisrakesh21.workers.dev`.
- For production:
```bash
npx vercel --prod
```
