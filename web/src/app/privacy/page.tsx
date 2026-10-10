import React from 'react';
import { ShieldCheck, Lock, MapPin, Phone, Database, ArrowLeft, Camera, Bell } from 'lucide-react';
import Link from 'next/link';

export default function PrivacyPolicyPage() {
  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto bg-white rounded-2xl shadow-xl border border-slate-200/80 overflow-hidden">
        {/* Header */}
        <div className="bg-gradient-to-r from-blue-700 via-blue-600 to-indigo-700 text-white px-6 py-8 sm:px-10">
          <Link
            href="/login"
            className="inline-flex items-center gap-2 text-blue-100 hover:text-white text-xs sm:text-sm font-medium mb-4 px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition backdrop-blur-xs"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back to Console</span>
          </Link>
          <div className="flex items-center gap-4">
            <div className="p-3 bg-white/10 rounded-2xl border border-white/20 backdrop-blur-sm">
              <ShieldCheck className="w-8 h-8 sm:w-10 sm:h-10 text-white" />
            </div>
            <div>
              <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight">RouteFlow Privacy Policy</h1>
              <p className="text-blue-100 text-xs sm:text-sm mt-1">
                Last updated: October 2026 • Compliant with Google Play Store Developer Policies
              </p>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 sm:p-10 space-y-8 text-sm sm:text-base leading-relaxed text-slate-700">
          <section>
            <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-2">
              <Database className="w-5 h-5 text-blue-600" />
              1. Overview & Scope
            </h2>
            <p className="text-slate-600">
              RouteFlow (&quot;we&quot;, &quot;our&quot;, or &quot;the Service&quot;) provides wholesale distribution, warehouse fulfillment, and field-sales management software for authorized businesses and their contracted employees. This Privacy Policy outlines how our native mobile application and web management console collect, process, and protect your information.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-2">
              <MapPin className="w-5 h-5 text-blue-600" />
              2. Location Data Collection & Prominent Disclosure
            </h2>
            <div className="bg-amber-50/80 border-l-4 border-amber-500 p-4 rounded-r-xl my-2 text-slate-800">
              <p className="font-semibold text-amber-900 mb-1">
                Prominent Location Disclosure (Google Play Compliance):
              </p>
              <p className="text-sm text-slate-700">
                RouteFlow collects <strong>precise background and foreground location data</strong> when a field sales or delivery employee starts an active duty shift. This data is collected solely to:
              </p>
              <ul className="list-disc ml-5 mt-2 space-y-1 text-sm text-slate-700">
                <li>Verify on-site attendance during retail kirana shop visits.</li>
                <li>Calculate travel distance and fuel reimbursement allowances.</li>
                <li>Ensure accurate order dispatch and delivery sequence routing.</li>
              </ul>
              <p className="text-xs text-amber-800 mt-2 font-medium">
                Location tracking terminates immediately when the employee clocks out or ends their shift. Location is never shared with third-party advertisers or data brokers.
              </p>
            </div>
          </section>

          <section>
            <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-2">
              <Phone className="w-5 h-5 text-blue-600" />
              3. Contact & Business Data
            </h2>
            <p className="text-slate-600">
              We collect contact information necessary for wholesale commerce:
            </p>
            <ul className="list-disc ml-5 mt-2 space-y-1 text-slate-600">
              <li><strong>Retail Store Profiles:</strong> Store trade name, owner name, mobile phone number, and physical store coordinates for delivery dispatch.</li>
              <li><strong>Staff Profiles:</strong> Employee full name, assigned username, mobile number, and role credentials.</li>
              <li><strong>Transactional Data:</strong> Purchase orders, payment receipt records (Cash, UPI, Cheque), and 6-digit delivery verification OTPs.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-2">
              <ShieldCheck className="w-5 h-5 text-blue-600" />
              4. Camera, Photos, Notifications & Diagnostics (Google Play Data Safety)
            </h2>
            <div className="space-y-3">
              <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                <div className="flex items-center gap-2 font-semibold text-slate-900">
                  <Camera className="w-4 h-4 text-blue-600" />
                  <span>Camera & Photos Permission</span>
                </div>
                <p className="text-sm text-slate-600 mt-1">
                  Used in warehouse operations exclusively for <strong>optical barcode scanning (CameraX)</strong> and capturing optional product return/damaged goods condition proofs. Camera data is processed on-device for barcode detection; images are only uploaded when a user explicitly attaches photo evidence for damaged returns.
                </p>
              </div>
              <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                <div className="flex items-center gap-2 font-semibold text-slate-900">
                  <Bell className="w-4 h-4 text-blue-600" />
                  <span>Notifications Permission</span>
                </div>
                <p className="text-sm text-slate-600 mt-1">
                  Used strictly for real-time operational alerts including <strong>Order Approval notifications, Dispatch Batch handovers, and Shift Tracker background service status</strong>.
                </p>
              </div>
              <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                <p className="font-semibold text-slate-900">Diagnostics & Crash Logs</p>
                <p className="text-sm text-slate-600 mt-1">
                  Technical diagnostic data (non-personally identifiable error stack traces, network latency metrics) may be logged to ensure app stability and prevent data loss during offline synchronization.
                </p>
              </div>
            </div>
          </section>

          <section>
            <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-2">
              <Lock className="w-5 h-5 text-blue-600" />
              5. Data Security & Storage
            </h2>
            <p className="text-slate-600">
              All communication between RouteFlow mobile devices, web consoles, and our Cloudflare Workers edge network is secured via mandatory HTTPS/TLS encryption in transit. Passwords and sensitive session tokens are salted and hashed using bcrypt and SHA-256 before storage in Cloudflare D1 serverless SQLite databases.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-slate-900 mb-2">
              6. Data Deletion & Retention
            </h2>
            <p className="text-slate-600">
              Business owners have full authority to request complete deletion of company records, employee accounts, and retailer registries by contacting their designated account administrator or writing to <code>privacy@routeflow.in</code>. Account sessions may be revoked at any time from the Web Console.
            </p>
          </section>

          <section className="border-t border-slate-200 pt-6">
            <h3 className="font-semibold text-slate-900 mb-1">Developer & Contact Information</h3>
            <p className="text-sm text-slate-600">
              RouteFlow Technologies • Jaipur, Rajasthan, India<br />
              Developer Support: <code className="text-blue-600">support@routeflow.in</code>
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
