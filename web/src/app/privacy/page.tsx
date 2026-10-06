import React from 'react';
import { ShieldCheck, Lock, MapPin, Phone, Database, ArrowLeft } from 'lucide-react';
import Link from 'next/link';

export default function PrivacyPolicyPage() {
  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto bg-white rounded-2xl shadow-xl border border-slate-200 overflow-hidden">
        {/* Header */}
        <div className="bg-blue-600 text-white px-6 py-8 sm:px-10">
          <Link href="/login" className="inline-flex items-center gap-2 text-blue-100 hover:text-white text-sm font-medium mb-4">
            <ArrowLeft className="w-4 h-4" /> Back to Console
          </Link>
          <div className="flex items-center gap-3">
            <ShieldCheck className="w-10 h-10 text-blue-200" />
            <div>
              <h1 className="text-2xl sm:text-3xl font-extrabold">RouteFlow Privacy Policy</h1>
              <p className="text-blue-100 text-sm mt-1">
                Last updated: October 2026 | Compliant with Google Play Store Developer Policies
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
            <p>
              RouteFlow (&quot;we&quot;, &quot;our&quot;, or &quot;the Service&quot;) provides wholesale distribution, warehouse fulfillment, and field-sales management software for authorized businesses and their contracted employees. This Privacy Policy outlines how our native mobile application and web management console collect, process, and protect your information.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-2">
              <MapPin className="w-5 h-5 text-blue-600" />
              2. Location Data Collection & Prominent Disclosure
            </h2>
            <div className="bg-amber-50 border-l-4 border-amber-500 p-4 rounded-r-xl my-2 text-slate-800">
              <p className="font-semibold text-amber-900 mb-1">
                Prominent Location Disclosure (Google Play Compliance):
              </p>
              <p className="text-sm">
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
            <p>
              We collect contact information necessary for wholesale commerce:
            </p>
            <ul className="list-disc ml-5 mt-2 space-y-1">
              <li><strong>Retail Store Profiles:</strong> Store trade name, owner name, mobile phone number, and physical store coordinates for delivery dispatch.</li>
              <li><strong>Staff Profiles:</strong> Employee full name, assigned username, mobile number, and role credentials.</li>
              <li><strong>Transactional Data:</strong> Purchase orders, payment receipt records (Cash, UPI, Cheque), and 6-digit delivery verification OTPs.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-2">
              <Lock className="w-5 h-5 text-blue-600" />
              4. Data Security & Storage
            </h2>
            <p>
              All communication between RouteFlow mobile devices, web consoles, and our Cloudflare Workers edge network is secured via mandatory HTTPS / TLS 1.3 encryption. Passwords and sensitive session tokens are salted and hashed using bcrypt and SHA-256 before storage in Cloudflare D1 serverless SQLite databases.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-slate-900 mb-2">
              5. Data Deletion & Retention
            </h2>
            <p>
              Business owners have full authority to request complete deletion of company records, employee accounts, and retailer registries by contacting their designated account administrator or writing to <code>privacy@routeflow.in</code>. Account sessions may be revoked at any time from the Web Console.
            </p>
          </section>

          <section className="border-t border-slate-200 pt-6">
            <h3 className="font-semibold text-slate-900 mb-1">Developer & Contact Information</h3>
            <p className="text-sm text-slate-600">
              RouteFlow Technologies | Jaipur, Rajasthan, India<br />
              Developer Support: <code>support@routeflow.in</code>
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
