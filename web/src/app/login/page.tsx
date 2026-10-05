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
      router.push('/dashboard');
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
    <div className="min-h-screen bg-slate-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8 text-slate-900">
      <div className="sm:mx-auto sm:w-full sm:max-w-md text-center">
        <div className="inline-flex p-3 bg-blue-600 rounded-2xl shadow-lg shadow-blue-500/20 mb-4">
          <Truck className="w-10 h-10 text-white" />
        </div>
        <h2 className="text-3xl font-extrabold tracking-tight text-slate-900">
          RouteFlow
        </h2>
        <p className="mt-1 text-sm text-slate-500">
          Executive & Operations Web Management Console
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-6 shadow-xl shadow-slate-200/60 rounded-2xl border border-slate-200 sm:px-10">
          {error && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm font-medium">
              {error}
            </div>
          )}

          <form className="space-y-5" onSubmit={handleLogin}>
            <div>
              <label className="block text-sm font-medium text-slate-700">
                Username / Email
              </label>
              <div className="mt-1.5">
                <input
                  type="text"
                  required
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full px-4 py-2.5 bg-slate-50/50 border border-slate-300 rounded-xl text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-600 focus:bg-white focus:border-transparent text-sm transition"
                  placeholder="e.g. owner"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-700">
                Password
              </label>
              <div className="mt-1.5">
                <input
                  type="password"
                  required
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full px-4 py-2.5 bg-slate-50/50 border border-slate-300 rounded-xl text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-600 focus:bg-white focus:border-transparent text-sm transition"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex justify-center py-3 px-4 border border-transparent rounded-xl shadow-md shadow-blue-600/20 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 transition cursor-pointer"
            >
              {loading ? 'Authenticating...' : 'Sign In to Console'}
            </button>
          </form>

          <div className="mt-6 pt-6 border-t border-slate-100">
            <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider text-center mb-3">
              Quick Fill Staging Roles
            </p>
            <div className="grid grid-cols-2 gap-2.5">
              <button
                type="button"
                onClick={() => quickFill('owner', 'RouteFlow@2026!')}
                className="flex items-center justify-center gap-2 py-2.5 px-3 text-xs font-semibold rounded-xl bg-slate-50 hover:bg-blue-50/60 hover:border-blue-300 text-slate-700 hover:text-blue-700 border border-slate-200 transition cursor-pointer"
              >
                <ShieldCheck className="w-4 h-4 text-blue-600" />
                Owner
              </button>
              <button
                type="button"
                onClick={() => quickFill('admin', 'RouteFlow@2026!')}
                className="flex items-center justify-center gap-2 py-2.5 px-3 text-xs font-semibold rounded-xl bg-slate-50 hover:bg-emerald-50/60 hover:border-emerald-300 text-slate-700 hover:text-emerald-700 border border-slate-200 transition cursor-pointer"
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
