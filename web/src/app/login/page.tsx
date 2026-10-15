'use client';

import { useState } from 'react';
import Link from 'next/link';
import { apiFetch, setSession, AuthResponse } from '@/lib/api';
import {
  Truck,
  Lock,
  User,
  Eye,
  EyeOff,
  Globe,
  HelpCircle,
  CheckCircle2,
  AlertCircle
} from 'lucide-react';

export default function LoginPage() {
  const [username, setUsername] = useState('owner');
  const [password, setPassword] = useState('RouteFlow@2026!');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lang, setLang] = useState<'en' | 'hi'>('en');

  const toggleLanguage = () => {
    setLang(prev => (prev === 'en' ? 'hi' : 'en'));
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await apiFetch<AuthResponse>('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ username, password }),
      });

      const allowedRoles = ['OWNER', 'ADMIN', 'SALESPERSON', 'WAREHOUSE_MANAGER', 'DELIVERY_EXECUTIVE'];
      if (!allowedRoles.includes(res.user.role)) {
        throw new Error(`Unauthorized role: ${res.user.role}.`);
      }

      setSession(res);
      window.location.href = '/dashboard';
    } catch (err: any) {
      setError(err.message || 'Login failed. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  const quickFill = (u: string, p: string) => {
    setUsername(u);
    setPassword(p);
    setError(null);
  };

  const isHindi = lang === 'hi';

  return (
    <div className="min-h-screen bg-[#F7F8FA] flex flex-col justify-between text-[#172033]">
      {/* Top Bar with Language Toggle */}
      <header className="w-full max-w-5xl mx-auto px-6 py-5 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-[#2563EB] flex items-center justify-center text-white shadow-sm">
            <Truck className="w-5 h-5" />
          </div>
          <div>
            <span className="font-bold text-lg tracking-tight text-[#172033]">RouteFlow</span>
            <span className="ml-2 text-xs font-semibold px-2 py-0.5 rounded-full bg-[#EFF6FF] text-[#2563EB] border border-[#BFDBFE]">
              Distributor OS
            </span>
          </div>
        </div>

        <button
          onClick={toggleLanguage}
          type="button"
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-[#E4E7EC] bg-white text-xs font-medium text-[#172033] hover:bg-[#F8FAFC] transition cursor-pointer"
        >
          <Globe className="w-3.5 h-3.5 text-[#667085]" />
          <span>{isHindi ? 'English' : 'हिन्दी'}</span>
        </button>
      </header>

      {/* Main Login Card Container */}
      <main className="w-full max-w-md mx-auto px-4 py-8">
        <div className="bg-white rounded-2xl border border-[#E4E7EC] shadow-sm p-7 sm:p-8">
          <div className="mb-6">
            <h1 className="text-xl font-bold text-[#172033] tracking-tight">
              {isHindi ? 'कंपनी में साइन इन करें' : 'Sign in to your company'}
            </h1>
            <p className="text-sm text-[#667085] mt-1">
              {isHindi ? 'अपने वितरक खाते का विवरण दर्ज करें' : 'Enter your distributor account credentials'}
            </p>
          </div>

          {error && (
            <div className="mb-5 p-3.5 bg-[#FEF3F2] border border-[#FECDCA] rounded-xl text-[#B42318] text-xs font-medium flex items-start gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-[#344054] mb-1.5">
                {isHindi ? 'उपयोगकर्ता नाम' : 'Username or Employee ID'}
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-[#667085]">
                  <User className="w-4 h-4" />
                </div>
                <input
                  type="text"
                  required
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full pl-9 pr-3 py-2.5 text-sm bg-white border border-[#D0D5DD] rounded-xl text-[#172033] placeholder-[#98A2B3] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] transition"
                  placeholder="e.g. owner"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-[#344054] mb-1.5">
                {isHindi ? 'पासवर्ड' : 'Password'}
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-[#667085]">
                  <Lock className="w-4 h-4" />
                </div>
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-9 pr-10 py-2.5 text-sm bg-white border border-[#D0D5DD] rounded-xl text-[#172033] placeholder-[#98A2B3] focus:outline-none focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] transition"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-[#667085] hover:text-[#172033]"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-2.5 px-4 bg-[#2563EB] hover:bg-[#1D4ED8] disabled:bg-[#98A2B3] text-white text-sm font-semibold rounded-xl transition shadow-xs flex items-center justify-center gap-2 cursor-pointer mt-2"
            >
              {loading ? (
                <span>{isHindi ? 'साइन इन हो रहा है…' : 'Signing in…'}</span>
              ) : (
                <span>{isHindi ? 'साइन इन करें' : 'Sign In'}</span>
              )}
            </button>
          </form>

          {/* Quick-fill Roles for Staging / Pilot Demo */}
          <div className="mt-6 pt-5 border-t border-[#F2F4F7]">
            <p className="text-[11px] font-medium text-[#667085] mb-2.5">
              {isHindi ? 'त्वरित टेस्ट खाते (स्टेजिंग):' : 'Staging quick-fill accounts:'}
            </p>
            <div className="grid grid-cols-2 gap-2 text-xs">
              <button
                type="button"
                onClick={() => quickFill('owner', 'RouteFlow@2026!')}
                className="px-2.5 py-1.5 rounded-lg border border-[#E4E7EC] bg-[#F8FAFC] hover:bg-[#EFF6FF] hover:border-[#BFDBFE] text-left transition font-medium text-[#344054]"
              >
                Owner
              </button>
              <button
                type="button"
                onClick={() => quickFill('admin_tl', 'RouteFlow@2026!')}
                className="px-2.5 py-1.5 rounded-lg border border-[#E4E7EC] bg-[#F8FAFC] hover:bg-[#EFF6FF] hover:border-[#BFDBFE] text-left transition font-medium text-[#344054]"
              >
                Admin / TL
              </button>
              <button
                type="button"
                onClick={() => quickFill('sales1', 'RouteFlow@2026!')}
                className="px-2.5 py-1.5 rounded-lg border border-[#E4E7EC] bg-[#F8FAFC] hover:bg-[#EFF6FF] hover:border-[#BFDBFE] text-left transition font-medium text-[#344054]"
              >
                Sales Exec
              </button>
              <button
                type="button"
                onClick={() => quickFill('warehouse1', 'RouteFlow@2026!')}
                className="px-2.5 py-1.5 rounded-lg border border-[#E4E7EC] bg-[#F8FAFC] hover:bg-[#EFF6FF] hover:border-[#BFDBFE] text-left transition font-medium text-[#344054]"
              >
                Warehouse
              </button>
              <button
                type="button"
                onClick={() => quickFill('driver1', 'RouteFlow@2026!')}
                className="col-span-2 px-2.5 py-1.5 rounded-lg border border-[#E4E7EC] bg-[#F8FAFC] hover:bg-[#EFF6FF] hover:border-[#BFDBFE] text-left transition font-medium text-[#344054]"
              >
                Delivery Executive
              </button>
            </div>
          </div>
        </div>

        {/* Footer Support Notice */}
        <div className="text-center mt-6">
          <p className="text-xs text-[#667085] flex items-center justify-center gap-1.5">
            <HelpCircle className="w-3.5 h-3.5 text-[#98A2B3]" />
            <span>
              {isHindi
                ? 'साइन इन में सहायता चाहिए? अपने वितरक व्यवस्थापक से संपर्क करें'
                : 'Need help signing in? Contact your distributor administrator'}
            </span>
          </p>
        </div>
      </main>

      {/* Footer */}
      <footer className="w-full max-w-5xl mx-auto px-6 py-4 flex items-center justify-between text-xs text-[#98A2B3]">
        <div className="flex items-center gap-2">
          <span className="w-1.5 h-1.5 rounded-full bg-[#15803D]"></span>
          <span>Cloudflare Edge Connected</span>
        </div>
        <Link href="/privacy" className="hover:text-[#667085] transition">
          Privacy Policy
        </Link>
      </footer>
    </div>
  );
}
