'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import {
  CanonicalRole,
  ProductItem,
  RetailerItem,
  OrderItem,
  TruckFleet,
  InwardReceipt,
  CashHandoverItem
} from '@/lib/types';
import {
  INITIAL_PRODUCTS,
  INITIAL_RETAILERS,
  INITIAL_FLEET,
  INITIAL_ORDERS,
  INITIAL_INWARD_RECEIPTS,
  INITIAL_HANDOVERS
} from '@/lib/seed-data';
import { getStoredUser, clearSession } from '@/lib/api';

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

  // Central Shared Business State
  const [products, setProducts] = useState<ProductItem[]>(INITIAL_PRODUCTS);
  const [retailers, setRetailers] = useState<RetailerItem[]>(INITIAL_RETAILERS);
  const [fleet, setFleet] = useState<TruckFleet[]>(INITIAL_FLEET);
  const [orders, setOrders] = useState<OrderItem[]>(INITIAL_ORDERS);
  const [inwardReceipts, setInwardReceipts] = useState<InwardReceipt[]>(INITIAL_INWARD_RECEIPTS);
  const [handovers, setHandovers] = useState<CashHandoverItem[]>(INITIAL_HANDOVERS);

  // Initialize from LocalStorage or user session
  useEffect(() => {
    try {
      const savedRole = localStorage.getItem('rf_active_role') as CanonicalRole;
      if (savedRole && ['WAREHOUSE', 'SALES', 'DELIVERY', 'OWNER', 'ADMIN'].includes(savedRole)) {
        setCurrentRole(savedRole);
        updateSubTabForRole(savedRole);
      } else {
        const u = getStoredUser();
        if (u?.role) {
          const r = u.role.toUpperCase();
          if (r.includes('WAREHOUSE')) {
            setCurrentRole('WAREHOUSE');
            setActiveSubTab('godown');
          } else if (r.includes('SALES')) {
            setCurrentRole('SALES');
            setActiveSubTab('dash');
          } else if (r.includes('DELIVERY')) {
            setCurrentRole('DELIVERY');
            setActiveSubTab('stops');
          } else {
            setCurrentRole('OWNER');
            setActiveSubTab('pulse');
          }
        }
      }

      // Restore persisted products & orders if stored
      const savedProds = localStorage.getItem('rf_products');
      if (savedProds) setProducts(JSON.parse(savedProds));

      const savedOrders = localStorage.getItem('rf_orders');
      if (savedOrders) setOrders(JSON.parse(savedOrders));

      const savedInwards = localStorage.getItem('rf_inwards');
      if (savedInwards) setInwardReceipts(JSON.parse(savedInwards));

      const savedFleet = localStorage.getItem('rf_fleet');
      if (savedFleet) setFleet(JSON.parse(savedFleet));

      const savedHandovers = localStorage.getItem('rf_handovers');
      if (savedHandovers) setHandovers(JSON.parse(savedHandovers));
    } catch (e) {
      console.warn('LocalStorage hydration fallback to initial data', e);
    } finally {
      setIsLoaded(true);
    }
  }, []);

  // Sync to LocalStorage on modifications
  useEffect(() => {
    if (!isLoaded) return;
    try {
      localStorage.setItem('rf_active_role', currentRole);
      localStorage.setItem('rf_products', JSON.stringify(products));
      localStorage.setItem('rf_orders', JSON.stringify(orders));
      localStorage.setItem('rf_inwards', JSON.stringify(inwardReceipts));
      localStorage.setItem('rf_fleet', JSON.stringify(fleet));
      localStorage.setItem('rf_handovers', JSON.stringify(handovers));
    } catch (e) {
      console.warn('LocalStorage save error', e);
    }
  }, [isLoaded, currentRole, products, orders, inwardReceipts, fleet, handovers]);

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

  const handleSelectRole = (newRole: CanonicalRole) => {
    setCurrentRole(newRole);
    updateSubTabForRole(newRole);
  };

  const handleLogout = () => {
    clearSession();
    router.push('/login');
  };

  if (!isLoaded) {
    return (
      <div className="min-h-screen bg-[#F8FAFC] flex items-center justify-center">
        <div className="flex flex-col items-center gap-2 text-slate-500">
          <div className="w-8 h-8 border-3 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
          <span className="text-xs font-bold">Loading RouteFlow Operations...</span>
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
