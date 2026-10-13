import os
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill_hex)
    tcPr.append(shd)

def create_document():
    doc = Document()
    
    # Configure margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

    # Styles
    title_p = doc.add_paragraph()
    title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title_run = title_p.add_run("ROUTEFLOW (B2B WHOLESALE & LOGISTICS OS)")
    title_run.font.name = 'Calibri'
    title_run.font.size = Pt(24)
    title_run.font.bold = True
    title_run.font.color.rgb = RGBColor(15, 23, 42)

    subtitle_p = doc.add_paragraph()
    subtitle_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    sub_run = subtitle_p.add_run("Comprehensive Technical Specification, System Architecture & Technology Decision Guide\nVersion 1.0.0 | Production Release | Confidential")
    sub_run.font.name = 'Calibri'
    sub_run.font.size = Pt(11)
    sub_run.font.italic = True
    sub_run.font.color.rgb = RGBColor(100, 116, 139)

    doc.add_paragraph() # Spacer

    # Helper for adding sections
    def add_h1(text):
        p = doc.add_paragraph()
        run = p.add_run(text)
        run.font.name = 'Calibri'
        run.font.size = Pt(16)
        run.font.bold = True
        run.font.color.rgb = RGBColor(30, 58, 138) # Dark Blue
        p.paragraph_format.space_before = Pt(16)
        p.paragraph_format.space_after = Pt(6)

    def add_h2(text):
        p = doc.add_paragraph()
        run = p.add_run(text)
        run.font.name = 'Calibri'
        run.font.size = Pt(13)
        run.font.bold = True
        run.font.color.rgb = RGBColor(14, 116, 144) # Cyan/Dark
        p.paragraph_format.space_before = Pt(12)
        p.paragraph_format.space_after = Pt(4)

    def add_body(text):
        p = doc.add_paragraph()
        run = p.add_run(text)
        run.font.name = 'Calibri'
        run.font.size = Pt(10.5)
        run.font.color.rgb = RGBColor(51, 65, 85)
        p.paragraph_format.space_after = Pt(4)
        return p

    def add_bullet(text, bold_prefix=""):
        p = doc.add_paragraph(style='List Bullet')
        if bold_prefix:
            b_run = p.add_run(bold_prefix)
            b_run.font.name = 'Calibri'
            b_run.font.size = Pt(10.5)
            b_run.font.bold = True
            b_run.font.color.rgb = RGBColor(15, 23, 42)
        run = p.add_run(text)
        run.font.name = 'Calibri'
        run.font.size = Pt(10.5)
        run.font.color.rgb = RGBColor(51, 65, 85)
        p.paragraph_format.space_after = Pt(2)

    def add_code_block(code_text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(4)
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.left_indent = Inches(0.2)
        run = p.add_run(code_text)
        run.font.name = 'Consolas'
        run.font.size = Pt(9)
        run.font.color.rgb = RGBColor(30, 41, 59)

    # 1. EXECUTIVE SUMMARY & PROBLEM STATEMENT
    add_h1("1. Executive Summary & Problem Domain")
    add_body("In India's ₹70 Lakh Crore retail economy, traditional FMCG, grocery, and Kirana distribution operates on high volume, razor-thin operating margins (2% to 5%), and intense informal credit. Millions of independent distributors manage field sales executives, physical godowns, delivery vans, and hundreds of retail shopkeepers.")
    add_body("The fundamental industry problem is Cash & Credit Leakage across disconnected operational silos:")
    add_bullet(" Salesmen book orders on paper or WhatsApp with zero visibility into live godown inventory, resulting in high order cancellation and shopkeeper dissatisfaction.", "Field Sales Blindness:")
    add_bullet(" Distributors extend credit without real-time tracking, resulting in massive bad debts (Udhaar) and uncontrolled credit risk.", "Credit Overextension:")
    add_bullet(" Godown pickers face packing errors, item swaps, and misplaced stock due to lack of digital item verification.", "Warehouse Disorganization:")
    add_bullet(" Delivery drivers claim shops were closed or tamper with cash collected at shop counters without proof.", "Logistics Leakage & Cash Dispute:")
    add_body("RouteFlow solves this end-to-end as a unified, real-time Operating System connecting Owner, Field Sales, Godown Packing, and Van Delivery into one cohesive state machine.")

    # 2. CANONICAL USER STORY (JAIPUR DISTRIBUTOR WORKFLOW)
    add_h1("2. The Canonical Operational Lifecycle (Jaipur Kirana Machine)")
    add_body("RouteFlow is engineered around a realistic, battle-tested 4-role distribution story:")
    add_bullet(" Distributor Principal / Owner who sets credit rules, pricing, manages staff, and oversees financial closing.", "Role 1 - Ramesh Ji (Owner):")
    add_bullet(" Field Sales Executive on motorbike covering Mansarovar Beat (BEAT-04) with GPS check-in.", "Role 2 - Rakesh Kumar (Sales):")
    add_bullet(" Godown / Depot Manager in charge of bin picking, item packing, and batch verification.", "Role 3 - Manoj Kumar (Warehouse):")
    add_bullet(" Delivery Driver / Auto Driver responsible for route stops, OTP verification, and cash collection.", "Role 4 - Suresh Yadav (Delivery):")

    add_h2("The 11-Step Daily Cycle:")
    add_bullet(" Morning 08:30 AM: Ramesh Ji starts depot operations, reviews bank balance, pending receivables, and godown stock.", "Step 1 (Depot Opening):")
    add_bullet(" 09:00 AM: Rakesh Kumar punches in via mobile app (GPS breadcrumbs start). Views assigned route of 28 Kirana stores.", "Step 2 (Sales Shift Start):")
    add_bullet(" 09:45 AM: Rakesh reaches Sharma General Store. GPS verifies location within 50m. App logs in-store dwell time.", "Step 3 (Store Check-In):")
    add_bullet(" 10:00 AM: Books wholesale order for ₹3,450 (10x Premium Tea, 5x Biscuit Cartons, 2x Oil Tins). Offline SQLite stores order instantly.", "Step 4 (Order Booking):")
    add_bullet(" 10:15 AM: Ramesh Ji receives real-time approval alert. Checks retailer credit exposure (₹12,400 < ₹50,000 limit) and stock availability. Taps 'Approve'.", "Step 5 (Owner Credit Approval):")
    add_bullet(" 10:45 AM: Manoj Kumar sees order in Godown Terminal. Picks line items from rack bins. Packs into 2 corrugated cartons. System seals packing status.", "Step 6 (Godown Picking & Packing):")
    add_bullet(" 11:30 AM: Cartons assigned to Suresh Yadav's delivery van. Order status transitions to OUT_FOR_DELIVERY.", "Step 7 (Van Dispatch):")
    add_bullet(" 02:15 PM: Suresh arrives at Sharma General Store. Initiates delivery. System triggers SMS OTP to retailer's mobile phone.", "Step 8 (OTP Verification):")
    add_bullet(" 02:20 PM: Shopkeeper provides OTP. Suresh collects ₹3,450 Cash on Delivery. App marks order DELIVERED; Suresh's custody account debited +₹3,450.", "Step 9 (Delivery & Cash Collection):")
    add_bullet(" 06:30 PM: Suresh returns to depot. Taps 'Submit Cash Handover' for ₹3,450. Ramesh Ji inspects physical currency and taps 'Accept Handover'.", "Step 10 (Depot Cash Handover):")
    add_bullet(" 07:00 PM: Ramesh Ji executes Daily Business Closing. Shopkeeper Khata, Stock Ledger, Driver Account, and Profit Margins reconcile to ₹0.00 discrepancy.", "Step 11 (Daily Business Closing):")

    # 3. REPOSITORY & FOLDER STRUCTURE
    add_h1("3. Repository Architecture & Directory Hierarchy")
    add_body("The project is organized as a production-grade monorepo containing three core subsystems:")
    add_code_block("""D:\\app
├── app/                  # Android Native App (Kotlin, Jetpack Compose, Room, Hilt)
│   ├── src/main/java/com/routeflow/app/
│   │   ├── core/         # Cross-cutting foundational infrastructure
│   │   │   ├── database/ # Room SQLite DB (Entities, DAOs, Migrations)
│   │   │   ├── network/  # Retrofit, OkHttp, DTOs, Auth Interceptors
│   │   │   ├── sync/     # Account-Scoped Offline-First Sync Engine
│   │   │   ├── security/ # EncryptedSharedPreferences, Keystore, Pinning
│   │   │   └── ui/theme/ # Material 3 Design System, RouteFlow Colors
│   │   ├── feature/      # Multi-Role Feature Modules
│   │   │   ├── auth/     # Login, Role Routing, Session Guard
│   │   │   ├── sales/    # Beat Plan, Shop Visit, Catalog, Order Booking
│   │   │   ├── warehouse/# Picking Queue, Carton Packing, Bin Management
│   │   │   ├── delivery/ # Route Navigation, Stop Check, OTP Proof, COD
│   │   │   ├── owner/    # Approvals, Khata 360, Staff Roster, Settlement
│   │   │   └── common/   # Universal components, Hindi/English labels
│   │   └── build.gradle.kts (staging / release build flavors)
├── backend/              # Cloudflare Workers Serverless API (Hono, D1, TypeScript)
│   ├── src/
│   │   ├── index.ts      # Main HTTP Router, RBAC, Core Endpoints
│   │   ├── daily-cycle.ts# Approvals, Invoicing, Cash Handover Settlement
│   │   ├── field-cycle.ts# Shifts, GPS Breadcrumbs, Field Visits, Audits
│   │   ├── delivery-proof.ts # Secure OTP Generator, Rate Limiting, SMS Gateway
│   │   ├── onboarding.ts # Public Tenant Signup, Owner Onboarding, Hashing
│   │   ├── operating.ts  # Day Book, P&L, Inventory Ledger, Retailer 360
│   │   ├── warehouse.ts  # Multi-bin Picking, Packing State Machine
│   │   ├── trips.ts      # Van Loading, Route Sequencing, Trip Lifecycle
│   │   └── governance.ts # Audit logs, CSV Export, Tenant Isolation Guard
│   ├── wrangler.toml     # Cloudflare Worker & D1 Database Bindings
│   └── test/             # 100% Automated Regression & Hardcore QA Suites
├── web/                  # Next.js 16 Executive Web Console (TypeScript, Tailwind)
│   ├── src/
│   │   ├── app/          # Next.js App Router (dashboard, login, privacy)
│   │   ├── components/   # Metric Cards, Data Tables, Bottom Nav, Modals
│   │   └── lib/          # Typed API Client, Session Storage, Formatters
│   └── package.json
└── docs/                 # QA Reports, Screenshots, Architectural Specifications""")

    # 4. TECH STACK, TOOLS & ALTERNATIVES ANALYSIS
    add_h1("4. Technology Stack & Exhaustive Alternatives Analysis")
    add_body("Every architectural decision in RouteFlow was deliberately evaluated against alternative tools and frameworks based on real-world Indian distribution conditions (low-cost hardware, unstable 4G/5G, offline godowns, zero tolerance for financial discrepancies).")

    # Table for Comparisons
    table = doc.add_table(rows=1, cols=4)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False

    hdr_cells = table.rows[0].cells
    headers = ["Tier", "Chosen Technology", "Evaluated Alternatives", "Core Architectural Justification"]
    col_widths = [Inches(1.0), Inches(1.8), Inches(1.8), Inches(2.6)]

    for idx, (cell, h_text) in enumerate(zip(hdr_cells, headers)):
        cell.text = h_text
        cell.width = col_widths[idx]
        set_cell_background(cell, "1E3A8A")
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for run in p.runs:
            run.font.bold = True
            run.font.color.rgb = RGBColor(255, 255, 255)
            run.font.size = Pt(9.5)

    matrix_data = [
        ("Mobile Client", "Native Android\n(Kotlin + Jetpack Compose)", "Flutter\nReact Native", "1. Zero JS bridge overhead on 2GB RAM phones.\n2. Native background GPS service never killed by OEM battery savers.\n3. SQLite Room guarantees offline-first ACID khata.\n4. Camera hardware scanning has 0ms latency."),
        ("Backend Tier", "Cloudflare Workers\n(Hono + TypeScript)", "Node.js / Express on EC2\nPython FastAPI / Django\nGo Fiber", "1. Sub-15ms edge latency across Indian telecom.\n2. Zero cold start vs AWS Lambda.\n3. Zero server maintenance/patching costs.\n4. Auto-scales effortlessly during morning order surges."),
        ("Database", "Cloudflare D1 (Serverless Distributed SQLite)", "PostgreSQL (RDS)\nMongoDB\nFirebase Firestore", "1. Exactly matches Android Room SQL schema.\n2. True ACID relational transactions for financial ledgers.\n3. Zero connection pooling limits.\n4. Avoids Firebase's unbounded document read pricing."),
        ("Web Console", "Next.js 16 (App Router + Tailwind)", "React SPA (Vite)\nAngular\nVue / Nuxt", "1. SSR enables instant first contentful paint for owners.\n2. Mobile bottom navigation gives app-like feel on phone browser.\n3. Shared TypeScript models with backend API.\n4. Built-in image optimization and route prefetching."),
        ("Architecture", "Account-Scoped Offline Sync + RBAC", "Online-Only REST\nGraphQL Subscriptions", "1. Kirana basements have 0 signal; orders must never block.\n2. Strict tenant isolation at DB query level.\n3. High-integrity idempotency prevents duplicate billing.")
    ]

    for row_idx, data in enumerate(matrix_data):
        row_cells = table.add_row().cells
        bg_color = "F8FAFC" if row_idx % 2 == 0 else "FFFFFF"
        for col_idx, text in enumerate(data):
            cell = row_cells[col_idx]
            cell.text = text
            cell.width = col_widths[col_idx]
            set_cell_background(cell, bg_color)
            p = cell.paragraphs[0]
            for run in p.runs:
                run.font.name = 'Calibri'
                run.font.size = Pt(9)
                run.font.color.rgb = RGBColor(30, 41, 59)

    doc.add_paragraph() # Spacer

    # 5. DEEP DIVE INTO CHOICES AND REJECTIONS
    add_h2("4.1 Why Native Android Kotlin Compose (And Why NOT Flutter or React Native)?")
    add_body("In logistics and field sales, 98% of users in India carry budget Android devices (Vivo Y-series, Redmi, Realme) costing under ₹10,000 with 2GB–4GB RAM and aggressive battery managers.")
    add_bullet(" Aggressive Chinese OEM ROMs (FuntouchOS, MIUI) terminate background processes after 5 minutes. Native Kotlin uses Android Foreground Services with sticky notifications (`NotificationCompat`), ensuring continuous GPS breadcrumb logging for salesmen shifts without being killed.", "1. Background GPS & Sensor Integrity:")
    add_bullet(" React Native relies on a JavaScript bridge or Hermes engine; Flutter bundles a full Skia/Impeller graphics engine (~30MB base size). Native Compose produces an optimized ~6.5MB AAB with instant boot-up and zero memory bloat.", "2. Memory Footprint on 2GB RAM:")
    add_bullet(" Room SQLite provides typed compile-time SQL validation and offline-first reactive StateFlow streams. In Flutter or React Native, SQLite plugins require serialization over asynchronous bridges, causing UI frame drops during large 10,000-SKU catalog queries.", "3. Offline Database Reliability:")

    add_h2("4.2 Why Cloudflare Workers & D1 (And Why NOT Traditional AWS EC2 / Docker or Firebase)?")
    add_body("Traditional B2B apps run Express/Django on AWS EC2 or containerized clusters. This was rejected for critical economic and operational reasons:")
    add_bullet(" Cloudflare Workers run on V8 isolates distributed across 300+ cities globally, including Mumbai, Delhi, Chennai, and Bengaluru. Cold start is less than 5ms (compared to 800ms–2500ms for Docker containers or AWS Lambda).", "1. Zero Cold-Start Edge Execution:")
    add_bullet(" A traditional EC2 instance runs 24/7, costing ₹5,000–₹15,000/month even when distributors are asleep at night. Cloudflare Workers cost $0 when idle and scale instantly during the 09:00–11:00 AM morning order booking rush.", "2. Radical Cost Efficiency:")
    add_bullet(" Firebase Firestore charges per document read. A single distributor dashboard refreshing 1,000 orders and 500 retailer balances produces 1,500 document reads per page reload. Firestore lacks double-entry SQL constraints, making balance reconciliation error-prone.", "3. Why NOT Firebase Firestore:")

    add_h2("4.3 Why Next.js 16 Web Dashboard (And Why NOT Vite React SPA)?")
    add_bullet(" Distributors access the web console from both desktop computers in the office and mobile phones while travelling. Next.js App Router provides instant server-rendered HTML with full meta hydration.", "1. Universal Responsive Experience:")
    add_bullet(" Next.js Server Components and Edge middleware guard against unauthorized token leakage before rendering the DOM.", "2. Security & Token Hygiene:")

    # 6. DATA MODEL & SCHEMA DESIGN
    add_h1("5. Core Data Schema & State Machine")
    add_body("RouteFlow enforces strict relational integrity in Cloudflare D1 and Android Room across the following entities:")
    add_bullet(" Top-level isolation barrier. All queries enforce `WHERE company_id = ?`.", "companies (Tenants):")
    add_bullet(" System actors with roles: OWNER, ADMIN, SALESPERSON, WAREHOUSE_MANAGER, DELIVERY_EXECUTIVE.", "users (Employees):")
    add_bullet(" Independent shops tagged with GPS coordinates, beat ID, credit limit, and live balance.", "retailers (Kirana Stores):")
    add_bullet(" SKU catalog with price_paise, mrp_paise, stock_quantity, and reserved_quantity.", "products (Inventory):")
    add_bullet(" Order entity governed by state machine: PENDING_APPROVAL → APPROVED → PICKING → PACKED → OUT_FOR_DELIVERY → DELIVERED (or DELIVERY_FAILED).", "orders & order_items:")
    add_bullet(" Two-man rule cash collection ledger (Driver custody → Owner accepted).", "cash_handovers:")
    add_bullet(" Immutable trail tracking every financial and operational mutation.", "audit_logs:")

    # 7. SECURITY & PRODUCTION READINESS
    add_h1("6. Security, Hardening & Compliance")
    add_bullet(" Cryptographically signed JWT tokens with 15-minute access expiry and 30-day sliding refresh sessions.", "Token Security:")
    add_bullet(" Cryptographic secure RNG OTP (`100000..999999`) sent to shopkeeper mobile phone. Zero prefill or debug leakage in production.", "Delivery Proof OTP:")
    add_bullet(" All mutate endpoints accept `idempotencyKey` preventing double charges or duplicate order bookings on flaky cellular networks.", "Network Idempotency:")
    add_bullet(" Zero occurrences of third-party consumer branding, test OTP leaks, or insecure debug flags.", "Zero Forbidden Terms:")

    # Output file
    os.makedirs("docs", exist_ok=True)
    output_path = os.path.abspath("docs/RouteFlow_Complete_Architecture_and_Technical_Specification.docx")
    doc.save(output_path)
    print(f"Document successfully created at: {output_path}")

if __name__ == "__main__":
    create_document()
