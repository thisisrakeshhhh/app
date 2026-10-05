'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, setSession, AuthResponse } from '@/lib/api';
import { ShieldCheck, Truck, Store, PackageCheck } from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('owner');
  const [password, setPassword] = useState('password123');
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
    <div className="min-h-screen bg-slate-900 flex flex-col justify-center py-12 sm:px-6 lg:px-8 text-white">
      <div className="sm:mx-auto sm:w-full sm:max-w-md text-center">
        <div className="inline-flex p-3 bg-blue-600 rounded-2xl shadow-lg shadow-blue-500/30 mb-4">
          <Truck className="w-10 h-10 text-white" />
        </div>
        <h2 className="text-3xl font-extrabold tracking-tight text-white">
          RouteFlow
        </h2>
        <p className="mt-2 text-sm text-slate-400">
          Executive & Operations Web Management Console
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-slate-800 py-8 px-6 shadow-2xl rounded-2xl border border-slate-700 sm:px-10">
          {error && (
            <div className="mb-4 p-3 bg-red-900/50 border border-red-500/50 rounded-xl text-red-200 text-sm">
              {error}
            </div>
          )}

          <form className="space-y-6" onSubmit={handleLogin}>
            <div>
              <label className="block text-sm font-medium text-slate-300">
                Username / Email
              </label>
              <div className="mt-1">
                <input
                  type="text"
                  required
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full px-4 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                  placeholder="e.g. owner"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300">
                Password
              </label>
              <div className="mt-1">
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full px-4 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex justify-center py-3 px-4 border border-transparent rounded-xl shadow-lg shadow-blue-600/30 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 transition"
            >
              {loading ? 'Authenticating...' : 'Sign In to Console'}
            </button>
          </form>

          <div className="mt-6 pt-6 border-t border-slate-700">
            <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider text-center mb-3">
              Quick Fill Staging Roles
            </p>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => quickFill('owner', 'password123')}
                className="flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-slate-700/60 hover:bg-slate-700 text-slate-200 border border-slate-600 transition"
              >
                <ShieldCheck className="w-3.5 h-3.5 text-blue-400" />
                Owner
              </button>
              <button
                type="button"
                onClick={() => quickFill('admin', 'password123')}
                className="flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-slate-700/60 hover:bg-slate-700 text-slate-200 border border-slate-600 transition"
              >
                <PackageCheck className="w-3.5 h-3.5 text-emerald-400" />
                Admin
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
