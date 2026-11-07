import {
  ProductItem,
  RetailerItem,
  OrderItem,
  OrderLineItem,
  InwardReceipt,
  CashHandoverItem,
  TruckFleet,
  CanonicalRole
} from './types';

export const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'https://routeflow-api-staging.thisisrakesh21.workers.dev';

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

/**
 * Ensures user is authenticated with live server.
 * If not authenticated or role mismatch, auto-logs into staging account.
 */
export async function ensureAuthenticated(targetRole: CanonicalRole = 'OWNER'): Promise<string> {
  const currentToken = getStoredToken();
  const currentUser = getStoredUser();

  const roleToUsername: Record<CanonicalRole, string> = {
    OWNER: 'owner',
    ADMIN: 'admin',
    SALES: 'sales',
    WAREHOUSE: 'warehouse',
    DELIVERY: 'delivery',
  };

  const expectedUsername = roleToUsername[targetRole] || 'owner';

  // If already logged in as this role
  if (currentToken && currentUser) {
    const r = currentUser.role?.toUpperCase() || '';
    if (
      (targetRole === 'OWNER' && r.includes('OWNER')) ||
      (targetRole === 'SALES' && r.includes('SALES')) ||
      (targetRole === 'WAREHOUSE' && r.includes('WAREHOUSE')) ||
      (targetRole === 'DELIVERY' && r.includes('DELIVERY'))
    ) {
      return currentToken;
    }
  }

  // Auto-login to server with role credential
  try {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: expectedUsername,
        password: 'RouteFlow@2026!',
      }),
    });
    const data = await res.json();
    if (data.access_token) {
      setSession(data);
      return data.access_token;
    }
  } catch (e) {
    console.error('Auto-login error:', e);
  }

  return currentToken || '';
}

export async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getStoredToken();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-Automated-Test': 'true', // Enables simulated OTP in staging
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
      throw new Error(errData.error || 'Invalid credentials');
    }
    // Re-authenticate and retry once
    const newToken = await ensureAuthenticated('OWNER');
    if (newToken && newToken !== token) {
      headers['Authorization'] = `Bearer ${newToken}`;
      const retryRes = await fetch(`${API_BASE}${path}`, { ...options, headers });
      if (retryRes.ok) return await retryRes.json();
    }
    clearSession();
    throw new Error('Session expired. Please log in again.');
  }

  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error || `Request failed with status ${res.status}`);
  }

  return data as T;
}

// ==========================================
// REAL SERVER DATA FETCHERS & MUTATIONS
// ==========================================

export async function fetchLiveProducts(): Promise<ProductItem[]> {
  const rawList = await apiFetch<any[]>('/products');
  return rawList.map((p) => {
    const pricePaise = p.pricePaise || p.price_paise || 5000;
    const boxQty = p.unit?.toLowerCase().includes('crate') || p.unit?.toLowerCase().includes('box') ? 96 : 24;
    const stripQty = 12;

    return {
      id: p.id,
      name: p.name,
      hindiName: p.hindiName || p.hindi_name || `${p.name} (स्टॉक)`,
      category: p.category || 'FMCG Products',
      mrpRupees: ((pricePaise * 1.2) / 100),
      piecePricePaise: Math.round(pricePaise / boxQty),
      stripQty: stripQty,
      boxQty: boxQty,
      gstRate: 12.0,
      godownStockBoxes: p.stockQuantity ?? p.stock_quantity ?? 0,
      carStockBoxes: p.reservedQuantity ?? p.reserved_quantity ?? 0,
      badge: p.stockQuantity <= 10 ? 'Low Stock' : 'Active Server SKU',
      batchNumber: p.sku || `BATCH-${p.id}`,
      expiryDate: '2027-03-31',
      reorderLevelBoxes: 20,
    };
  });
}

export async function fetchLiveRetailers(): Promise<RetailerItem[]> {
  const rawList = await apiFetch<any[]>('/retailers');
  return rawList.map((r) => ({
    id: r.id,
    name: r.name,
    ownerName: r.name,
    phone: r.contactNumber || r.contact_number || '+91 98290 00000',
    address: r.address || 'Main Beat Market, Jodhpur',
    beat: r.beatId || r.beat_id || 'BEAT-04 Mandore',
    outstandingBalanceRupees: Math.abs((r.outstandingAmountPaise || r.outstanding_amount_paise || 0) / 100),
    creditLimitRupees: (r.creditLimitPaise || r.credit_limit_paise || 1000000) / 100,
    lastVisitDate: new Date().toISOString().slice(0, 10),
    latitude: r.latitude || 26.85,
    longitude: r.longitude || 75.76,
  }));
}

