'use client';

import { useState } from 'react';
import Link from 'next/link';
import { apiFetch, setSession, AuthResponse } from '@/lib/api';
import {
  ShieldCheck,
  Truck,
  Store,
  PackageCheck,
  Lock,
  User,
  Eye,
  EyeOff,
  CheckCircle2,
  ArrowRight,
  Activity,
  Layers,
  Sparkles
} from 'lucide-react';

export default function LoginPage() {
  const [username, setUsername] = useState('owner');
  const [password, setPassword] = useState('RouteFlow@2026!');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedRole, setSelectedRole] = useState<'owner' | 'admin' | 'sales' | 'warehouse' | 'delivery'>('owner');

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
      setError(err.message || 'Login failed. Please check credentials.');
    } finally {
      setLoading(false);
    }
  };

  const quickFill = (u: string, p: string, roleKey: 'owner' | 'admin' | 'sales' | 'warehouse' | 'delivery') => {
    setUsername(u);
    setPassword(p);
    setSelectedRole(roleKey);
    setError(null);
  };

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col justify-center selection:bg-blue-600 selection:text-white">
      {/* Background Decorative Lighting */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -left-40 w-96 h-96 bg-blue-600/15 rounded-full blur-3xl"></div>
        <div className="absolute top-1/2 -right-40 w-96 h-96 bg-indigo-600/15 rounded-full blur-3xl"></div>
        <div className="absolute -bottom-40 left-1/3 w-96 h-96 bg-cyan-600/10 rounded-full blur-3xl"></div>
      </div>

      <div className="relative w-full max-w-6xl mx-auto px-4 py-8 sm:py-12 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center">
          
          {/* Left Column: Brand Hero & Platform Overview */}
          <div className="lg:col-span-6 space-y-6 text-white order-2 lg:order-1">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-blue-500/10 border border-blue-400/20 text-blue-400 text-xs font-semibold backdrop-blur-sm">
              <Sparkles className="w-3.5 h-3.5 text-blue-400" />
              <span>Next-Gen Wholesale & Logistics OS</span>
            </div>

            <div className="space-y-3">
              <div className="flex items-center gap-3">
                <div className="p-3 bg-gradient-to-tr from-blue-600 to-indigo-600 rounded-2xl shadow-xl shadow-blue-500/25 border border-blue-400/30">
                  <Truck className="w-8 h-8 text-white" />
                </div>
                <div>
                  <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-white">
                    RouteFlow
                  </h1>
                  <p className="text-sm font-medium text-blue-300">
                    B2B Distribution & Warehouse Console
                  </p>
                </div>
              </div>

              <p className="text-slate-300 text-sm sm:text-base leading-relaxed max-w-lg">
                Complete operational visibility across field sales booking, godown picking, van dispatch manifests, and 100% verified cash reconciliation.
              </p>
            </div>

            {/* Feature Cards Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
              <div className="p-3.5 rounded-xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
                <div className="flex items-center gap-2.5 mb-1.5">
                  <div className="p-1.5 rounded-lg bg-blue-500/10 text-blue-400">
                    <ShieldCheck className="w-4 h-4" />
                  </div>
                  <h3 className="text-xs font-semibold text-white">Owner Control Room</h3>
                </div>
                <p className="text-xs text-slate-400 leading-normal">
                  Real-time sales pulse, cash handover approvals, and overdue khata exposure.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
                <div className="flex items-center gap-2.5 mb-1.5">
                  <div className="p-1.5 rounded-lg bg-emerald-500/10 text-emerald-400">
                    <Layers className="w-4 h-4" />
                  </div>
                  <h3 className="text-xs font-semibold text-white">Godown Fulfillment</h3>
                </div>
                <p className="text-xs text-slate-400 leading-normal">
                  Dense stock management, digital picking queue, and batch trip dispatch.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
                <div className="flex items-center gap-2.5 mb-1.5">
                  <div className="p-1.5 rounded-lg bg-amber-500/10 text-amber-400">
                    <Store className="w-4 h-4" />
                  </div>
                  <h3 className="text-xs font-semibold text-white">Retailer 360 Khata</h3>
                </div>
                <p className="text-xs text-slate-400 leading-normal">
                  Instant Kirana ledger, payment reconciliation, and credit limit tracking.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
                <div className="flex items-center gap-2.5 mb-1.5">
                  <div className="p-1.5 rounded-lg bg-purple-500/10 text-purple-400">
                    <CheckCircle2 className="w-4 h-4" />
                  </div>
                  <h3 className="text-xs font-semibold text-white">OTP Verification</h3>
                </div>
                <p className="text-xs text-slate-400 leading-normal">
                  Zero delivery fraud with mandatory 6-digit delivery authentication.
                </p>
              </div>
            </div>

            {/* Status Footer */}
            <div className="pt-2 flex flex-wrap items-center gap-4 text-xs text-slate-400">
              <div className="flex items-center gap-2">
                <span className="relative flex h-2 w-2">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                </span>
                <span className="text-slate-300 font-medium">Cloudflare Edge Live</span>
              </div>
              <span className="text-slate-600">•</span>
              <span>Jaipur Wholesale Hub</span>
              <span className="text-slate-600">•</span>
              <Link href="/privacy" className="text-blue-400 hover:text-blue-300 hover:underline">
                Privacy Policy
              </Link>
            </div>
          </div>

          {/* Right Column: Authentication Card */}
          <div className="lg:col-span-6 w-full max-w-md mx-auto order-1 lg:order-2">
            <div className="bg-white rounded-2xl shadow-2xl shadow-slate-950/50 border border-slate-200/80 p-6 sm:p-8 backdrop-blur-xl">
              
              <div className="mb-6">
                <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-slate-900">
                  Management Console
                </h2>
                <p className="text-xs sm:text-sm text-slate-500 mt-1">
                  Enter your credentials to access operations
                </p>
              </div>

              {error && (
                <div className="mb-5 p-3.5 bg-red-50 border border-red-200 rounded-xl text-red-700 text-xs sm:text-sm font-medium flex items-start gap-2.5">
                  <div className="w-2 h-2 rounded-full bg-red-500 mt-1.5 shrink-0" />
                  <span>{error}</span>
                </div>
              )}

              <form className="space-y-4" onSubmit={handleLogin}>
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                    Username / Work Email
                  </label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                      <User className="w-4 h-4" />
                    </div>
                    <input
                      type="text"
                      required
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                      className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-600 focus:bg-white focus:border-transparent text-sm transition"
                      placeholder="e.g. owner"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                    Password
                  </label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                      <Lock className="w-4 h-4" />
                    </div>
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      autoComplete="current-password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="w-full pl-10 pr-10 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-600 focus:bg-white focus:border-transparent text-sm transition"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute inset-y-0 right-0 pr-3.5 flex items-center text-slate-400 hover:text-slate-600 transition"
                      tabIndex={-1}
                    >
                      {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 active:bg-blue-800 shadow-md shadow-blue-600/25 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-600 disabled:opacity-50 transition cursor-pointer min-h-[46px]"
                >
                  {loading ? (
                    <>
                      <Activity className="w-4 h-4 animate-spin" />
                      <span>Authenticating...</span>
                    </>
                  ) : (
                    <>
                      <span>Sign In to Console</span>
                      <ArrowRight className="w-4 h-4" />
                    </>
                  )}
                </button>
              </form>

              {/* Quick Role Fill Pills */}
              <div className="mt-6 pt-5 border-t border-slate-100">
                <div className="flex items-center justify-between mb-2.5">
                  <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                    Quick Role Selector
                  </p>
                  <span className="text-[10px] text-slate-400 font-medium">Staging Access</span>
                </div>
                
                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => quickFill('owner', 'RouteFlow@2026!', 'owner')}
                    className={`flex flex-col items-center justify-center py-2 px-1 text-xs font-semibold rounded-xl border transition cursor-pointer ${
                      selectedRole === 'owner'
                        ? 'bg-blue-50 border-blue-400 text-blue-700 shadow-xs'
                        : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                    }`}
                  >
                    <ShieldCheck className="w-4 h-4 text-blue-600 mb-0.5" />
                    <span>Owner</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => quickFill('admin', 'RouteFlow@2026!', 'admin')}
                    className={`flex flex-col items-center justify-center py-2 px-1 text-xs font-semibold rounded-xl border transition cursor-pointer ${
                      selectedRole === 'admin'
                        ? 'bg-indigo-50 border-indigo-400 text-indigo-700 shadow-xs'
                        : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                    }`}
                  >
                    <PackageCheck className="w-4 h-4 text-indigo-600 mb-0.5" />
                    <span>Admin</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => quickFill('sales', 'RouteFlow@2026!', 'sales')}
                    className={`flex flex-col items-center justify-center py-2 px-1 text-xs font-semibold rounded-xl border transition cursor-pointer ${
                      selectedRole === 'sales'
                        ? 'bg-amber-50 border-amber-400 text-amber-700 shadow-xs'
                        : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                    }`}
                  >
                    <Store className="w-4 h-4 text-amber-600 mb-0.5" />
                    <span>Sales</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => quickFill('warehouse', 'RouteFlow@2026!', 'warehouse')}
                    className={`flex flex-col items-center justify-center py-2 px-1 text-xs font-semibold rounded-xl border transition cursor-pointer ${
                      selectedRole === 'warehouse'
                        ? 'bg-purple-50 border-purple-400 text-purple-700 shadow-xs'
                        : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                    }`}
                  >
                    <Layers className="w-4 h-4 text-purple-600 mb-0.5" />
                    <span>Warehouse</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => quickFill('delivery', 'RouteFlow@2026!', 'delivery')}
                    className={`col-span-2 flex items-center justify-center gap-1.5 py-2 px-2 text-xs font-semibold rounded-xl border transition cursor-pointer ${
                      selectedRole === 'delivery'
                        ? 'bg-emerald-50 border-emerald-400 text-emerald-700 shadow-xs'
                        : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                    }`}
                  >
                    <Truck className="w-4 h-4 text-emerald-600" />
                    <span>Delivery Executive</span>
                  </button>
                </div>
              </div>

            </div>
          </div>

        </div>
      </div>
    </div>
  );
}
