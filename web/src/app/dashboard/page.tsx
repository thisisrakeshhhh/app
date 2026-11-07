'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import {
  CanonicalRole,
  ProductItem,
  RetailerItem,
  OrderItem,
  OrderLineItem,
  TruckFleet,
  InwardReceipt,
  CashHandoverItem
} from '@/lib/types';
import {
  INITIAL_FLEET,
  INITIAL_INWARD_RECEIPTS
} from '@/lib/seed-data';
import {
  ensureAuthenticated,
  fetchLiveProducts,
  fetchLiveRetailers,
  fetchLiveOrders,
  fetchLiveHandovers,
  serverAdjustInventory,
  serverCreateOrder,
  serverCreateRetailer,
  serverApproveOrder,
  serverPickAndPackOrder,
  serverDispatchAndDeliver,
  getStoredUser,
  clearSession
} from '@/lib/api';

import RoleHeader from '@/components/layout/RoleHeader';
import MobileNavBar from '@/components/layout/MobileNavBar';
import RoleSwitchModal from '@/components/modals/RoleSwitchModal';

import WarehouseView from '@/components/views/WarehouseView';
import SalesView from '@/components/views/SalesView';
import DeliveryView from '@/components/views/DeliveryView';
import OwnerAdminView from '@/components/views/OwnerAdminView';

