const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'https://routeflow-api-staging.thisisrakesh21.workers.dev';

export interface User {
  id: string;
  name: string;
  role: string;
  company_id: string;
}

export interface AuthResponse {
  access_token?: string;
  refresh_token?: string;
  token?: string;
  refreshToken?: string;
  user: User;
}

export function getStoredToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('rf_token');
}

export function getStoredUser(): User | null {
  if (typeof window === 'undefined') return null;
  const raw = localStorage.getItem('rf_user');
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function setSession(auth: AuthResponse) {
  if (typeof window === 'undefined') return;
  const token = auth.access_token || auth.token || '';
  const refresh = auth.refresh_token || auth.refreshToken || '';
  localStorage.setItem('rf_token', token);
  localStorage.setItem('rf_refresh', refresh);
  localStorage.setItem('rf_user', JSON.stringify(auth.user));
}

export function clearSession() {
  if (typeof window === 'undefined') return;
  localStorage.removeItem('rf_token');
  localStorage.removeItem('rf_refresh');
  localStorage.removeItem('rf_user');
}

export async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getStoredToken();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> || {}),
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  if (res.status === 401) {
    if (path.startsWith('/auth/login')) {
      const errData = await res.json().catch(() => ({}));
      throw new Error(errData.error || 'Invalid username or password');
    }
    clearSession();
    if (typeof window !== 'undefined' && !window.location.pathname.startsWith('/login')) {
      window.location.href = '/login';
    }
    throw new Error('Session expired. Please log in again.');
  }

  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error || `Request failed with status ${res.status}`);
  }

  return data as T;
}
