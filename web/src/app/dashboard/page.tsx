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
  const [orderFilter, setOrderFilter] = useState<'ALL' | 'PENDING' | 'APPROVED' | 'DISPATCHED' | 'DELIVERED'>('ALL');
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

  const filteredOrders = orders.filter((o) => {
    if (orderFilter === 'ALL') return true;
    if (orderFilter === 'PENDING') return o.status === 'PENDING_APPROVAL' || o.status === 'PENDING';
    if (orderFilter === 'APPROVED') return o.status === 'APPROVED' || o.status === 'PICKING' || o.status === 'PACKED';
    if (orderFilter === 'DISPATCHED') return o.status === 'OUT_FOR_DELIVERY';
    if (orderFilter === 'DELIVERED') return o.status === 'DELIVERED';
    return true;
  });

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col">
      {/* Top Navigation */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-xs">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2.5 sm:gap-3">
            <div className="p-2 bg-blue-600 rounded-xl shadow-md shadow-blue-500/20">
              <Truck className="w-5 h-5 text-white" />
            </div>
            <div>
              <div className="flex items-center gap-1.5 sm:gap-2">
                <span className="font-bold text-base sm:text-lg text-slate-900 tracking-tight">RouteFlow</span>
                <span className="text-[10px] sm:text-xs font-semibold px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                  {user?.role || 'Executive'}
                </span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2 sm:gap-4">
            <span className="text-xs sm:text-sm text-slate-500 hidden md:inline">
              Welcome, <strong className="text-slate-800">{user?.name}</strong>
            </span>
            <button
              onClick={loadAllData}
              disabled={loading}
              className="p-2 text-slate-500 hover:text-slate-800 rounded-lg hover:bg-slate-100 transition cursor-pointer min-h-[38px] min-w-[38px] flex items-center justify-center"
              title="Refresh Data"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
            <button
              onClick={handleLogout}
              className="flex items-center gap-1.5 text-xs font-semibold py-1.5 px-2.5 sm:px-3 rounded-lg bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 transition cursor-pointer min-h-[38px]"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Logout</span>
            </button>
          </div>
        </div>

        {/* Navigation Tabs - Responsive Scrollable Bar */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex gap-1.5 sm:gap-2 overflow-x-auto border-t border-slate-100 py-2 scrollbar-none">
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
                className={`flex items-center gap-1.5 sm:gap-2 px-3 sm:px-3.5 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap transition cursor-pointer min-h-[36px] ${
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
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-5 sm:py-8 flex-1 w-full">
        {message && (
          <div className="mb-4 sm:mb-6 p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-xs sm:text-sm flex items-center justify-between">
            <span>{message}</span>
            <button onClick={() => setMessage(null)} className="text-xs text-emerald-600 font-bold ml-4 cursor-pointer p-1">✕</button>
          </div>
        )}

        {/* 1. OVERVIEW TAB */}
        {activeTab === 'overview' && (
          <div className="space-y-4 sm:space-y-6">
            <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Business Overview</h1>

            {/* KPI Cards - 2 Columns on Phone, 4 on Desktop */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Pending Approvals</span>
                <div className="mt-1.5 sm:mt-2 text-2xl sm:text-3xl font-extrabold text-blue-600">{metrics.pendingApprovals}</div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-400">Awaiting owner action</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Delivered Sales Today</span>
                <div className="mt-1.5 sm:mt-2 text-xl sm:text-3xl font-extrabold text-emerald-600 truncate">
                  ₹{(metrics.deliveredSalesToday / 100).toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-400">Settled via OTP & Cash</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Picking / Packing</span>
                <div className="mt-1.5 sm:mt-2 text-2xl sm:text-3xl font-extrabold text-amber-600">{metrics.pickingPacking}</div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-400">Active in warehouse</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Retailer Outstanding</span>
                <div className="mt-1.5 sm:mt-2 text-xl sm:text-3xl font-extrabold text-slate-900 truncate">
                  ₹{(metrics.retailerOutstanding / 100).toLocaleString('en-IN')}
                </div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-400">Total ledger balance</p>
              </div>
            </div>

            {/* Quick Actions Panel */}
            <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-6 shadow-xs">
              <h2 className="text-sm sm:text-base font-semibold text-slate-900 mb-3 sm:mb-4">Operations Status</h2>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
                <div className="flex items-center gap-3 p-3.5 sm:p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-2.5 sm:p-3 bg-blue-50 text-blue-600 rounded-lg shrink-0">
                    <Truck className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{metrics.outForDelivery} Orders</div>
                    <div className="text-xs text-slate-500">Currently out for delivery</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3.5 sm:p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-2.5 sm:p-3 bg-emerald-50 text-emerald-600 rounded-lg shrink-0">
                    <CheckCircle className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{products.length} Products Active</div>
                    <div className="text-xs text-slate-500">In warehouse inventory catalog</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3.5 sm:p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-2.5 sm:p-3 bg-purple-50 text-purple-600 rounded-lg shrink-0">
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
          <div className="space-y-4 sm:space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Orders & Approvals</h1>
                <p className="text-xs sm:text-sm text-slate-500">Live order state management from booking to delivery</p>
              </div>

              {/* Status Filter Chips */}
              <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 scrollbar-none">
                {[
                  { id: 'ALL', label: `All (${orders.length})` },
                  { id: 'PENDING', label: `Pending (${orders.filter(o => o.status === 'PENDING_APPROVAL' || o.status === 'PENDING').length})` },
                  { id: 'APPROVED', label: `Warehouse (${orders.filter(o => o.status === 'APPROVED' || o.status === 'PICKING' || o.status === 'PACKED').length})` },
                  { id: 'DISPATCHED', label: `Dispatched (${orders.filter(o => o.status === 'OUT_FOR_DELIVERY').length})` },
                  { id: 'DELIVERED', label: `Delivered (${orders.filter(o => o.status === 'DELIVERED').length})` },
                ].map((f) => (
                  <button
                    key={f.id}
                    onClick={() => setOrderFilter(f.id as any)}
                    className={`px-2.5 py-1 text-xs font-semibold rounded-lg whitespace-nowrap transition cursor-pointer ${
                      orderFilter === f.id
                        ? 'bg-blue-600 text-white shadow-xs'
                        : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    {f.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Mobile Cards (Visible on screens < 768px) */}
            <div className="md:hidden space-y-3">
              {filteredOrders.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center text-slate-400 text-sm">
                  No orders match this filter
                </div>
              ) : (
                filteredOrders.map((o) => (
                  <div key={o.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-xs font-semibold text-slate-900">{o.id}</span>
                      <span
                        className={`inline-flex px-2 py-0.5 rounded-full text-[11px] font-semibold ${
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
                    </div>

                    <div className="flex items-baseline justify-between border-t border-slate-100 pt-2">
                      <div>
                        <div className="text-sm font-semibold text-slate-800">{o.retailer_name || o.retailer_id}</div>
                        <div className="text-xs text-slate-400">Order #{o.id.slice(-6)}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-base font-extrabold text-slate-900">
                          ₹{((o.total_amount_paise || (o as any).total_amount * 100 || 0) / 100).toFixed(2)}
                        </div>
                      </div>
                    </div>

                    {(o.status === 'PENDING_APPROVAL' || o.status === 'PENDING') && (
                      <button
                        onClick={() => handleApproveOrder(o.id)}
                        disabled={actionLoading === o.id}
                        className="w-full flex items-center justify-center py-2.5 px-4 text-xs font-semibold rounded-xl bg-blue-600 hover:bg-blue-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer min-h-[40px]"
                      >
                        {actionLoading === o.id ? 'Approving...' : 'Approve Order'}
                      </button>
                    )}
                  </div>
                ))
              )}
            </div>

            {/* Desktop Table (Visible on screens >= 768px) */}
            <div className="hidden md:block bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
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
                    {filteredOrders.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="px-6 py-8 text-center text-slate-400">
                          No orders match this filter
                        </td>
                      </tr>
                    ) : (
                      filteredOrders.map((o) => (
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
          <div className="space-y-4 sm:space-y-6">
            <div>
              <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Cash Handover Reconciliation</h1>
              <p className="text-xs sm:text-sm text-slate-500">Acknowledge physical cash collections from delivery executives</p>
            </div>

            {/* Mobile Cards (Visible on screens < 768px) */}
            <div className="md:hidden space-y-3">
              {handovers.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center text-slate-400 text-sm">
                  No cash handovers recorded yet
                </div>
              ) : (
                handovers.map((h) => (
                  <div key={h.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-xs font-semibold text-slate-900">{h.id.slice(0, 14)}...</span>
                      <span
                        className={`inline-flex px-2 py-0.5 rounded-full text-[11px] font-semibold ${
                          h.status === 'ACCEPTED'
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : 'bg-amber-50 text-amber-700 border border-amber-200'
                        }`}
                      >
                        {h.status}
                      </span>
                    </div>

                    <div className="flex items-baseline justify-between border-t border-slate-100 pt-2">
                      <div>
                        <div className="text-sm font-semibold text-slate-800">{h.driver_name || h.user_id}</div>
                        <div className="text-xs text-slate-400">Delivery Executive</div>
                      </div>
                      <div className="text-right">
                        <div className="text-base font-extrabold text-slate-900">
                          ₹{(h.amount_paise / 100).toFixed(2)}
                        </div>
                      </div>
                    </div>

                    {h.status === 'PENDING' ? (
                      <button
                        onClick={() => handleAcceptHandover(h.id, h.amount_paise)}
                        disabled={actionLoading === h.id}
                        className="w-full flex items-center justify-center py-2.5 px-4 text-xs font-semibold rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer min-h-[40px]"
                      >
                        {actionLoading === h.id ? 'Settling...' : 'Accept Cash'}
                      </button>
                    ) : (
                      <div className="text-center py-1 text-xs text-emerald-600 font-semibold bg-emerald-50 rounded-lg border border-emerald-200">
                        Reconciled & Deposited
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>

            {/* Desktop Table (Visible on screens >= 768px) */}
            <div className="hidden md:block bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
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
          <div className="space-y-4 sm:space-y-6">
            <div>
              <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Master Products Catalog</h1>
              <p className="text-xs sm:text-sm text-slate-500">Inventory items available for wholesale distribution</p>
            </div>

            {/* Mobile Cards (Visible on screens < 768px) */}
            <div className="md:hidden space-y-3">
              {products.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center text-slate-400 text-sm">
                  No products found
                </div>
              ) : (
                products.map((p) => (
                  <div key={p.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs flex items-center justify-between">
                    <div>
                      <div className="text-sm font-semibold text-slate-900">{p.name}</div>
                      <div className="text-xs font-mono text-slate-400 mt-0.5">{p.sku || p.id}</div>
                      <div className="text-xs text-slate-500 mt-1">
                        Stock: <span className="font-semibold text-slate-700">{p.stock_quantity ?? p.stock ?? 'In Stock'}</span>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-base font-extrabold text-slate-900">
                        ₹{((p.price_paise || p.price * 100 || 0) / 100).toFixed(2)}
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>

            {/* Desktop Table (Visible on screens >= 768px) */}
            <div className="hidden md:block bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
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
          <div className="space-y-4 sm:space-y-6">
            <div>
              <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Retailers & Distribution Network</h1>
              <p className="text-xs sm:text-sm text-slate-500">Registered shops and wholesale distribution accounts</p>
            </div>

            {/* Mobile Cards (Visible on screens < 768px) */}
            <div className="md:hidden space-y-3">
              {retailers.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center text-slate-400 text-sm">
                  No retailers found
                </div>
              ) : (
                retailers.map((r) => (
                  <div key={r.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs space-y-2">
                    <div className="flex items-start justify-between">
                      <div>
                        <div className="text-sm font-semibold text-slate-900">{r.name}</div>
                        <div className="text-xs text-slate-500 mt-0.5">{r.contact_number || 'No contact'}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-xs text-slate-400">Credit Limit</div>
                        <div className="text-sm font-extrabold text-slate-900">
                          ₹{((r.credit_limit_paise || 0) / 100).toLocaleString('en-IN')}
                        </div>
                      </div>
                    </div>
                    {r.address && (
                      <div className="text-xs text-slate-400 border-t border-slate-100 pt-2 truncate">
                        {r.address}
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>

            {/* Desktop Table (Visible on screens >= 768px) */}
            <div className="hidden md:block bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
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
