'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, setSession, AuthResponse } from '@/lib/api';
import { ShieldCheck, Truck, Store, PackageCheck } from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('owner');
  const [password, setPassword] = useState('RouteFlow@2026!');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await apiFetch<AuthResponse>('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ username, password }),
      });

      if (!['OWNER', 'ADMIN'].includes(res.user.role)) {
        throw new Error(`Web Dashboard is for Owner and Admin roles only. Logged in as ${res.user.role}.`);
      }

      setSession(res);
      window.location.href = '/dashboard';
    } catch (err: any) {
      setError(err.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  const quickFill = (u: string, p: string) => {
    setUsername(u);
    setPassword(p);
    setError(null);
  };

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col justify-center px-4 py-8 sm:py-12 sm:px-6 lg:px-8 text-slate-900">
      <div className="w-full max-w-md mx-auto text-center">
        <div className="inline-flex p-3 bg-blue-600 rounded-2xl shadow-lg shadow-blue-500/20 mb-3">
          <Truck className="w-9 h-9 sm:w-10 sm:h-10 text-white" />
        </div>
        <h2 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
          RouteFlow
        </h2>
        <p className="mt-1 text-xs sm:text-sm text-slate-500">
          Executive & Operations Web Management Console
        </p>
      </div>

      <div className="mt-6 sm:mt-8 w-full max-w-md mx-auto">
        <div className="bg-white py-6 px-5 sm:py-8 sm:px-10 shadow-xl shadow-slate-200/60 rounded-2xl border border-slate-200">
          {error && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-xs sm:text-sm font-medium">
              {error}
            </div>
          )}

          <form className="space-y-4 sm:space-y-5" onSubmit={handleLogin}>
            <div>
              <label className="block text-xs sm:text-sm font-medium text-slate-700">
                Username / Email
              </label>
              <div className="mt-1.5">
                <input
                  type="text"
                  required
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full px-4 py-2.5 bg-slate-50/50 border border-slate-300 rounded-xl text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-600 focus:bg-white focus:border-transparent text-base sm:text-sm transition min-h-[44px]"
                  placeholder="e.g. owner"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs sm:text-sm font-medium text-slate-700">
                Password
              </label>
              <div className="mt-1.5">
                <input
                  type="password"
                  required
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full px-4 py-2.5 bg-slate-50/50 border border-slate-300 rounded-xl text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-600 focus:bg-white focus:border-transparent text-base sm:text-sm transition min-h-[44px]"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center py-3 px-4 border border-transparent rounded-xl shadow-md shadow-blue-600/20 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 transition cursor-pointer min-h-[46px]"
            >
              {loading ? 'Authenticating...' : 'Sign In to Console'}
            </button>
          </form>

          <div className="mt-6 pt-5 border-t border-slate-100">
            <p className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider text-center mb-2.5">
              Quick Fill Staging Roles
            </p>
            <div className="grid grid-cols-2 gap-2 sm:gap-2.5">
              <button
                type="button"
                onClick={() => quickFill('owner', 'RouteFlow@2026!')}
                className="flex items-center justify-center gap-1.5 sm:gap-2 py-2.5 px-3 text-xs font-semibold rounded-xl bg-slate-50 hover:bg-blue-50/60 hover:border-blue-300 text-slate-700 hover:text-blue-700 border border-slate-200 transition cursor-pointer min-h-[42px]"
              >
                <ShieldCheck className="w-4 h-4 text-blue-600" />
                Owner
              </button>
              <button
                type="button"
                onClick={() => quickFill('admin', 'RouteFlow@2026!')}
                className="flex items-center justify-center gap-1.5 sm:gap-2 py-2.5 px-3 text-xs font-semibold rounded-xl bg-slate-50 hover:bg-emerald-50/60 hover:border-emerald-300 text-slate-700 hover:text-emerald-700 border border-slate-200 transition cursor-pointer min-h-[42px]"
              >
                <PackageCheck className="w-4 h-4 text-emerald-600" />
                Admin
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