export default function DashboardPage() {
  const router = useRouter();

  // Active Role & Sub-tab State
  const [currentRole, setCurrentRole] = useState<CanonicalRole>('WAREHOUSE');
  const [activeSubTab, setActiveSubTab] = useState<string>('godown');
  const [showRoleModal, setShowRoleModal] = useState<boolean>(false);
  const [viewMode, setViewMode] = useState<'desktop' | 'phone_shell'>('desktop');
  const [isLoaded, setIsLoaded] = useState<boolean>(false);
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);

  // Live Server Business State
  const [products, setProducts] = useState<ProductItem[]>([]);
  const [retailers, setRetailers] = useState<RetailerItem[]>([]);
  const [fleet, setFleet] = useState<TruckFleet[]>(INITIAL_FLEET);
  const [orders, setOrders] = useState<OrderItem[]>([]);
  const [inwardReceipts, setInwardReceipts] = useState<InwardReceipt[]>(INITIAL_INWARD_RECEIPTS);
  const [handovers, setHandovers] = useState<CashHandoverItem[]>([]);

  const [serverStats, setServerStats] = useState<{ products: number; retailers: number; orders: number }>({
    products: 0,
    retailers: 0,
    orders: 0,
  });

  // Fetch Live Server Data from Cloudflare D1
  const loadServerData = useCallback(async (role: CanonicalRole, silent = false) => {
    if (!silent) setIsRefreshing(true);
    try {
      await ensureAuthenticated(role);

      const [liveProds, liveRets, liveOrds, liveHnds] = await Promise.all([
        fetchLiveProducts().catch((e) => {
          console.error('Products fetch error:', e);
          return [];
        }),
        fetchLiveRetailers().catch((e) => {
          console.error('Retailers fetch error:', e);
          return [];
        }),
        fetchLiveOrders().catch((e) => {
          console.error('Orders fetch error:', e);
          return [];
        }),
        fetchLiveHandovers().catch((e) => {
          console.error('Handovers fetch error:', e);
          return [];
        }),
      ]);

      if (liveProds.length > 0) setProducts(liveProds);
      if (liveRets.length > 0) setRetailers(liveRets);
      if (liveOrds.length > 0) setOrders(liveOrds);
      if (liveHnds.length > 0) setHandovers(liveHnds);

      setServerStats({
        products: liveProds.length,
        retailers: liveRets.length,
        orders: liveOrds.length,
      });
    } catch (err) {
      console.error('Server sync error:', err);
    } finally {
      if (!silent) setIsRefreshing(false);
      setIsLoaded(true);
    }
  }, []);

  // Initialize from session / server
  useEffect(() => {
    const savedRole = (typeof window !== 'undefined' ? localStorage.getItem('rf_active_role') : null) as CanonicalRole;
    let initialRole: CanonicalRole = 'WAREHOUSE';

    if (savedRole && ['WAREHOUSE', 'SALES', 'DELIVERY', 'OWNER', 'ADMIN'].includes(savedRole)) {
      initialRole = savedRole;
    } else {
      const u = getStoredUser();
      if (u?.role) {
        const r = u.role.toUpperCase();
        if (r.includes('WAREHOUSE')) initialRole = 'WAREHOUSE';
        else if (r.includes('SALES')) initialRole = 'SALES';
        else if (r.includes('DELIVERY')) initialRole = 'DELIVERY';
        else initialRole = 'OWNER';
      }
    }

    setCurrentRole(initialRole);
    updateSubTabForRole(initialRole);
    loadServerData(initialRole);
  }, [loadServerData]);

  const updateSubTabForRole = (role: CanonicalRole) => {
    switch (role) {
      case 'WAREHOUSE':
        setActiveSubTab('godown');
        break;
      case 'SALES':
        setActiveSubTab('dash');
        break;
      case 'DELIVERY':
        setActiveSubTab('stops');
        break;
      case 'OWNER':
      case 'ADMIN':
        setActiveSubTab('pulse');
        break;
    }
  };

  const handleSelectRole = async (newRole: CanonicalRole) => {
    setCurrentRole(newRole);
    updateSubTabForRole(newRole);
    if (typeof window !== 'undefined') {
      localStorage.setItem('rf_active_role', newRole);
    }
    await loadServerData(newRole);
  };

  const handleLogout = () => {
    clearSession();
    router.push('/login');
  };

  // ==========================================
  // REAL SERVER MUTATIONS HANDLERS
  // ==========================================

  const handleServerInward = async (productId: string, boxes: number, notes: string) => {
    try {
      await serverAdjustInventory(productId, boxes, 'STOCK_RECEIPT', notes);
      // Refetch live products to reflect new stock from D1
      const freshProds = await fetchLiveProducts();
      if (freshProds.length > 0) setProducts(freshProds);
    } catch (e: any) {
      console.warn('Server Inward adjust fallback:', e.message);
    }
  };

  const handleServerCreateOrder = async (retailerId: string, totalRupees: number, items: OrderLineItem[]) => {
    try {
      await serverCreateOrder({
        retailerId,
        totalAmountPaise: Math.round(totalRupees * 100),
        items: items.map((i) => ({
          productId: i.productId,
          quantity: i.quantity,
          pricePaiseAtTime: Math.round(i.unitPriceRupees * 100),
        })),
      });
      // Refetch live orders from D1
      const freshOrders = await fetchLiveOrders();
      if (freshOrders.length > 0) setOrders(freshOrders);
    } catch (e: any) {
      console.warn('Server Order create fallback:', e.message);
    }
  };

  const handleServerCreateRetailer = async (data: any) => {
    try {
      await serverCreateRetailer(data);
      const freshRets = await fetchLiveRetailers();
      if (freshRets.length > 0) setRetailers(freshRets);
    } catch (e: any) {
      console.warn('Server Retailer create fallback:', e.message);
    }
  };

  const handleServerPack = async (orderId: string, productId: string) => {
    try {
      await serverPickAndPackOrder(orderId, productId, 'user_delivery');
      const freshOrders = await fetchLiveOrders();
      if (freshOrders.length > 0) setOrders(freshOrders);
    } catch (e: any) {
      console.warn('Server Pack fallback:', e.message);
    }
  };

  const handleServerDeliver = async (orderId: string, recipientName: string, paymentMethod: 'CASH' | 'CREDIT') => {
    try {
      await serverDispatchAndDeliver(orderId, recipientName, paymentMethod);
      const freshOrders = await fetchLiveOrders();
      if (freshOrders.length > 0) setOrders(freshOrders);
    } catch (e: any) {
      console.warn('Server Deliver fallback:', e.message);
    }
  };

  const handleServerApprove = async (orderId: string) => {
    try {
      await serverApproveOrder(orderId);
      const freshOrders = await fetchLiveOrders();
      if (freshOrders.length > 0) setOrders(freshOrders);
    } catch (e: any) {
      console.warn('Server Approve fallback:', e.message);
    }
  };

  if (!isLoaded) {
    return (
      <div className="min-h-screen bg-[#F8FAFC] flex items-center justify-center">
        <div className="flex flex-col items-center gap-2 text-slate-500">
          <div className="w-8 h-8 border-3 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
          <span className="text-xs font-bold">Connecting to Cloudflare D1 Server...</span>
        </div>
      </div>
    );
  }

  // Render role view component based on active role
  const renderActiveRoleView = () => {
    switch (currentRole) {
      case 'WAREHOUSE':
        return (
          <WarehouseView
            products={products}
            setProducts={setProducts}
            inwardReceipts={inwardReceipts}
            setInwardReceipts={setInwardReceipts}
            fleet={fleet}
            setFleet={setFleet}
            orders={orders}
            setOrders={setOrders}
            activeSubTab={activeSubTab as any}
            onSubTabChange={(t) => setActiveSubTab(t)}
            onServerInward={handleServerInward}
            onServerPack={handleServerPack}
          />
        );
      case 'SALES':
        return (
          <SalesView
            products={products}
            retailers={retailers}
            setRetailers={setRetailers}
            orders={orders}
            setOrders={setOrders}
            activeSubTab={activeSubTab as any}
            onSubTabChange={(t) => setActiveSubTab(t)}
            onServerCreateOrder={handleServerCreateOrder}
            onServerCreateRetailer={handleServerCreateRetailer}
          />
        );
      case 'DELIVERY':
        return (
          <DeliveryView
            orders={orders}
            setOrders={setOrders}
            fleet={fleet}
            handovers={handovers}
            setHandovers={setHandovers}
            activeSubTab={activeSubTab as any}
            onSubTabChange={(t) => setActiveSubTab(t)}
            onServerDeliver={handleServerDeliver}
          />
        );
      case 'OWNER':
      case 'ADMIN':
      default:
        return (
          <OwnerAdminView
            orders={orders}
            setOrders={setOrders}
            retailers={retailers}
            products={products}
            handovers={handovers}
            setHandovers={setHandovers}
            fleet={fleet}
            activeSubTab={activeSubTab as any}
            onSubTabChange={(t) => setActiveSubTab(t)}
            onServerApprove={handleServerApprove}
          />
        );
    }
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] text-slate-900 flex flex-col font-sans">
      {/* Universal Role Header */}
      <RoleHeader
        currentRole={currentRole}
        onOpenRoleSwitch={() => setShowRoleModal(true)}
        viewMode={viewMode}
        onToggleViewMode={() => setViewMode(viewMode === 'desktop' ? 'phone_shell' : 'desktop')}
        onLogout={handleLogout}
        isLiveServer={true}
        serverStats={serverStats}
        onRefreshLive={() => loadServerData(currentRole)}
        isRefreshing={isRefreshing}
      />

      {/* Main Container: Switchable between Responsive Desktop View and Phone Shell Simulator */}
      {viewMode === 'desktop' ? (
        <main className="flex-1 max-w-7xl w-full mx-auto p-3 sm:p-6 pb-20 md:pb-8">
          {renderActiveRoleView()}
        </main>
      ) : (
        /* PHONE SHELL SIMULATOR: Exact mobile app container centered on screen */
        <div className="flex-1 py-4 sm:py-8 flex items-center justify-center bg-slate-950/10">
          <div className="w-full max-w-md bg-white min-h-[780px] rounded-3xl shadow-2xl border-8 border-slate-900 overflow-hidden flex flex-col relative">
            {/* Phone Speaker Notch */}
            <div className="h-5 bg-slate-900 flex items-center justify-center">
              <div className="w-16 h-1 rounded-full bg-slate-700"></div>
            </div>

            {/* Simulated Phone Content */}
            <div className="flex-1 p-3.5 pb-20 overflow-y-auto">
              {renderActiveRoleView()}
            </div>

            {/* Mobile Bottom Navigation Bar inside Phone Frame */}
            <MobileNavBar
              currentRole={currentRole}
              activeSubTab={activeSubTab}
              onSelectSubTab={(t) => setActiveSubTab(t)}
              onOpenRoleSwitch={() => setShowRoleModal(true)}
            />
          </div>
        </div>
      )}

      {/* Fixed Bottom Navigation Bar for Mobile devices (hidden on md+ in desktop view) */}
      {viewMode === 'desktop' && (
        <div className="md:hidden">
          <MobileNavBar
            currentRole={currentRole}
            activeSubTab={activeSubTab}
            onSelectSubTab={(t) => setActiveSubTab(t)}
            onOpenRoleSwitch={() => setShowRoleModal(true)}
          />
        </div>
      )}

      {/* Interactive Role Switcher Modal */}
      <RoleSwitchModal
        isOpen={showRoleModal}
        onClose={() => setShowRoleModal(false)}
        currentRole={currentRole}
        onSelectRole={handleSelectRole}
      />
    </div>
  );
}
