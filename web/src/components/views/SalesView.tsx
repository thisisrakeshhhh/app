'use client';

import { useState } from 'react';
import {
  ProductItem,
  RetailerItem,
  OrderItem,
  OrderLineItem,
  PackagingUnit
} from '@/lib/types';
import {
  Store,
  ShoppingCart,
  Package,
  Search,
  Plus,
  Minus,
  CheckCircle2,
  Phone,
  MapPin,
  Clock,
  TrendingUp,
  Warehouse,
  Truck,
  Check,
  AlertCircle,
  ArrowRight,
  ShieldAlert
} from 'lucide-react';

interface SalesViewProps {
  products: ProductItem[];
  retailers: RetailerItem[];
  setRetailers: React.Dispatch<React.SetStateAction<RetailerItem[]>>;
  orders: OrderItem[];
  setOrders: React.Dispatch<React.SetStateAction<OrderItem[]>>;
  activeSubTab?: 'dash' | 'retailers' | 'products' | 'new_order';
  onSubTabChange?: (tab: 'dash' | 'retailers' | 'products' | 'new_order') => void;
}

export default function SalesView({
  products,
  retailers,
  setRetailers,
  orders,
  setOrders,
  activeSubTab = 'dash',
  onSubTabChange,
}: SalesViewProps) {
  const [subTab, setSubTab] = useState<'dash' | 'retailers' | 'products' | 'new_order'>(activeSubTab);

  const handleTabClick = (t: 'dash' | 'retailers' | 'products' | 'new_order') => {
    setSubTab(t);
    if (onSubTabChange) onSubTabChange(t);
  };

  const [searchQuery, setSearchQuery] = useState('');
  const [checkedInRetailerId, setCheckedInRetailerId] = useState<string | null>(null);

  // New Order Booking Form State
  const [selectedRetailerId, setSelectedRetailerId] = useState<string>(retailers[0]?.id || '');
  const [orderItemsMap, setOrderItemsMap] = useState<
    Record<string, { unit: PackagingUnit; qty: number }>
  >({});
  const [orderSubmittedBanner, setOrderSubmittedBanner] = useState<string | null>(null);

  // Add Retailer Modal State
  const [showAddRetailerModal, setShowAddRetailerModal] = useState(false);
  const [newRetailerName, setNewRetailerName] = useState('');
  const [newRetailerOwner, setNewRetailerOwner] = useState('');
  const [newRetailerPhone, setNewRetailerPhone] = useState('');
  const [newRetailerAddress, setNewRetailerAddress] = useState('');
  const [newRetailerBeat, setNewRetailerBeat] = useState('Beat-01 Mandore Circle');
  const [newRetailerCreditLimit, setNewRetailerCreditLimit] = useState('15000');

  // Computed Godown Totals
  const totalGodownBoxes = products.reduce((acc, p) => acc + p.godownStockBoxes, 0);
  const totalVanBoxes = products.reduce((acc, p) => acc + p.carStockBoxes, 0);

  // Cart calculations
  const calculateCartTotal = () => {
    let total = 0;
    Object.entries(orderItemsMap).forEach(([prodId, selection]) => {
      if (selection.qty <= 0) return;
      const prod = products.find((p) => p.id === prodId);
      if (!prod) return;

      const piecePrice = prod.piecePricePaise / 100;
      let unitPrice = 0;
      if (selection.unit === 'BOX') unitPrice = piecePrice * prod.boxQty;
      else if (selection.unit === 'STRIP') unitPrice = piecePrice * prod.stripQty;
      else unitPrice = piecePrice;

      total += unitPrice * selection.qty;
    });
    return total;
  };

  const cartTotalAmount = calculateCartTotal();
  const cartItemCount = Object.values(orderItemsMap).filter((s) => s.qty > 0).length;

  const handleUpdateItemQty = (prodId: string, unit: PackagingUnit, delta: number) => {
    setOrderItemsMap((prev) => {
      const cur = prev[prodId] || { unit, qty: 0 };
      const newQty = Math.max(0, cur.qty + delta);
      return {
        ...prev,
        [prodId]: { unit, qty: newQty },
      };
    });
  };

  const handleSetItemUnit = (prodId: string, unit: PackagingUnit) => {
    setOrderItemsMap((prev) => {
      const cur = prev[prodId] || { unit: 'BOX', qty: 0 };
      return {
        ...prev,
        [prodId]: { ...cur, unit },
      };
    });
  };

  // Submit Naya Order
  const handleSubmitOrder = (e: React.FormEvent) => {
    e.preventDefault();
    if (cartItemCount === 0) {
      alert('Please add at least 1 item to the order');
      return;
    }

    const ret = retailers.find((r) => r.id === selectedRetailerId) || retailers[0];
    const lineItems: OrderLineItem[] = [];

    Object.entries(orderItemsMap).forEach(([prodId, selection]) => {
      if (selection.qty <= 0) return;
      const prod = products.find((p) => p.id === prodId);
      if (!prod) return;

      const piecePrice = prod.piecePricePaise / 100;
      let unitPrice = 0;
      let boxEq = 0;

      if (selection.unit === 'BOX') {
        unitPrice = piecePrice * prod.boxQty;
        boxEq = selection.qty;
      } else if (selection.unit === 'STRIP') {
        unitPrice = piecePrice * prod.stripQty;
        boxEq = (selection.qty * prod.stripQty) / prod.boxQty;
      } else {
        unitPrice = piecePrice;
        boxEq = selection.qty / prod.boxQty;
      }

      lineItems.push({
        productId: prod.id,
        productName: prod.name,
        unit: selection.unit,
        quantity: selection.qty,
        boxEquivalent: boxEq,
        unitPriceRupees: unitPrice,
        totalPriceRupees: unitPrice * selection.qty,
      });
    });

    const newOrder: OrderItem = {
      id: `ORD-2026-${Math.floor(1000 + Math.random() * 9000)}`,
      orderCode: `RF-ORD-0${Math.floor(100 + Math.random() * 900)}`,
      retailerId: ret.id,
      retailerName: ret.name,
      retailerPhone: ret.phone,
      retailerAddress: ret.address,
      status: 'APPROVED',
      totalAmountRupees: cartTotalAmount,
      items: lineItems,
      assignedTruckPlate: 'RJ-19-GA-1102',
      deliveryOtp: `${Math.floor(1000 + Math.random() * 9000)}`,
      createdAt: new Date().toISOString().replace('T', ' ').slice(0, 16),
    };

    setOrders((prev) => [newOrder, ...prev]);
    setOrderItemsMap({});
    setOrderSubmittedBanner(`Order ${newOrder.orderCode} booked for ${ret.name} (₹${cartTotalAmount.toFixed(2)})!`);
    handleTabClick('dash');
    setTimeout(() => setOrderSubmittedBanner(null), 5000);
  };

  // Add Retailer
  const handleCreateRetailer = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRetailerName.trim() || !newRetailerPhone.trim()) {
      alert('Please enter Shop Name and Contact Number');
      return;
    }

    const created: RetailerItem = {
      id: `RET-${Math.floor(100 + Math.random() * 900)}`,
      name: newRetailerName.trim(),
      ownerName: newRetailerOwner.trim() || newRetailerName.trim(),
      phone: newRetailerPhone.trim(),
      address: newRetailerAddress.trim() || 'Jodhpur Beat Market',
      beat: newRetailerBeat,
      outstandingBalanceRupees: 0.0,
      creditLimitRupees: parseFloat(newRetailerCreditLimit) || 15000,
      lastVisitDate: new Date().toISOString().slice(0, 10),
    };

    setRetailers((prev) => [created, ...prev]);
    setShowAddRetailerModal(false);
    setSelectedRetailerId(created.id);
    alert(`Shop ${created.name} added to ${created.beat}!`);
  };

  return (
    <div className="space-y-4">
      {/* Subtab Navigation Pills */}
      <div className="bg-white rounded-2xl border border-slate-200 p-1.5 flex items-center gap-1 shadow-xs overflow-x-auto scrollbar-none">
        <button
          onClick={() => handleTabClick('dash')}
          className={`flex-1 min-w-[110px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'dash'
              ? 'bg-rose-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <TrendingUp className="w-4 h-4" />
          <span>Sales Home</span>
        </button>

        <button
          onClick={() => handleTabClick('new_order')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'new_order'
              ? 'bg-rose-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <ShoppingCart className="w-4 h-4" />
          <span>Naya Order</span>
          {cartItemCount > 0 && (
            <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-white text-rose-700 font-extrabold">
              {cartItemCount}
            </span>
          )}
        </button>

        <button
          onClick={() => handleTabClick('retailers')}
          className={`flex-1 min-w-[110px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'retailers'
              ? 'bg-rose-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Store className="w-4 h-4" />
          <span>Retailers</span>
          <span className="text-[10px] bg-slate-100 text-slate-600 px-1.5 py-0.2 rounded-full font-bold">
            {retailers.length}
          </span>
        </button>

        <button
          onClick={() => handleTabClick('products')}
          className={`flex-1 min-w-[110px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'products'
              ? 'bg-rose-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Package className="w-4 h-4" />
          <span>Items Catalog</span>
        </button>
      </div>

      {orderSubmittedBanner && (
        <div className="p-3.5 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-xs font-semibold flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>{orderSubmittedBanner}</span>
        </div>
      )}

      {/* 1. SALES DASHBOARD VIEW */}
      {subTab === 'dash' && (
        <div className="space-y-4">
          {/* Live Inventory Availability Banner - Matches Flutter Mobile App */}
          <div className="bg-gradient-to-r from-blue-900 to-indigo-950 rounded-2xl p-4 sm:p-5 text-white border border-blue-800/60 shadow-sm space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                <span className="text-xs font-extrabold uppercase tracking-wider text-blue-200">
                  Live Inventory Availability (गोदाम स्टॉक)
                </span>
              </div>
              <button
                onClick={() => handleTabClick('products')}
                className="text-[11px] font-bold text-blue-300 hover:text-white flex items-center gap-1 cursor-pointer"
              >
                <span>View Full Catalog</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
            </div>

            <div className="grid grid-cols-3 gap-2 pt-1">
              <div className="bg-white/10 backdrop-blur-xs rounded-xl p-3 border border-white/10">
                <span className="text-[10px] sm:text-xs text-blue-200 block font-medium">Central Godown</span>
                <span className="text-base sm:text-xl font-black text-white mt-0.5 block">
                  {totalGodownBoxes} <span className="text-xs font-normal text-blue-300">Bxs</span>
                </span>
              </div>

              <div className="bg-white/10 backdrop-blur-xs rounded-xl p-3 border border-white/10">
                <span className="text-[10px] sm:text-xs text-blue-200 block font-medium">Active SKUs</span>
                <span className="text-base sm:text-xl font-black text-amber-300 mt-0.5 block">
                  {products.length} <span className="text-xs font-normal text-blue-300">SKUs</span>
                </span>
              </div>

              <div className="bg-white/10 backdrop-blur-xs rounded-xl p-3 border border-white/10">
                <span className="text-[10px] sm:text-xs text-blue-200 block font-medium">Van Fleet Stock</span>
                <span className="text-base sm:text-xl font-black text-emerald-300 mt-0.5 block">
                  {totalVanBoxes} <span className="text-xs font-normal text-blue-300">Bxs</span>
                </span>
              </div>
            </div>
          </div>

          {/* KPI Summary Cards */}
          <div className="grid grid-cols-3 gap-3">
            <div className="bg-white rounded-xl border border-slate-200 p-3.5 shadow-2xs">
              <span className="text-[11px] text-slate-500 font-medium block">Today's Orders</span>
              <span className="text-lg font-black text-slate-900 mt-0.5 block">
                {orders.length}
              </span>
            </div>

            <div className="bg-white rounded-xl border border-slate-200 p-3.5 shadow-2xs">
              <span className="text-[11px] text-slate-500 font-medium block">Retailers on Beat</span>
              <span className="text-lg font-black text-slate-900 mt-0.5 block">
                {retailers.length} Shops
              </span>
            </div>

            <div className="bg-white rounded-xl border border-slate-200 p-3.5 shadow-2xs">
              <span className="text-[11px] text-slate-500 font-medium block">Total Bookings</span>
              <span className="text-lg font-black text-rose-600 mt-0.5 block">
                ₹{orders.reduce((acc, o) => acc + o.totalAmountRupees, 0).toFixed(0)}
              </span>
            </div>
          </div>

          {/* Quick Action Shortcuts */}
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={() => handleTabClick('new_order')}
              className="p-4 bg-rose-600 hover:bg-rose-700 text-white rounded-2xl shadow-sm transition text-left flex items-center justify-between cursor-pointer"
            >
              <div>
                <span className="text-xs text-rose-200 block font-semibold">Immediate Booking</span>
                <span className="text-sm font-bold block mt-0.5">+ Naya Order Book Karein</span>
              </div>
              <ShoppingCart className="w-5 h-5 text-white/80" />
            </button>

            <button
              onClick={() => handleTabClick('retailers')}
              className="p-4 bg-slate-900 hover:bg-slate-800 text-white rounded-2xl shadow-sm transition text-left flex items-center justify-between cursor-pointer"
            >
              <div>
                <span className="text-xs text-slate-400 block font-semibold">Field Operations</span>
                <span className="text-sm font-bold block mt-0.5">Retailer Beat & Visits</span>
              </div>
              <Store className="w-5 h-5 text-white/80" />
            </button>
          </div>

          {/* Recent Orders List */}
          <div className="bg-white rounded-2xl border border-slate-200 p-4 shadow-xs">
            <h4 className="text-xs font-bold text-slate-900 uppercase tracking-wider mb-3">
              Recent Booked Orders
            </h4>
            <div className="divide-y divide-slate-100">
              {orders.slice(0, 5).map((ord) => (
                <div key={ord.id} className="py-2.5 flex items-center justify-between text-xs">
                  <div>
                    <span className="font-bold text-slate-900 block">{ord.retailerName}</span>
                    <span className="text-[11px] text-slate-400">
                      {ord.orderCode} • {ord.items.length} items
                    </span>
                  </div>
                  <div className="text-right">
                    <span className="font-bold text-rose-700 block">
                      ₹{ord.totalAmountRupees.toFixed(2)}
                    </span>
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 font-bold">
                      {ord.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* 2. NEW ORDER BOOKING (NAYA ORDER) */}
      {subTab === 'new_order' && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-5 shadow-xs space-y-4">
            <div>
              <h3 className="text-base font-black text-slate-900">Naya Order Booking (ऑर्डर बुकिंग)</h3>
              <p className="text-xs text-slate-500">
                Live Godown Stock check with Packaging Unit Selection (Box / Strip / Pcs).
              </p>
            </div>

            {/* Step 1: Select Retailer */}
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Select Retailer / Shop *
              </label>
              <select
                value={selectedRetailerId}
                onChange={(e) => setSelectedRetailerId(e.target.value)}
                className="w-full px-3 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-rose-500 font-semibold"
              >
                {retailers.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.name} - Outstanding: ₹{r.outstandingBalanceRupees} ({r.beat})
                  </option>
                ))}
              </select>
            </div>

            {/* Step 2: Line Items with Unit Chips & Live Stock Checks */}
            <div className="space-y-3">
              <label className="block text-xs font-bold text-slate-700">
                Select Products & Packaging Quantities:
              </label>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {products.map((p) => {
                  const sel = orderItemsMap[p.id] || { unit: 'BOX', qty: 0 };
                  const piecePrice = p.piecePricePaise / 100;
                  let currentUnitPrice = 0;
                  if (sel.unit === 'BOX') currentUnitPrice = piecePrice * p.boxQty;
                  else if (sel.unit === 'STRIP') currentUnitPrice = piecePrice * p.stripQty;
                  else currentUnitPrice = piecePrice;

                  const lineTotal = currentUnitPrice * sel.qty;
                  const hasStock = p.godownStockBoxes > 0;

                  return (
                    <div
                      key={p.id}
                      className={`border rounded-xl p-3.5 transition space-y-2.5 ${
                        sel.qty > 0
                          ? 'bg-rose-50/40 border-rose-300'
                          : 'bg-white border-slate-200'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <span className="text-[10px] font-extrabold text-blue-700 bg-blue-50 px-1.5 py-0.5 rounded">
                            {p.id}
                          </span>
                          <h4 className="text-xs font-bold text-slate-900 mt-0.5">{p.name}</h4>
                          <span className="text-[11px] text-slate-500">{p.hindiName}</span>
                        </div>

                        {/* Live Stock Badge - Matches Flutter Screen */}
                        <div className="text-right">
                          <span className="text-[10px] px-2 py-0.5 rounded-full bg-blue-100 text-blue-800 font-extrabold block">
                            Godown: {p.godownStockBoxes} Bxs
                          </span>
                          <span className="text-[10px] text-slate-400 mt-0.5 block">
                            Van: {p.carStockBoxes} Bxs
                          </span>
                        </div>
                      </div>

                      {/* Unit Selector Chips (Box, Strip, Pcs) */}
                      <div className="flex items-center gap-1.5 text-xs">
                        <span className="text-[11px] text-slate-400 font-medium">Unit:</span>
                        {(['BOX', 'STRIP', 'PCS'] as PackagingUnit[]).map((u) => (
                          <button
                            key={u}
                            type="button"
                            onClick={() => handleSetItemUnit(p.id, u)}
                            className={`px-2.5 py-1 rounded-lg text-[11px] font-bold transition cursor-pointer ${
                              sel.unit === u
                                ? 'bg-rose-600 text-white shadow-xs'
                                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                            }`}
                          >
                            {u === 'BOX' && `Box (${p.boxQty} Pcs)`}
                            {u === 'STRIP' && `Strip (${p.stripQty} Pcs)`}
                            {u === 'PCS' && 'Piece (Single)'}
                          </button>
                        ))}
                      </div>

                      {/* Quantity Stepper & Line Total */}
                      <div className="flex items-center justify-between pt-1 border-t border-slate-100">
                        <div className="text-xs">
                          <span className="text-slate-400 block text-[10px]">Rate</span>
                          <span className="font-bold text-slate-800">₹{currentUnitPrice.toFixed(2)}</span>
                        </div>

                        <div className="flex items-center gap-2">
                          <button
                            type="button"
                            onClick={() => handleUpdateItemQty(p.id, sel.unit, -1)}
                            disabled={sel.qty <= 0}
                            className="w-7 h-7 rounded-lg bg-slate-100 hover:bg-slate-200 disabled:opacity-30 text-slate-700 flex items-center justify-center font-bold cursor-pointer"
                          >
                            -
                          </button>
                          <span className="w-8 text-center text-xs font-black text-slate-900">
                            {sel.qty}
                          </span>
                          <button
                            type="button"
                            onClick={() => handleUpdateItemQty(p.id, sel.unit, 1)}
                            className="w-7 h-7 rounded-lg bg-rose-600 hover:bg-rose-700 text-white flex items-center justify-center font-bold cursor-pointer"
                          >
                            +
                          </button>
                        </div>

                        <div className="text-right">
                          <span className="text-slate-400 block text-[10px]">Item Total</span>
                          <span className="font-extrabold text-rose-700 text-xs">
                            ₹{lineTotal.toFixed(2)}
                          </span>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Step 3: Order Bottom Summary & Confirmation Bar */}
            <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 space-y-3">
              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-600">Items Selected:</span>
                <span className="font-bold text-slate-900">{cartItemCount} SKUs</span>
              </div>
              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-600">Delivery Van:</span>
                <span className="font-semibold text-slate-800">RJ-19-GA-1102 (Trip 1)</span>
              </div>
              <div className="flex items-center justify-between text-sm font-extrabold border-t border-slate-200 pt-2">
                <span className="text-slate-900">Grand Total (₹):</span>
                <span className="text-rose-700 text-base">₹{cartTotalAmount.toFixed(2)}</span>
              </div>

              <button
                type="button"
                onClick={handleSubmitOrder}
                disabled={cartItemCount === 0}
                className="w-full py-3 bg-rose-600 hover:bg-rose-700 disabled:bg-slate-300 text-white rounded-xl text-xs font-bold shadow-sm transition flex items-center justify-center gap-2 cursor-pointer"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>Confirm & Submit Order to Warehouse</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 3. RETAILERS DIRECTORY & BEAT VISITS */}
      {subTab === 'retailers' && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-5 shadow-xs">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
              <div>
                <h3 className="text-base font-black text-slate-900">
                  Retailer Beat & Shop Directory
                </h3>
                <p className="text-xs text-slate-500">
                  Daily field visits, check-ins, and direct order bookings.
                </p>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setShowAddRetailerModal(true)}
                  className="px-3 py-1.5 bg-rose-600 hover:bg-rose-700 text-white rounded-xl text-xs font-bold flex items-center gap-1 cursor-pointer"
                >
                  <Plus className="w-4 h-4" />
                  <span>+ Add Shop</span>
                </button>
              </div>
            </div>

            {/* Retailer Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {retailers.map((ret) => {
                const isCheckedIn = checkedInRetailerId === ret.id;

                return (
                  <div
                    key={ret.id}
                    className="border border-slate-200 rounded-xl p-4 bg-white hover:border-slate-300 transition space-y-3 shadow-2xs"
                  >
                    <div className="flex items-start justify-between">
                      <div>
                        <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-slate-100 text-slate-600">
                          {ret.beat}
                        </span>
                        <h4 className="text-sm font-bold text-slate-900 mt-1">{ret.name}</h4>
                        <p className="text-xs text-slate-600 font-medium">{ret.ownerName}</p>
                      </div>

                      <div className="text-right">
                        <span className="text-[10px] text-slate-400 block">Khata Outstanding</span>
                        <span className="text-sm font-black text-rose-600">
                          ₹{ret.outstandingBalanceRupees.toFixed(2)}
                        </span>
                      </div>
                    </div>

                    <div className="text-[11px] text-slate-500 space-y-1">
                      <p className="flex items-center gap-1.5">
                        <Phone className="w-3.5 h-3.5 text-slate-400" />
                        <span>{ret.phone}</span>
                      </p>
                      <p className="flex items-center gap-1.5">
                        <MapPin className="w-3.5 h-3.5 text-slate-400" />
                        <span>{ret.address}</span>
                      </p>
                    </div>

                    <div className="flex items-center gap-2 pt-2 border-t border-slate-100">
                      <button
                        type="button"
                        onClick={() => {
                          setCheckedInRetailerId(isCheckedIn ? null : ret.id);
                        }}
                        className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition flex items-center justify-center gap-1 cursor-pointer ${
                          isCheckedIn
                            ? 'bg-emerald-100 text-emerald-800'
                            : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                        }`}
                      >
                        <Clock className="w-3.5 h-3.5" />
                        <span>{isCheckedIn ? 'Checked In' : 'Check In'}</span>
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setSelectedRetailerId(ret.id);
                          handleTabClick('new_order');
                        }}
                        className="flex-1 py-1.5 bg-rose-600 hover:bg-rose-700 text-white rounded-lg text-xs font-bold flex items-center justify-center gap-1 cursor-pointer"
                      >
                        <ShoppingCart className="w-3.5 h-3.5" />
                        <span>Book Order</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* 4. PRODUCTS CATALOG */}
      {subTab === 'products' && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-5 shadow-xs">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
              <div>
                <h3 className="text-base font-black text-slate-900">
                  Products & Stock Availability
                </h3>
                <p className="text-xs text-slate-500">
                  Available quantities in Central Godown and assigned delivery vans.
                </p>
              </div>

              <div className="relative min-w-[200px]">
                <Search className="w-4 h-4 absolute left-3 top-2.5 text-slate-400" />
                <input
                  type="text"
                  placeholder="Search products..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-9 pr-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-xl"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              {products
                .filter((p) => p.name.toLowerCase().includes(searchQuery.toLowerCase()))
                .map((p) => {
                  const piecePrice = p.piecePricePaise / 100;
                  const boxPrice = piecePrice * p.boxQty;
                  const stripPrice = piecePrice * p.stripQty;

                  return (
                    <div
                      key={p.id}
                      className="border border-slate-200 rounded-xl p-4 bg-white hover:border-slate-300 transition space-y-2.5 shadow-2xs"
                    >
                      <div className="flex items-start justify-between">
                        <div>
                          <span className="text-[10px] font-extrabold text-blue-700 bg-blue-50 px-1.5 py-0.5 rounded">
                            {p.id}
                          </span>
                          <h4 className="text-xs font-bold text-slate-900 mt-0.5">{p.name}</h4>
                          <span className="text-[11px] text-slate-500">{p.hindiName}</span>
                        </div>

                        {/* Live Badges */}
                        <div className="text-right">
                          <span className="text-[10px] font-extrabold px-2 py-0.5 rounded bg-blue-100 text-blue-800 block">
                            Godown: {p.godownStockBoxes} Bxs
                          </span>
                          <span className="text-[10px] text-slate-400 mt-0.5 block">
                            Van: {p.carStockBoxes} Bxs
                          </span>
                        </div>
                      </div>

                      {/* Pricing pills */}
                      <div className="bg-slate-50 rounded-lg p-2 text-[11px] grid grid-cols-3 gap-1 border border-slate-100">
                        <div>
                          <span className="text-slate-400 block">Box</span>
                          <span className="font-bold text-slate-800">₹{boxPrice.toFixed(0)}</span>
                        </div>
                        <div>
                          <span className="text-slate-400 block">Strip</span>
                          <span className="font-bold text-slate-800">₹{stripPrice.toFixed(0)}</span>
                        </div>
                        <div>
                          <span className="text-slate-400 block">Piece</span>
                          <span className="font-bold text-emerald-700">₹{piecePrice.toFixed(2)}</span>
                        </div>
                      </div>

                      <button
                        type="button"
                        onClick={() => {
                          setOrderItemsMap((prev) => ({
                            ...prev,
                            [p.id]: { unit: 'BOX', qty: (prev[p.id]?.qty || 0) + 1 },
                          }));
                          handleTabClick('new_order');
                        }}
                        className="w-full py-1.5 bg-rose-50 hover:bg-rose-100 text-rose-700 text-xs font-bold rounded-lg transition text-center cursor-pointer"
                      >
                        + Add to Order
                      </button>
                    </div>
                  );
                })}
            </div>
          </div>
        </div>
      )}

      {/* MODAL: ADD RETAILER */}
      {showAddRetailerModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 shadow-xl border border-slate-200">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold text-slate-900">Add New Retailer to Beat</h3>
              <button
                onClick={() => setShowAddRetailerModal(false)}
                className="text-slate-400 hover:text-slate-600 font-bold p-1 cursor-pointer"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateRetailer} className="space-y-3 text-xs">
              <div>
                <label className="font-bold text-slate-700 block mb-1">Shop Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Rameshwar Provision Store"
                  value={newRetailerName}
                  onChange={(e) => setNewRetailerName(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Owner Contact Name</label>
                <input
                  type="text"
                  placeholder="e.g. Rameshwar Lal"
                  value={newRetailerOwner}
                  onChange={(e) => setNewRetailerOwner(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Phone Number *</label>
                  <input
                    type="tel"
                    required
                    placeholder="+91 98290 00000"
                    value={newRetailerPhone}
                    onChange={(e) => setNewRetailerPhone(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Beat Route</label>
                  <select
                    value={newRetailerBeat}
                    onChange={(e) => setNewRetailerBeat(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                  >
                    <option value="Beat-01 Mandore Circle">Beat-01 Mandore</option>
                    <option value="Beat-02 Sojati Gate Hub">Beat-02 Sojati Gate</option>
                    <option value="Beat-03 Paota Sub-Market">Beat-03 Paota</option>
                    <option value="Beat-04 Sardarpura Commercial">Beat-04 Sardarpura</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Address / Landmark</label>
                <input
                  type="text"
                  placeholder="Main Market Road"
                  value={newRetailerAddress}
                  onChange={(e) => setNewRetailerAddress(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowAddRetailerModal(false)}
                  className="px-4 py-2 text-slate-600 font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-rose-600 hover:bg-rose-700 text-white rounded-xl font-bold"
                >
                  Save Retailer
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