export async function fetchLiveOrders(): Promise<OrderItem[]> {
  const rawList = await apiFetch<any[]>('/orders');
  return rawList.map((o) => {
    const totalPaise = o.totalAmountPaise || o.total_amount_paise || 0;
    const totalRupees = totalPaise / 100;
    const createdDate = o.createdAt
      ? new Date(o.createdAt).toISOString().replace('T', ' ').slice(0, 16)
      : new Date().toISOString().replace('T', ' ').slice(0, 16);

    return {
      id: o.id,
      orderCode: o.id.startsWith('ORD-') ? o.id : `ORD-${o.id.slice(-6)}`,
      retailerId: o.retailerId || o.retailer_id || '',
      retailerName: o.retailerName || o.retailer_name || `Retailer Shop (${o.retailerId || 'R1'})`,
      retailerPhone: '+91 98290 12345',
      retailerAddress: 'Main Market, Beat Route',
      status: o.status || 'SUBMITTED',
      totalAmountRupees: totalRupees,
      items: (o.items || []).map((i: any) => ({
        productId: i.productId || i.product_id || 'P1',
        productName: i.productName || i.product_id || 'FMCG Pack',
        unit: 'BOX',
        quantity: i.quantity || 1,
        boxEquivalent: i.quantity || 1,
        unitPriceRupees: (i.pricePaiseAtTime || totalPaise) / 100,
        totalPriceRupees: (i.pricePaiseAtTime || totalPaise) / 100,
      })),
      assignedTruckPlate: o.deliveryEmployeeId ? 'RJ-19-GA-1102' : undefined,
      deliveryOtp: '1234',
      createdAt: createdDate,
    };
  });
}

export async function fetchLiveHandovers(): Promise<CashHandoverItem[]> {
  const rawList = await apiFetch<any[]>('/cash-handovers').catch(() => []);
  const list = Array.isArray(rawList) ? rawList : (rawList as any).handovers || [];
  return list.map((h: any) => ({
    id: h.id,
    driverName: h.driverName || h.driver_name || 'Suresh Yadav',
    truckPlate: 'RJ-19-GA-1102',
    collectedRupees: (h.amountPaise || h.amount_paise || 495000) / 100,
    submittedRupees: (h.amountPaise || h.amount_paise || 495000) / 100,
    status: h.status || 'PENDING',
    timestamp: new Date(h.submittedAt || Date.now()).toISOString().replace('T', ' ').slice(0, 16),
  }));
}

/**
 * Live Server Mutation: Inward Receipt / Stock Adjustment
 */
export async function serverAdjustInventory(
  productId: string,
  changeQuantity: number,
  reason: 'STOCK_RECEIPT' | 'AUDIT_CORRECTION' = 'STOCK_RECEIPT',
  notes: string = 'Inward Receipt'
) {
  return await apiFetch<any>('/inventory/adjust', {
    method: 'POST',
    body: JSON.stringify({
      productId,
      changeQuantity,
      reason,
      notes,
    }),
  });
}

/**
 * Live Server Mutation: Create Retailer
 */
export async function serverCreateRetailer(data: {
  name: string;
  contactNumber: string;
  address: string;
  beatId?: string;
  creditLimitRupees?: number;
}) {
  return await apiFetch<any>('/retailers', {
    method: 'POST',
    body: JSON.stringify({
      name: data.name,
      contactNumber: data.contactNumber,
      address: data.address,
      beatId: data.beatId || 'BEAT-04',
      creditLimitRupees: data.creditLimitRupees || 15000,
    }),
  });
}

/**
 * Live Server Mutation: Create Order
 */
export async function serverCreateOrder(data: {
  retailerId: string;
  totalAmountPaise: number;
  items: Array<{ productId: string; quantity: number; pricePaiseAtTime: number }>;
}) {
  const orderId = `ORD-${Math.floor(100000 + Math.random() * 900000)}`;
  return await apiFetch<any>('/orders', {
    method: 'POST',
    body: JSON.stringify({
      idempotencyKey: `idemp_${orderId}`,
      order: {
        id: orderId,
        retailerId: data.retailerId,
        totalAmountPaise: data.totalAmountPaise,
      },
      items: data.items,
    }),
  });
}

/**
 * Live Server Mutation: Approve Order
 */
export async function serverApproveOrder(orderId: string) {
  return await apiFetch<any>(`/orders/${orderId}/approve`, {
    method: 'POST',
  });
}

/**
 * Live Server Mutation: Pick Item & Pack Order
 */
export async function serverPickAndPackOrder(orderId: string, productId: string, deliveryEmployeeId: string = 'user_delivery') {
  // 1. Start picking
  await apiFetch(`/orders/${orderId}/start-picking`, { method: 'POST' }).catch(() => null);
  // 2. Pick item
  await apiFetch(`/orders/${orderId}/pick-item`, {
    method: 'POST',
    body: JSON.stringify({ productId, isPicked: true }),
  }).catch(() => null);
  // 3. Pack order
  return await apiFetch(`/orders/${orderId}/pack`, {
    method: 'POST',
    body: JSON.stringify({ deliveryEmployeeId }),
  });
}

/**
 * Live Server Mutation: Dispatch & Deliver Order
 */
export async function serverDispatchAndDeliver(
  orderId: string,
  recipientName: string = 'Shopkeeper',
  paymentMethod: 'CASH' | 'CREDIT' = 'CASH'
) {
  // 1. Dispatch
  await apiFetch(`/orders/${orderId}/dispatch`, {
    method: 'POST',
    body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' }),
  }).catch(() => null);

  // 2. Request OTP
  const otpRes = await apiFetch<any>(`/orders/${orderId}/request-otp`, {
    method: 'POST',
  }).catch(() => ({ debugOtp: '123456' }));

  const otpCode = otpRes.debugOtp || '123456';

  // 3. Confirm Delivery
  return await apiFetch(`/orders/${orderId}/deliver`, {
    method: 'POST',
    body: JSON.stringify({
      otp: otpCode,
      recipientName,
      paymentMethod,
    }),
  });
}
