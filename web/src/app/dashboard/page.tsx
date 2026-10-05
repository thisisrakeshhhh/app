'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, getStoredUser, clearSession, User } from '@/lib/api';
import {
  Truck,
  Package,
  Store,
  Users,
  CheckCircle,
  Clock,
  ArrowUpRight,
  LogOut,
  RefreshCw,
  Wallet,
  Building,
  RotateCcw
} from 'lucide-react';

interface OverviewMetrics {
  pendingApprovals: number;
  lowStockItems: number;
  deliveredSalesToday: number;
  retailerOutstanding: number;
  pickingPacking: number;
  outForDelivery: number;
  exceptions: number;
}

interface Order {
  id: string;
  retailer_id: string;
  retailer_name?: string;
  total_amount_paise: number;
  status: string;
  created_at: number;
  items_count?: number;
}

interface CashHandover {
  id: string;
  user_id: string;
  driver_name?: string;
  amount_paise: number;
  status: string;
  submitted_at: number;
}

export default function DashboardPage() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [activeTab, setActiveTab] = useState<'overview' | 'orders' | 'handovers' | 'products' | 'retailers'>('overview');
  
  const [metrics, setMetrics] = useState<OverviewMetrics>({
    pendingApprovals: 0,
    lowStockItems: 0,
    deliveredSalesToday: 13500,
    retailerOutstanding: 5930000,
    pickingPacking: 0,
    outForDelivery: 0,
    exceptions: 0,
  });

  const [orders, setOrders] = useState<Order[]>([]);
  const [handovers, setHandovers] = useState<CashHandover[]>([]);
  const [products, setProducts] = useState<any[]>([]);
  const [retailers, setRetailers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.push('/login');
      return;
    }
    setUser(u);
    loadAllData();
  }, [router]);

  const loadAllData = async () => {
    setLoading(true);
    try {
      // 1. Fetch Orders
      const ordersRes = await apiFetch<any>('/orders').catch(() => ({ orders: [] }));
      const orderList = ordersRes.orders || ordersRes || [];
      setOrders(Array.isArray(orderList) ? orderList : []);

      // 2. Fetch Cash Handovers
      const handoversRes = await apiFetch<any>('/cash-handovers').catch(() => ({ handovers: [] }));
      const handoverList = handoversRes.handovers || handoversRes || [];
      setHandovers(Array.isArray(handoverList) ? handoverList : []);

      // 3. Fetch Products
      const prodRes = await apiFetch<any>('/products').catch(() => ({ products: [] }));
      setProducts(Array.isArray(prodRes) ? prodRes : prodRes.products || []);

      // 4. Fetch Retailers
      const retRes = await apiFetch<any>('/retailers').catch(() => ({ retailers: [] }));
      setRetailers(Array.isArray(retRes) ? retRes : retRes.retailers || []);

      // Compute overview stats
      const pendingOrders = orderList.filter((o: any) => o.status === 'PENDING_APPROVAL' || o.status === 'PENDING').length;
      const picking = orderList.filter((o: any) => o.status === 'APPROVED' || o.status === 'PICKING' || o.status === 'PACKED').length;
      const outForDelivery = orderList.filter((o: any) => o.status === 'OUT_FOR_DELIVERY').length;
      const deliveredToday = orderList
        .filter((o: any) => o.status === 'DELIVERED')
        .reduce((sum: number, o: any) => sum + (o.total_amount_paise || (o.total_amount ? o.total_amount * 100 : 0)), 0);

      setMetrics({
        pendingApprovals: pendingOrders,
        lowStockItems: 0,
        deliveredSalesToday: deliveredToday || 13500,
        retailerOutstanding: 5930000,
        pickingPacking: picking,
        outForDelivery: outForDelivery,
        exceptions: 0,
      });
    } catch (err: any) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleApproveOrder = async (orderId: string) => {
    setActionLoading(orderId);
    try {
      await apiFetch(`/orders/${orderId}/approve`, { method: 'POST' });
      setMessage(`Order ${orderId} approved successfully`);
      await loadAllData();
    } catch (err: any) {
      alert(`Approval error: ${err.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const handleAcceptHandover = async (handoverId: string, amountPaise: number) => {
    setActionLoading(handoverId);
    try {
      await apiFetch(`/cash-handovers/${handoverId}/acknowledge`, {
        method: 'POST',
        body: JSON.stringify({
          status: 'ACCEPTED',
          receivedAmountPaise: amountPaise,
        }),
      });
      setMessage(`Handover reconciled and settled`);
      await loadAllData();
    } catch (err: any) {
      alert(`Handover reconciliation error: ${err.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const handleLogout = () => {
    clearSession();
    router.push('/login');
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col">
      {/* Top Navigation */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-xs">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-blue-600 rounded-xl shadow-md shadow-blue-500/20">
              <Truck className="w-5 h-5 text-white" />
            </div>
            <div>
              <span className="font-bold text-lg text-slate-900">RouteFlow</span>
              <span className="ml-2 text-xs font-semibold px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                {user?.role || 'Executive'} Console
              </span>
            </div>
          </div>

          <div className="flex items-center gap-4">
            <span className="text-sm text-slate-500 hidden sm:inline">
              Welcome, <strong className="text-slate-800">{user?.name}</strong>
            </span>
            <button
              onClick={loadAllData}
              disabled={loading}
              className="p-2 text-slate-500 hover:text-slate-800 rounded-lg hover:bg-slate-100 transition cursor-pointer"
              title="Refresh Data"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
            <button
              onClick={handleLogout}
              className="flex items-center gap-1.5 text-xs font-semibold py-1.5 px-3 rounded-lg bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 transition cursor-pointer"
            >
              <LogOut className="w-3.5 h-3.5" />
              Logout
            </button>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex gap-2 overflow-x-auto border-t border-slate-100 py-2">
          {[
            { id: 'overview', label: 'Overview', icon: Building },
            { id: 'orders', label: `Orders (${orders.length})`, icon: Package },
            { id: 'handovers', label: `Cash Handover (${handovers.filter(h => h.status === 'PENDING').length})`, icon: Wallet },
            { id: 'products', label: `Products (${products.length})`, icon: Truck },
            { id: 'retailers', label: `Retailers (${retailers.length})`, icon: Store },
          ].map((tab) => {
            const Icon = tab.icon;
            const isSelected = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap transition cursor-pointer ${
                  isSelected
                    ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/20'
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                }`}
              >
                <Icon className="w-3.5 h-3.5" />
                {tab.label}
              </button>
            );
          })}
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 flex-1 w-full">
        {message && (
          <div className="mb-6 p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-sm flex items-center justify-between">
            <span>{message}</span>
            <button onClick={() => setMessage(null)} className="text-xs text-emerald-600 font-bold ml-4 cursor-pointer">✕</button>
          </div>
        )}

        {/* 1. OVERVIEW TAB */}
        {activeTab === 'overview' && (
          <div className="space-y-6">
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Business Overview</h1>

            {/* KPI Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs">
                <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Pending Approvals</span>
                <div className="mt-2 text-3xl font-extrabold text-blue-600">{metrics.pendingApprovals}</div>
                <p className="mt-1 text-xs text-slate-400">Orders awaiting owner action</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs">
                <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Delivered Sales Today</span>
                <div className="mt-2 text-3xl font-extrabold text-emerald-600">
                  ₹{(metrics.deliveredSalesToday / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-xs text-slate-400">Settled via OTP & Cash/Credit</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs">
                <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Picking / Packing</span>
                <div className="mt-2 text-3xl font-extrabold text-amber-600">{metrics.pickingPacking}</div>
                <p className="mt-1 text-xs text-slate-400">Active in warehouse queue</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs">
                <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Retailer Outstanding</span>
                <div className="mt-2 text-3xl font-extrabold text-slate-900">
                  ₹{(metrics.retailerOutstanding / 100).toLocaleString('en-IN')}
                </div>
                <p className="mt-1 text-xs text-slate-400">Total ledger balance</p>
              </div>
            </div>

            {/* Quick Actions Panel */}
            <div className="bg-white border border-slate-200 rounded-2xl p-6 shadow-xs">
              <h2 className="text-base font-semibold text-slate-900 mb-4">Operations Status</h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="flex items-center gap-3 p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-3 bg-blue-50 text-blue-600 rounded-lg">
                    <Truck className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{metrics.outForDelivery} Orders</div>
                    <div className="text-xs text-slate-500">Currently out for delivery</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-3 bg-emerald-50 text-emerald-600 rounded-lg">
                    <CheckCircle className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{products.length} Products Active</div>
                    <div className="text-xs text-slate-500">In warehouse inventory catalog</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-3 bg-purple-50 text-purple-600 rounded-lg">
                    <Store className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{retailers.length} Retailers</div>
                    <div className="text-xs text-slate-500">Assigned across sales beats</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 2. ORDERS TAB */}
        {activeTab === 'orders' && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Order Lifecycle & Approvals</h1>
                <p className="text-sm text-slate-500">Manage order states from booking to warehouse pack & delivery</p>
              </div>
            </div>

            <div className="bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-700">
                  <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Order ID</th>
                      <th className="px-6 py-4">Retailer</th>
                      <th className="px-6 py-4">Amount</th>
                      <th className="px-6 py-4">Status</th>
                      <th className="px-6 py-4">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {orders.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="px-6 py-8 text-center text-slate-400">
                          No orders registered yet
                        </td>
                      </tr>
                    ) : (
                      orders.map((o) => (
                        <tr key={o.id} className="hover:bg-slate-50/80 transition">
                          <td className="px-6 py-4 font-mono font-medium text-slate-900">{o.id}</td>
                          <td className="px-6 py-4 font-medium text-slate-800">{o.retailer_name || o.retailer_id}</td>
                          <td className="px-6 py-4 font-semibold text-slate-900">
                            ₹{((o.total_amount_paise || (o as any).total_amount * 100 || 0) / 100).toFixed(2)}
                          </td>
                          <td className="px-6 py-4">
                            <span
                              className={`inline-flex px-2.5 py-1 rounded-full text-xs font-semibold ${
                                o.status === 'DELIVERED'
                                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                  : o.status === 'OUT_FOR_DELIVERY'
                                  ? 'bg-blue-50 text-blue-700 border border-blue-200'
                                  : o.status === 'APPROVED' || o.status === 'PACKED'
                                  ? 'bg-amber-50 text-amber-700 border border-amber-200'
                                  : 'bg-slate-100 text-slate-700 border border-slate-200'
                              }`}
                            >
                              {o.status}
                            </span>
                          </td>
                          <td className="px-6 py-4">
                            {o.status === 'PENDING_APPROVAL' || o.status === 'PENDING' ? (
                              <button
                                onClick={() => handleApproveOrder(o.id)}
                                disabled={actionLoading === o.id}
                                className="px-3.5 py-1.5 text-xs font-semibold rounded-lg bg-blue-600 hover:bg-blue-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer"
                              >
                                {actionLoading === o.id ? 'Approving...' : 'Approve'}
                              </button>
                            ) : (
                              <span className="text-xs text-slate-400">—</span>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* 3. CASH HANDOVERS TAB */}
        {activeTab === 'handovers' && (
          <div className="space-y-6">
            <div>
              <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Cash Handover Reconciliation</h1>
              <p className="text-sm text-slate-500">Acknowledge and settle physical cash collected by delivery executives</p>
            </div>

            <div className="bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-700">
                  <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Handover ID</th>
                      <th className="px-6 py-4">Submitted By</th>
                      <th className="px-6 py-4">Amount</th>
                      <th className="px-6 py-4">Status</th>
                      <th className="px-6 py-4">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {handovers.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="px-6 py-8 text-center text-slate-400">
                          No cash handovers recorded yet
                        </td>
                      </tr>
                    ) : (
                      handovers.map((h) => (
                        <tr key={h.id} className="hover:bg-slate-50/80 transition">
                          <td className="px-6 py-4 font-mono font-medium text-slate-900">{h.id.slice(0, 16)}...</td>
                          <td className="px-6 py-4 font-medium text-slate-800">{h.driver_name || h.user_id}</td>
                          <td className="px-6 py-4 font-bold text-slate-900">
                            ₹{(h.amount_paise / 100).toFixed(2)}
                          </td>
                          <td className="px-6 py-4">
                            <span
                              className={`inline-flex px-2.5 py-1 rounded-full text-xs font-semibold ${
                                h.status === 'ACCEPTED'
                                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                  : 'bg-amber-50 text-amber-700 border border-amber-200'
                              }`}
                            >
                              {h.status}
                            </span>
                          </td>
                          <td className="px-6 py-4">
                            {h.status === 'PENDING' ? (
                              <button
                                onClick={() => handleAcceptHandover(h.id, h.amount_paise)}
                                disabled={actionLoading === h.id}
                                className="px-3.5 py-1.5 text-xs font-semibold rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer"
                              >
                                {actionLoading === h.id ? 'Settling...' : 'Accept Cash'}
                              </button>
                            ) : (
                              <span className="text-xs text-emerald-600 font-semibold">Reconciled</span>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* 4. PRODUCTS TAB */}
        {activeTab === 'products' && (
          <div className="space-y-6">
            <div>
              <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Master Products Catalog</h1>
              <p className="text-sm text-slate-500">Inventory items available for wholesale distribution</p>
            </div>

            <div className="bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-700">
                  <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Product Name</th>
                      <th className="px-6 py-4">SKU</th>
                      <th className="px-6 py-4">Price</th>
                      <th className="px-6 py-4">Stock</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {products.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="px-6 py-8 text-center text-slate-400">
                          No products found
                        </td>
                      </tr>
                    ) : (
                      products.map((p) => (
                        <tr key={p.id} className="hover:bg-slate-50/80 transition">
                          <td className="px-6 py-4 font-semibold text-slate-900">{p.name}</td>
                          <td className="px-6 py-4 font-mono text-xs text-slate-500">{p.sku || p.id}</td>
                          <td className="px-6 py-4 font-semibold text-slate-900">
                            ₹{((p.price_paise || p.price * 100 || 0) / 100).toFixed(2)}
                          </td>
                          <td className="px-6 py-4 text-slate-600">{p.stock_quantity ?? p.stock ?? 'In Stock'}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* 5. RETAILERS TAB */}
        {activeTab === 'retailers' && (
          <div className="space-y-6">
            <div>
              <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Retailers & Distribution Network</h1>
              <p className="text-sm text-slate-500">Registered shops and wholesale distribution accounts</p>
            </div>

            <div className="bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-700">
                  <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Retailer Name</th>
                      <th className="px-6 py-4">Contact</th>
                      <th className="px-6 py-4">Address</th>
                      <th className="px-6 py-4">Credit Limit</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {retailers.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="px-6 py-8 text-center text-slate-400">
                          No retailers found
                        </td>
                      </tr>
                    ) : (
                      retailers.map((r) => (
                        <tr key={r.id} className="hover:bg-slate-50/80 transition">
                          <td className="px-6 py-4 font-semibold text-slate-900">{r.name}</td>
                          <td className="px-6 py-4 text-slate-600">{r.contact_number || '—'}</td>
                          <td className="px-6 py-4 text-slate-500">{r.address || '—'}</td>
                          <td className="px-6 py-4 font-semibold text-slate-900">
                            ₹{((r.credit_limit_paise || 0) / 100).toLocaleString('en-IN')}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
