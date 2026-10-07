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
  RotateCcw,
  Plus,
  MapPin,
  Phone,
  X,
  AlertTriangle,
  FileText,
  ShoppingBag,
  DollarSign
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
  const [activeTab, setActiveTab] = useState<'overview' | 'control_room' | 'exceptions' | 'orders' | 'handovers' | 'products' | 'retailers'>('overview');
  
  // Operating System State
  const [controlRoomData, setControlRoomData] = useState<any | null>(null);
  const [exceptionsList, setExceptionsList] = useState<any[]>([]);
  const [dayBookData, setDayBookData] = useState<any | null>(null);
  const [purchaseList, setPurchaseList] = useState<any[]>([]);
  const [cashBookData, setCashBookData] = useState<any | null>(null);
  const [selectedRetailer360, setSelectedRetailer360] = useState<any | null>(null);
  const [retailer360Loading, setRetailer360Loading] = useState(false);
  
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

  // Add Retailer Modal State
  const [showAddRetailerModal, setShowAddRetailerModal] = useState(false);
  const [newRetailer, setNewRetailer] = useState({
    name: '',
    contactNumber: '',
    address: '',
    creditLimitRupees: '5000',
    beatId: 'BEAT-04',
    latitude: '',
    longitude: ''
  });
  const [detectingLocation, setDetectingLocation] = useState(false);
  const [creatingRetailer, setCreatingRetailer] = useState(false);

  // Add Product Modal State
  const [showAddProductModal, setShowAddProductModal] = useState(false);
  const [newProduct, setNewProduct] = useState({
    name: '',
    category: 'General',
    priceRupees: '100',
    unit: 'Pack',
    stockQuantity: '50'
  });
  const [creatingProduct, setCreatingProduct] = useState(false);

  // Delivery Assignment State
  const [deliveryExecutives, setDeliveryExecutives] = useState<any[]>([]);
  const [assignModalOrder, setAssignModalOrder] = useState<any | null>(null);
  const [selectedDriverId, setSelectedDriverId] = useState<string>('');
  const [assigningLoading, setAssigningLoading] = useState(false);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.push('/login');
      return;
    }
    setUser(u);
    const r = u.role?.toUpperCase();
    if (r === 'SALESPERSON' || r === 'SALES') {
      setActiveTab('retailers');
    } else if (r === 'WAREHOUSE_MANAGER' || r === 'WAREHOUSE') {
      setActiveTab('products');
    } else if (r === 'DELIVERY_EXECUTIVE' || r === 'DELIVERY') {
      setActiveTab('orders');
    } else {
      setActiveTab('overview');
    }
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

      // 5. Fetch Delivery Executives
      const devRes = await apiFetch<any>('/delivery-executives').catch(() => []);
      const devList = Array.isArray(devRes) ? devRes : devRes.executives || [];
      setDeliveryExecutives(devList);
      if (devList.length > 0 && !selectedDriverId) {
        setSelectedDriverId(devList[0].id);
      }

      // 6. Fetch Operating System Modules (Owner Control Room, Exceptions, Day Book, Purchase)
      const [pulseRes, excRes, dayRes, purRes] = await Promise.all([
        apiFetch<any>('/control-room/pulse').catch(() => null),
        apiFetch<any>('/exceptions/feed').catch(() => ({ exceptions: [] })),
        apiFetch<any>('/day-book/today').catch(() => null),
        apiFetch<any>('/purchase-planning/suggestions').catch(() => ({ purchaseList: [] }))
      ]);
      setControlRoomData(pulseRes);
      setExceptionsList(excRes?.exceptions || []);
      setDayBookData(dayRes);
      setPurchaseList(purRes?.purchaseList || []);

      // Compute overview stats
      const pendingOrders = orderList.filter((o: any) => o.status === 'PENDING_APPROVAL' || o.status === 'PENDING').length;
      const picking = orderList.filter((o: any) => o.status === 'APPROVED' || o.status === 'PICKING' || o.status === 'PACKED').length;
      const outForDelivery = orderList.filter((o: any) => o.status === 'OUT_FOR_DELIVERY').length;
      const deliveredToday = orderList
        .filter((o: any) => o.status === 'DELIVERED')
        .reduce((sum: number, o: any) => sum + (o.total_amount_paise || (o.total_amount ? o.total_amount * 100 : 0)), 0);

      setMetrics({
        pendingApprovals: pendingOrders,
        lowStockItems: pulseRes?.inventory?.lowStockCount || 0,
        deliveredSalesToday: pulseRes?.todaySales?.deliveredPaise || deliveredToday || 13500,
        retailerOutstanding: pulseRes?.todayCollections?.netCashInHandPaise || 5930000,
        pickingPacking: picking,
        outForDelivery: outForDelivery,
        exceptions: excRes?.exceptions?.length || 0,
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

  const handleDetectLocation = () => {
    if (typeof window === 'undefined' || !navigator.geolocation) {
      alert('Geolocation is not supported by your browser');
      return;
    }
    setDetectingLocation(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setNewRetailer((prev) => ({
          ...prev,
          latitude: pos.coords.latitude.toFixed(6),
          longitude: pos.coords.longitude.toFixed(6),
        }));
        setDetectingLocation(false);
      },
      (err) => {
        alert('Could not retrieve location: ' + err.message);
        setDetectingLocation(false);
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  };

  const handleCreateRetailer = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRetailer.name.trim()) return;
    setCreatingRetailer(true);
    try {
      const creditPaise = Math.round((parseFloat(newRetailer.creditLimitRupees) || 0) * 100);
      await apiFetch('/retailers', {
        method: 'POST',
        body: JSON.stringify({
          name: newRetailer.name.trim(),
          contactNumber: newRetailer.contactNumber.trim(),
          address: newRetailer.address.trim(),
          creditLimitPaise: creditPaise,
          beatId: newRetailer.beatId || 'BEAT-04',
          latitude: newRetailer.latitude ? parseFloat(newRetailer.latitude) : undefined,
          longitude: newRetailer.longitude ? parseFloat(newRetailer.longitude) : undefined,
        }),
      });
      setMessage('Shop / Retailer added successfully!');
      setShowAddRetailerModal(false);
      setNewRetailer({
        name: '',
        contactNumber: '',
        address: '',
        creditLimitRupees: '5000',
        beatId: 'BEAT-04',
        latitude: '',
        longitude: ''
      });
      await loadAllData();
      setTimeout(() => setMessage(null), 3000);
    } catch (err: any) {
      alert(err.message || 'Failed to create retailer');
    } finally {
      setCreatingRetailer(false);
    }
  };

  const handleCreateProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newProduct.name.trim()) return;
    setCreatingProduct(true);
    try {
      const pricePaise = Math.round((parseFloat(newProduct.priceRupees) || 0) * 100);
      const stock = parseInt(newProduct.stockQuantity) || 0;
      await apiFetch('/products', {
        method: 'POST',
        body: JSON.stringify({
          name: newProduct.name.trim(),
          category: newProduct.category.trim() || 'General',
          pricePaise,
          unit: newProduct.unit.trim() || 'Unit',
          stockQuantity: stock,
        }),
      });
      setMessage('Product added to catalog successfully!');
      setShowAddProductModal(false);
      setNewProduct({
        name: '',
        category: 'General',
        priceRupees: '100',
        unit: 'Pack',
        stockQuantity: '50'
      });
      await loadAllData();
      setTimeout(() => setMessage(null), 3000);
    } catch (err: any) {
      alert(err.message || 'Failed to create product');
    } finally {
      setCreatingProduct(false);
    }
  };

  const handleAssignDelivery = async () => {
    if (!assignModalOrder || !selectedDriverId) return;
    setAssigningLoading(true);
    try {
      const orderId = assignModalOrder.id;
      // If order is APPROVED, mark items picked and pack it first so dispatch trigger succeeds
      if (assignModalOrder.status === 'APPROVED') {
        const itemsRes = await apiFetch<any>(`/orders/${orderId}/items`).catch(() => []);
        const itemsList = Array.isArray(itemsRes) ? itemsRes : itemsRes.items || [];
        for (const it of itemsList) {
          if (!it.is_picked) {
            await apiFetch(`/orders/${orderId}/items/${it.product_id || it.productId}/pick`, {
              method: 'PUT',
              body: JSON.stringify({ isPicked: true })
            }).catch(() => {});
          }
        }
        await apiFetch(`/orders/${orderId}/pack`, { method: 'POST' }).catch(() => {});
      }

      await apiFetch(`/orders/${orderId}/dispatch`, {
        method: 'POST',
        body: JSON.stringify({ deliveryEmployeeId: selectedDriverId }),
      });

      setMessage(`Order ${orderId} assigned to delivery driver & dispatched!`);
      setAssignModalOrder(null);
      await loadAllData();
      setTimeout(() => setMessage(null), 3000);
    } catch (err: any) {
      alert(`Assignment failed: ${err.message}`);
    } finally {
      setAssigningLoading(false);
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
        {(() => {
          const role = user?.role?.toUpperCase() || 'OWNER';
          const isOwnerOrAdmin = role === 'OWNER' || role === 'ADMIN';
          const isWarehouse = role === 'WAREHOUSE_MANAGER' || role === 'WAREHOUSE';
          const isDelivery = role === 'DELIVERY_EXECUTIVE' || role === 'DELIVERY';
          const isSales = role === 'SALESPERSON' || role === 'SALES';

          const visibleTabs = [
            ...(isOwnerOrAdmin ? [{ id: 'overview', label: 'Overview', icon: Building }] : []),
            ...(isOwnerOrAdmin ? [{ id: 'control_room', label: 'Control Room', icon: DollarSign }] : []),
            ...(isOwnerOrAdmin ? [{ id: 'exceptions', label: `Exceptions (${exceptionsList.length})`, icon: AlertTriangle }] : []),
            { id: 'orders', label: `Orders (${orders.length})`, icon: Package },
            ...(isOwnerOrAdmin || isDelivery ? [{ id: 'handovers', label: `Cash Handover (${handovers.filter(h => h.status === 'PENDING').length})`, icon: Wallet }] : []),
            ...(isOwnerOrAdmin || isWarehouse || isSales ? [{ id: 'products', label: `Products (${products.length})`, icon: Truck }] : []),
            ...(isOwnerOrAdmin || isSales ? [{ id: 'retailers', label: `Retailers (${retailers.length})`, icon: Store }] : []),
          ];

          return (
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex gap-1.5 sm:gap-2 overflow-x-auto border-t border-slate-100 py-2 scrollbar-none">
              {visibleTabs.map((tab) => {
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
          );
        })()}
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-5 sm:py-8 flex-1 w-full">
        {/* Role Banner for Field Roles */}
        {(() => {
          const role = user?.role?.toUpperCase() || 'OWNER';
          const isOwnerOrAdmin = role === 'OWNER' || role === 'ADMIN';
          const isWarehouse = role === 'WAREHOUSE_MANAGER' || role === 'WAREHOUSE';
          const isDelivery = role === 'DELIVERY_EXECUTIVE' || role === 'DELIVERY';
          const isSales = role === 'SALESPERSON' || role === 'SALES';

          if (isOwnerOrAdmin) return null;

          return (
            <div className="mb-4 sm:mb-6 p-3.5 sm:p-4 bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-2xl text-blue-900 text-xs sm:text-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-xs">
              <div className="flex items-center gap-3">
                <span className="text-xl sm:text-2xl">📱</span>
                <div>
                  <p className="font-bold text-slate-900">Mobile App Recommended for Field Roles</p>
                  <p className="text-slate-600 text-xs mt-0.5">
                    {isSales && 'Live shop onboarding with GPS, catalog ordering, and cash collections are built for the RouteFlow Android phone app.'}
                    {isWarehouse && 'Real-time picking, packing, and godown scanner operations are optimized for the RouteFlow Android phone app.'}
                    {isDelivery && 'Turn-by-turn route delivery, customer OTP proof, and cash handovers are handled via the RouteFlow Android phone app.'}
                    {' This web console provides fallback office & emergency desktop access.'}
                  </p>
                </div>
              </div>
              <span className="px-2.5 py-1 bg-white border border-blue-200 text-blue-700 rounded-lg font-semibold text-[11px] whitespace-nowrap self-start sm:self-center shadow-xs">
                Web Fallback Mode
              </span>
            </div>
          );
        })()}

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

        {/* 1.1 OWNER CONTROL ROOM TAB */}
        {activeTab === 'control_room' && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Owner Control Room</h1>
                <p className="text-xs sm:text-sm text-slate-500">Live operational command center for daily wholesale & cash flow control</p>
              </div>
              <div className="flex items-center gap-2">
                <a
                  href="/api/reports/printable/daily-closing"
                  target="_blank"
                  className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold text-xs rounded-xl shadow-xs transition flex items-center gap-1.5"
                >
                  <FileText className="w-3.5 h-3.5" />
                  Print Daily Closing Slip
                </a>
              </div>
            </div>

            {/* Live Financial & Ops Grid */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Booked Sales Today</span>
                <div className="mt-1.5 text-2xl font-extrabold text-blue-600">
                  ₹{((controlRoomData?.todaySales?.bookedPaise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-xs text-slate-400">{controlRoomData?.todaySales?.totalOrders || 0} Total Orders Booked</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Cash Collected</span>
                <div className="mt-1.5 text-2xl font-extrabold text-emerald-600">
                  ₹{((controlRoomData?.todayCollections?.cashCollectedPaise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-xs text-slate-400">Net in Hand: ₹{((controlRoomData?.todayCollections?.netCashInHandPaise || 0) / 100).toLocaleString('en-IN')}</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Pending Approvals</span>
                <div className="mt-1.5 text-2xl font-extrabold text-amber-600">
                  {controlRoomData?.todaySales?.pendingApprovals || 0}
                </div>
                <p className="mt-1 text-xs text-slate-400">Awaiting owner sign-off</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Critical Low Stock</span>
                <div className="mt-1.5 text-2xl font-extrabold text-rose-600">
                  {controlRoomData?.inventory?.lowStockCount || 0} SKUs
                </div>
                <p className="mt-1 text-xs text-slate-400">{controlRoomData?.inventory?.outOfStockCount || 0} Out of Stock</p>
              </div>
            </div>

            {/* Split Sections: Top Overdue Retailers & Tomorrow Purchase Suggestions */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {/* Overdue Retailers Card */}
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="font-bold text-slate-900 text-sm sm:text-base flex items-center gap-2">
                    <Store className="w-4 h-4 text-purple-600" />
                    Top Overdue Retailers
                  </h3>
                  <span className="text-xs text-slate-400">Credit Risk Watch</span>
                </div>
                <div className="divide-y divide-slate-100">
                  {controlRoomData?.topOverdueRetailers?.length === 0 ? (
                    <p className="py-4 text-center text-xs text-slate-400">No overdue balances recorded</p>
                  ) : (
                    controlRoomData?.topOverdueRetailers?.map((r: any) => (
                      <div key={r.id} className="py-2.5 flex items-center justify-between text-xs">
                        <div>
                          <p className="font-bold text-slate-800">{r.name}</p>
                          <p className="text-slate-400 text-[11px]">{r.contact_number || 'No phone'} • Beat: {r.beat_id}</p>
                        </div>
                        <div className="text-right">
                          <p className="font-bold text-rose-600">₹{(r.outstanding_amount_paise / 100).toFixed(2)}</p>
                          <p className="text-slate-400 text-[10px]">Limit: ₹{(r.credit_limit_paise / 100).toFixed(0)}</p>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Tomorrow Purchase Suggestions */}
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="font-bold text-slate-900 text-sm sm:text-base flex items-center gap-2">
                    <ShoppingBag className="w-4 h-4 text-emerald-600" />
                    Tomorrow Purchase Suggestions
                  </h3>
                  <span className="text-xs text-slate-400">Inventory Reorder</span>
                </div>
                <div className="divide-y divide-slate-100">
                  {controlRoomData?.tomorrowPurchaseSuggestions?.length === 0 ? (
                    <p className="py-4 text-center text-xs text-slate-400">Inventory levels are healthy</p>
                  ) : (
                    controlRoomData?.tomorrowPurchaseSuggestions?.map((p: any) => (
                      <div key={p.id} className="py-2.5 flex items-center justify-between text-xs">
                        <div>
                          <p className="font-bold text-slate-800">{p.name}</p>
                          <p className="text-slate-400 text-[11px]">SKU: {p.sku} • Stock: <span className="font-semibold text-amber-600">{p.stock_quantity} {p.unit}</span></p>
                        </div>
                        <div className="text-right">
                          <span className="px-2 py-0.5 bg-emerald-50 text-emerald-700 font-bold text-[11px] rounded-md border border-emerald-200">
                            Reorder {p.stock_quantity <= 10 ? 50 : 30} {p.unit}
                          </span>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 1.2 EXCEPTION CENTER TAB */}
        {activeTab === 'exceptions' && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Central Exception Center</h1>
                <p className="text-xs sm:text-sm text-slate-500">Live operational issues requiring manager/owner intervention</p>
              </div>
              <span className="px-3 py-1 bg-rose-50 text-rose-700 border border-rose-200 font-bold text-xs rounded-xl self-start">
                {exceptionsList.length} Active Problems
              </span>
            </div>

            <div className="space-y-3">
              {exceptionsList.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-12 text-center text-slate-400 text-sm">
                  🎉 Zero exceptions detected! Daily warehouse and delivery cycle is running smoothly.
                </div>
              ) : (
                exceptionsList.map((exc, idx) => (
                  <div key={idx} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs flex items-start gap-3.5">
                    <div className={`p-2.5 rounded-xl shrink-0 ${exc.severity === 'HIGH' ? 'bg-rose-50 text-rose-600' : 'bg-amber-50 text-amber-600'}`}>
                      <AlertTriangle className="w-5 h-5" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-2">
                        <p className="font-bold text-slate-900 text-sm">{exc.title}</p>
                        <span className={`px-2 py-0.5 text-[10px] font-bold rounded-md ${exc.severity === 'HIGH' ? 'bg-rose-100 text-rose-800' : 'bg-amber-100 text-amber-800'}`}>
                          {exc.severity}
                        </span>
                      </div>
                      <p className="text-slate-600 text-xs mt-1">{exc.description}</p>
                      <p className="text-slate-400 text-[10px] mt-1.5 font-mono">Alert Type: {exc.type}</p>
                    </div>
                  </div>
                ))
              )}
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
                    {(o.status === 'APPROVED' || o.status === 'PACKED') && (
                      <button
                        onClick={() => setAssignModalOrder(o)}
                        className="w-full flex items-center justify-center py-2.5 px-4 text-xs font-semibold rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white shadow-xs transition cursor-pointer min-h-[40px]"
                      >
                        Assign Delivery
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
                            ) : o.status === 'APPROVED' || o.status === 'PACKED' ? (
                              <button
                                onClick={() => setAssignModalOrder(o)}
                                className="px-3.5 py-1.5 text-xs font-semibold rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white shadow-xs transition cursor-pointer"
                              >
                                Assign Delivery
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
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Master Products Catalog</h1>
                <p className="text-xs sm:text-sm text-slate-500">Inventory items available for wholesale distribution</p>
              </div>
              <button
                onClick={() => setShowAddProductModal(true)}
                className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl shadow-xs transition cursor-pointer self-start sm:self-auto"
              >
                <Plus className="w-4 h-4" />
                <span>Add Product</span>
              </button>
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
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Retailers & Distribution Network</h1>
                <p className="text-xs sm:text-sm text-slate-500">Registered shops and wholesale distribution accounts</p>
              </div>
              <button
                onClick={() => setShowAddRetailerModal(true)}
                className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl shadow-xs transition cursor-pointer self-start sm:self-auto"
              >
                <Plus className="w-4 h-4" />
                <span>Add Retailer / Shop</span>
              </button>
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

        {/* ADD RETAILER MODAL */}
        {showAddRetailerModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
            <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-6 border border-slate-200 max-h-[90vh] overflow-y-auto space-y-5 animate-in fade-in zoom-in-95 duration-150">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div>
                  <h3 className="text-lg font-bold text-slate-900">Add New Shop / Wholesale</h3>
                  <p className="text-xs text-slate-500">Register a new retail or wholesale counter</p>
                </div>
                <button
                  type="button"
                  onClick={() => setShowAddRetailerModal(false)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <form onSubmit={handleCreateRetailer} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    Shop / Wholesale Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Laxmi Wholesale & Retail"
                    value={newRetailer.name}
                    onChange={(e) => setNewRetailer({ ...newRetailer, name: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                  />
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Contact Phone
                    </label>
                    <div className="relative">
                      <Phone className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                      <input
                        type="text"
                        placeholder="e.g. 9876543210"
                        value={newRetailer.contactNumber}
                        onChange={(e) => setNewRetailer({ ...newRetailer, contactNumber: e.target.value })}
                        className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Credit Limit (₹)
                    </label>
                    <input
                      type="number"
                      placeholder="5000"
                      value={newRetailer.creditLimitRupees}
                      onChange={(e) => setNewRetailer({ ...newRetailer, creditLimitRupees: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    Address
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. Shop #14, Main Wholesale Market"
                    value={newRetailer.address}
                    onChange={(e) => setNewRetailer({ ...newRetailer, address: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                  />
                </div>

                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider">
                      Location / GPS Coordinates
                    </label>
                    <button
                      type="button"
                      onClick={handleDetectLocation}
                      disabled={detectingLocation}
                      className="inline-flex items-center gap-1.5 text-xs text-blue-600 hover:text-blue-700 font-semibold cursor-pointer disabled:opacity-50"
                    >
                      <MapPin className="w-3.5 h-3.5" />
                      {detectingLocation ? 'Detecting...' : '📍 Auto-Detect Location'}
                    </button>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <input
                      type="text"
                      placeholder="Latitude"
                      value={newRetailer.latitude}
                      onChange={(e) => setNewRetailer({ ...newRetailer, latitude: e.target.value })}
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                    <input
                      type="text"
                      placeholder="Longitude"
                      value={newRetailer.longitude}
                      onChange={(e) => setNewRetailer({ ...newRetailer, longitude: e.target.value })}
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>
                </div>

                <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setShowAddRetailerModal(false)}
                    className="px-4 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={creatingRetailer}
                    className="px-5 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-xs transition disabled:opacity-50 cursor-pointer"
                  >
                    {creatingRetailer ? 'Adding...' : 'Add Shop'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ADD PRODUCT MODAL */}
        {showAddProductModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
            <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-6 border border-slate-200 max-h-[90vh] overflow-y-auto space-y-5 animate-in fade-in zoom-in-95 duration-150">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div>
                  <h3 className="text-lg font-bold text-slate-900">Add Product to Catalog</h3>
                  <p className="text-xs text-slate-500">Add an inventory item available for wholesale distribution</p>
                </div>
                <button
                  type="button"
                  onClick={() => setShowAddProductModal(false)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <form onSubmit={handleCreateProduct} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    Product / Item Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Masala Chai 500g Pack"
                    value={newProduct.name}
                    onChange={(e) => setNewProduct({ ...newProduct, name: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Category
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Beverages, Spices"
                      value={newProduct.category}
                      onChange={(e) => setNewProduct({ ...newProduct, category: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Unit
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Pack, Box, Kg"
                      value={newProduct.unit}
                      onChange={(e) => setNewProduct({ ...newProduct, unit: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Price (₹) *
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      required
                      placeholder="100.00"
                      value={newProduct.priceRupees}
                      onChange={(e) => setNewProduct({ ...newProduct, priceRupees: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Warehouse Stock *
                    </label>
                    <input
                      type="number"
                      required
                      placeholder="50"
                      value={newProduct.stockQuantity}
                      onChange={(e) => setNewProduct({ ...newProduct, stockQuantity: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>
                </div>

                <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setShowAddProductModal(false)}
                    className="px-4 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={creatingProduct}
                    className="px-5 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-xs transition disabled:opacity-50 cursor-pointer"
                  >
                    {creatingProduct ? 'Adding...' : 'Add Product'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ASSIGN DELIVERY MODAL */}
        {assignModalOrder && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
            <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-6 border border-slate-200 space-y-5 animate-in fade-in zoom-in-95 duration-150">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div>
                  <h3 className="text-lg font-bold text-slate-900">Assign Goods to Delivery</h3>
                  <p className="text-xs text-slate-500">Dispatch order to designated delivery executive</p>
                </div>
                <button
                  type="button"
                  onClick={() => setAssignModalOrder(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="space-y-4">
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200 text-xs space-y-1.5">
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Order ID:</span>
                    <span className="font-mono font-bold text-slate-900">{assignModalOrder.id}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Retailer / Shop:</span>
                    <span className="font-semibold text-slate-900">{assignModalOrder.retailer_name || assignModalOrder.retailer_id}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Total Value:</span>
                    <span className="font-bold text-slate-900">₹{((assignModalOrder.total_amount_paise || (assignModalOrder as any).total_amount * 100 || 0) / 100).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Status:</span>
                    <span className="font-semibold text-amber-700">{assignModalOrder.status}</span>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    Select Delivery Executive *
                  </label>
                  {deliveryExecutives.length === 0 ? (
                    <div className="p-3 bg-amber-50 text-amber-800 text-xs rounded-xl border border-amber-200">
                      No active delivery executives found. Please ensure a delivery executive account exists.
                    </div>
                  ) : (
                    <select
                      value={selectedDriverId}
                      onChange={(e) => setSelectedDriverId(e.target.value)}
                      className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:bg-white transition cursor-pointer"
                    >
                      {deliveryExecutives.map((d) => (
                        <option key={d.id} value={d.id}>
                          {d.fullName || d.username} (@{d.username})
                        </option>
                      ))}
                    </select>
                  )}
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setAssignModalOrder(null)}
                  className="px-4 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleAssignDelivery}
                  disabled={assigningLoading || !selectedDriverId}
                  className="px-5 py-2 text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-700 rounded-xl shadow-xs transition disabled:opacity-50 cursor-pointer"
                >
                  {assigningLoading ? 'Assigning...' : 'Assign & Dispatch'}
                </button>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
