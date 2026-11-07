'use client';

import { useState } from 'react';
import {
  ProductItem,
  InwardReceipt,
  TruckFleet,
  OrderItem,
  PackagingUnit
} from '@/lib/types';
import {
  Warehouse,
  Truck,
  Package,
  Calendar,
  AlertTriangle,
  Plus,
  ArrowRight,
  CheckCircle2,
  FileText,
  Clock,
  ShieldCheck,
  Search,
  Check,
  Layers,
  TrendingUp,
  RefreshCw
} from 'lucide-react';

interface WarehouseViewProps {
  products: ProductItem[];
  setProducts: React.Dispatch<React.SetStateAction<ProductItem[]>>;
  inwardReceipts: InwardReceipt[];
  setInwardReceipts: React.Dispatch<React.SetStateAction<InwardReceipt[]>>;
  fleet: TruckFleet[];
  setFleet: React.Dispatch<React.SetStateAction<TruckFleet[]>>;
  orders: OrderItem[];
  setOrders: React.Dispatch<React.SetStateAction<OrderItem[]>>;
  activeSubTab?: 'godown' | 'inward' | 'pick_pack' | 'load_van';
  onSubTabChange?: (tab: 'godown' | 'inward' | 'pick_pack' | 'load_van') => void;
  onServerInward?: (productId: string, boxes: number, notes: string) => Promise<void>;
  onServerPack?: (orderId: string, productId: string) => Promise<void>;
}

export default function WarehouseView({
  products,
  setProducts,
  inwardReceipts,
  setInwardReceipts,
  fleet,
  setFleet,
  orders,
  setOrders,
  activeSubTab = 'godown',
  onSubTabChange,
  onServerInward,
  onServerPack,
}: WarehouseViewProps) {
  const [subTab, setSubTab] = useState<'godown' | 'inward' | 'pick_pack' | 'load_van'>(activeSubTab);

  const handleTabClick = (t: 'godown' | 'inward' | 'pick_pack' | 'load_van') => {
    setSubTab(t);
    if (onSubTabChange) onSubTabChange(t);
  };

  // Stock Subtab View Filter
  const [stockView, setStockView] = useState<'godown' | 'truck' | 'expiry'>('godown');
  const [searchQuery, setSearchQuery] = useState('');

  // Add SKU Modal State
  const [showAddSkuModal, setShowAddSkuModal] = useState(false);
  const [newSku, setNewSku] = useState({
    id: '',
    name: '',
    hindiName: '',
    category: 'Snacks & Extruded',
    mrpRupees: '10',
    piecePricePaise: '850',
    stripQty: '12',
    boxQty: '96',
    initialGodownStock: '50',
    batchNumber: 'LOT-2026-N01',
    expiryDate: '2027-03-31',
    reorderLevelBoxes: '30',
  });

  // Manual Inward Receipt (GRN) Form State
  const [inwardTruck, setInwardTruck] = useState('RJ-19-GA-1102');
  const [inwardChallan, setInwardChallan] = useState('CH-2026-8820');
  const [inwardSupplier, setInwardSupplier] = useState('PepsiCo India Holdings Pvt Ltd');
  const [inwardSku, setInwardSku] = useState('KURK-01');
  const [inwardBoxes, setInwardBoxes] = useState('50');
  const [inwardBatch, setInwardBatch] = useState('LOT-2026-KM02');
  const [inwardExpiry, setInwardExpiry] = useState('2027-04-15');
  const [showInwardConfirmDialog, setShowInwardConfirmDialog] = useState(false);
  const [inwardSuccessBanner, setInwardSuccessBanner] = useState<string | null>(null);

  // Load Van / Truck Transfer State
  const [selectedTransferTruck, setSelectedTransferTruck] = useState(fleet[0]?.plateNumber || 'RJ-19-GA-1102');
  const [transferSku, setTransferSku] = useState(products[0]?.id || 'KURK-01');
  const [transferBoxes, setTransferBoxes] = useState('10');
  const [transferSuccess, setTransferSuccess] = useState<string | null>(null);

  // Computed Totals
  const totalGodownBoxes = products.reduce((acc, p) => acc + p.godownStockBoxes, 0);
  const totalTruckBoxes = products.reduce((acc, p) => acc + p.carStockBoxes, 0);
  const totalValuationLakhs = (
    products.reduce((acc, p) => acc + p.godownStockBoxes * p.boxQty * (p.piecePricePaise / 100), 0) / 100000
  ).toFixed(2);

  const nearExpiryProducts = products.filter((p) => {
    const exp = new Date(p.expiryDate);
    const now = new Date();
    const diffDays = Math.ceil((exp.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    return diffDays <= 45;
  });

  // Handler: Add New SKU
  const handleCreateSku = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newSku.id.trim() || !newSku.name.trim()) {
      alert('Please enter SKU Code and Product Name');
      return;
    }

    const created: ProductItem = {
      id: newSku.id.trim().toUpperCase(),
      name: newSku.name.trim(),
      hindiName: newSku.hindiName.trim() || newSku.name.trim(),
      category: newSku.category,
      mrpRupees: parseFloat(newSku.mrpRupees) || 10,
      piecePricePaise: parseInt(newSku.piecePricePaise) || 850,
      stripQty: parseInt(newSku.stripQty) || 12,
      boxQty: parseInt(newSku.boxQty) || 96,
      gstRate: 12.0,
      godownStockBoxes: parseInt(newSku.initialGodownStock) || 0,
      carStockBoxes: 0,
      batchNumber: newSku.batchNumber.trim(),
      expiryDate: newSku.expiryDate,
      reorderLevelBoxes: parseInt(newSku.reorderLevelBoxes) || 20,
      badge: 'New SKU',
    };

    setProducts((prev) => [created, ...prev]);
    setShowAddSkuModal(false);
    alert(`SKU ${created.name} (${created.id}) created with ${created.godownStockBoxes} Boxes in Central Godown!`);
  };

  // Handler: Commit Inward Receipt
  const handleExecuteInward = () => {
    const boxes = parseInt(inwardBoxes) || 0;
    if (boxes <= 0) {
      alert('Please enter valid box count (> 0)');
      return;
    }

    const targetProduct = products.find((p) => p.id === inwardSku) || products[0];
    const newReceipt: InwardReceipt = {
      id: `INW-${Date.now().toString().slice(-4)}`,
      challanNumber: inwardChallan,
      truckPlate: inwardTruck,
      supplierName: inwardSupplier,
      productId: targetProduct.id,
      productName: targetProduct.name,
      boxesReceived: boxes,
      batchNumber: inwardBatch,
      expiryDate: inwardExpiry,
      timestamp: new Date().toISOString().replace('T', ' ').slice(0, 16),
    };

    // Update Central Godown stock (+ boxes)
    setProducts((prev) =>
      prev.map((p) => {
        if (p.id === targetProduct.id) {
          return {
            ...p,
            godownStockBoxes: p.godownStockBoxes + boxes,
            batchNumber: inwardBatch || p.batchNumber,
            expiryDate: inwardExpiry || p.expiryDate,
          };
        }
        return p;
      })
    );

    if (onServerInward) {
      onServerInward(targetProduct.id, boxes, `GRN Inward Challan ${inwardChallan} from ${inwardSupplier}`).catch(console.error);
    }

    setInwardReceipts((prev) => [newReceipt, ...prev]);
    setShowInwardConfirmDialog(false);
    setInwardSuccessBanner(
      `GRN Success: +${boxes} Boxes of ${targetProduct.name} posted to Central Godown! Total: ${targetProduct.godownStockBoxes + boxes} Boxes`
    );
    setTimeout(() => setInwardSuccessBanner(null), 5000);
  };

  // Handler: Load Van / Transfer to Truck
  const handleExecuteTransfer = (e: React.FormEvent) => {
    e.preventDefault();
    const qty = parseInt(transferBoxes) || 0;
    if (qty <= 0) {
      alert('Transfer boxes must be > 0');
      return;
    }

    const prod = products.find((p) => p.id === transferSku);
    if (!prod) return;

    if (prod.godownStockBoxes < qty) {
      alert(`Cannot transfer ${qty} boxes. Godown only has ${prod.godownStockBoxes} boxes available.`);
      return;
    }

    // Conservation invariant: - Godown stock, + Truck stock
    setProducts((prev) =>
      prev.map((p) => {
        if (p.id === transferSku) {
          return {
            ...p,
            godownStockBoxes: p.godownStockBoxes - qty,
            carStockBoxes: p.carStockBoxes + qty,
          };
        }
        return p;
      })
    );

    // Update Truck Fleet manifest
    setFleet((prev) =>
      prev.map((t) => {
        if (t.plateNumber === selectedTransferTruck) {
          const cur = t.stockMap[transferSku] || 0;
          return {
            ...t,
            loadedBoxes: t.loadedBoxes + qty,
            stockMap: {
              ...t.stockMap,
              [transferSku]: cur + qty,
            },
          };
        }
        return t;
      })
    );

    setTransferSuccess(
      `Transferred ${qty} Boxes of ${prod.name} from Central Godown to Truck ${selectedTransferTruck}!`
    );
    setTimeout(() => setTransferSuccess(null), 4000);
  };

  // Handler: Pack & Assign Order
  const handlePackOrder = (orderId: string, truckPlate: string) => {
    setOrders((prev) =>
      prev.map((o) => {
        if (o.id === orderId) {
          if (onServerPack) {
            const prodId = o.items[0]?.productId || 'P1';
            onServerPack(orderId, prodId).catch(console.error);
          }
          return {
            ...o,
            status: 'PACKED',
            assignedTruckPlate: truckPlate,
          };
        }
        return o;
      })
    );
    alert(`Order ${orderId} packed and assigned to ${truckPlate}!`);
  };

  // Filtered Products for Catalog
  const filteredProducts = products.filter(
    (p) =>
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.hindiName.includes(searchQuery)
  );

  return (
    <div className="space-y-4">
      {/* Role Navigation Sub-tabs */}
      <div className="bg-white rounded-2xl border border-slate-200 p-1.5 flex items-center gap-1 shadow-xs overflow-x-auto scrollbar-none">
        <button
          onClick={() => handleTabClick('godown')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-2 cursor-pointer ${
            subTab === 'godown'
              ? 'bg-blue-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
          }`}
        >
          <Warehouse className="w-4 h-4" />
          <span>Godown Stock</span>
        </button>

        <button
          onClick={() => handleTabClick('inward')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-2 cursor-pointer ${
            subTab === 'inward'
              ? 'bg-blue-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
          }`}
        >
          <Layers className="w-4 h-4" />
          <span>Inward (GRN)</span>
          {inwardReceipts.length > 0 && (
            <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-white/20 text-white">
              {inwardReceipts.length}
            </span>
          )}
        </button>

        <button
          onClick={() => handleTabClick('pick_pack')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-2 cursor-pointer ${
            subTab === 'pick_pack'
              ? 'bg-blue-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
          }`}
        >
          <Package className="w-4 h-4" />
          <span>Pick & Pack</span>
          <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-amber-100 text-amber-800 font-bold">
            {orders.filter((o) => o.status === 'APPROVED' || o.status === 'PICKING').length}
          </span>
        </button>

        <button
          onClick={() => handleTabClick('load_van')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-2 cursor-pointer ${
            subTab === 'load_van'
              ? 'bg-blue-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
          }`}
        >
          <Truck className="w-4 h-4" />
          <span>Load Van</span>
        </button>
      </div>

      {/* Success Notification Banners */}
      {inwardSuccessBanner && (
        <div className="p-3.5 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-xs font-semibold flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>{inwardSuccessBanner}</span>
        </div>
      )}

      {transferSuccess && (
        <div className="p-3.5 bg-blue-50 border border-blue-200 rounded-xl text-blue-800 text-xs font-semibold flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-4 h-4 text-blue-600 shrink-0" />
          <span>{transferSuccess}</span>
        </div>
      )}

      {/* TAB 1: GODOWN & TRUCK STOCK */}
      {subTab === 'godown' && (
        <div className="space-y-4">
          {/* Warehouse Hero Banner & KPIs */}
          <div className="bg-gradient-to-r from-[#1E293B] to-[#0F172A] rounded-2xl p-5 text-white shadow-sm border border-slate-800">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-4">
              <div>
                <div className="flex items-center gap-2">
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wide bg-blue-500/20 text-blue-300 border border-blue-400/30">
                    Central Godown Jodhpur
                  </span>
                  <span className="text-xs text-slate-400">Warehouse Master Inventory</span>
                </div>
                <h2 className="text-xl sm:text-2xl font-black tracking-tight mt-1">
                  Godown & Truck Fleet Inventory
                </h2>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setShowAddSkuModal(true)}
                  className="px-3.5 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 shadow-sm transition cursor-pointer"
                >
                  <Plus className="w-4 h-4" />
                  <span>+ Add SKU</span>
                </button>

                <button
                  onClick={() => handleTabClick('inward')}
                  className="px-3.5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 shadow-sm transition cursor-pointer"
                >
                  <Layers className="w-4 h-4" />
                  <span>Inward Entry</span>
                </button>
              </div>
            </div>

            {/* KPI 3-Pillar Cards */}
            <div className="grid grid-cols-3 gap-3 pt-3 border-t border-slate-700/60">
              <div className="bg-slate-800/60 rounded-xl p-3 border border-slate-700/50">
                <span className="text-[11px] text-slate-400 block font-medium">Central Godown</span>
                <span className="text-lg sm:text-xl font-black text-white mt-0.5 block">
                  {totalGodownBoxes} <span className="text-xs font-normal text-slate-400">Boxes</span>
                </span>
              </div>

              <div className="bg-slate-800/60 rounded-xl p-3 border border-slate-700/50">
                <span className="text-[11px] text-slate-400 block font-medium">Truck Fleet Stock</span>
                <span className="text-lg sm:text-xl font-black text-amber-400 mt-0.5 block">
                  {totalTruckBoxes} <span className="text-xs font-normal text-slate-400">Boxes</span>
                </span>
              </div>

              <div className="bg-slate-800/60 rounded-xl p-3 border border-slate-700/50">
                <span className="text-[11px] text-slate-400 block font-medium">Godown Valuation</span>
                <span className="text-lg sm:text-xl font-black text-emerald-400 mt-0.5 block">
                  ₹{totalValuationLakhs} <span className="text-xs font-normal text-slate-400">Lakhs</span>
                </span>
              </div>
            </div>
          </div>

          {/* Sub-view Toggle & Search */}
          <div className="bg-white rounded-2xl border border-slate-200 p-4 shadow-xs">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
              {/* Toggle Stock Mode */}
              <div className="flex items-center bg-slate-100 p-1 rounded-xl">
                <button
                  onClick={() => setStockView('godown')}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer ${
                    stockView === 'godown' ? 'bg-white text-slate-900 shadow-xs' : 'text-slate-600'
                  }`}
                >
                  Central Godown ({totalGodownBoxes} Bxs)
                </button>
                <button
                  onClick={() => setStockView('truck')}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer ${
                    stockView === 'truck' ? 'bg-white text-slate-900 shadow-xs' : 'text-slate-600'
                  }`}
                >
                  Truck Fleet ({totalTruckBoxes} Bxs)
                </button>
                <button
                  onClick={() => setStockView('expiry')}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer flex items-center gap-1 ${
                    stockView === 'expiry' ? 'bg-white text-rose-700 shadow-xs' : 'text-slate-600'
                  }`}
                >
                  <AlertTriangle className="w-3.5 h-3.5 text-amber-500" />
                  <span>Expiry Radar ({nearExpiryProducts.length})</span>
                </button>
              </div>

              {/* Search Bar */}
              <div className="relative min-w-[220px]">
                <Search className="w-4 h-4 absolute left-3 top-2.5 text-slate-400" />
                <input
                  type="text"
                  placeholder="Search SKU or Hindi Name..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-9 pr-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-1 focus:ring-blue-500 focus:bg-white"
                />
              </div>
            </div>

            {/* EXPIRY RADAR VIEW */}
            {stockView === 'expiry' && (
              <div className="space-y-3">
                <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-amber-800 text-xs">
                  <span className="font-bold">Expiry Radar Active:</span> Highlighting batches expiring within 45 days. Prioritize loading these batches to trucks first (FIFO enforcement).
                </div>

                <div className="divide-y divide-slate-100">
                  {nearExpiryProducts.map((p) => (
                    <div key={p.id} className="py-3 flex items-center justify-between">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-bold text-slate-900">{p.name}</span>
                          <span className="text-[10px] bg-rose-100 text-rose-700 font-extrabold px-2 py-0.5 rounded-full">
                            Expires {p.expiryDate}
                          </span>
                        </div>
                        <p className="text-[11px] text-slate-500">
                          Batch: <span className="font-semibold text-slate-700">{p.batchNumber}</span> • Godown Stock: <span className="font-bold text-slate-900">{p.godownStockBoxes} Boxes</span>
                        </p>
                      </div>

                      <button
                        onClick={() => {
                          setTransferSku(p.id);
                          handleTabClick('load_van');
                        }}
                        className="px-3 py-1.5 bg-amber-500 hover:bg-amber-600 text-white rounded-lg text-xs font-bold flex items-center gap-1 cursor-pointer"
                      >
                        <Truck className="w-3.5 h-3.5" />
                        <span>Dispatch to Truck</span>
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* PRODUCT STOCK CARDS (Godown or Truck) */}
            {stockView !== 'expiry' && (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                {filteredProducts.map((prod) => {
                  const isLow = prod.godownStockBoxes <= prod.reorderLevelBoxes;
                  const displayStock = stockView === 'godown' ? prod.godownStockBoxes : prod.carStockBoxes;
                  const boxValueRupees = (prod.boxQty * (prod.piecePricePaise / 100)).toFixed(0);

                  return (
                    <div
                      key={prod.id}
                      className="bg-white border border-slate-200 rounded-xl p-4 hover:border-slate-300 transition shadow-2xs space-y-3"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <div className="flex items-center gap-1.5">
                            <span className="text-xs font-extrabold text-blue-600 bg-blue-50 px-2 py-0.5 rounded-md">
                              {prod.id}
                            </span>
                            {prod.badge && (
                              <span className="text-[10px] font-bold text-emerald-700 bg-emerald-50 px-1.5 py-0.5 rounded">
                                {prod.badge}
                              </span>
                            )}
                          </div>
                          <h4 className="text-sm font-bold text-slate-900 mt-1">{prod.name}</h4>
                          <p className="text-xs text-slate-500">{prod.hindiName}</p>
                        </div>

                        <div className="text-right">
                          <span className="text-xs text-slate-400 block font-medium">
                            {stockView === 'godown' ? 'Godown' : 'Trucks'}
                          </span>
                          <span
                            className={`text-xl font-black block ${
                              isLow && stockView === 'godown' ? 'text-rose-600' : 'text-slate-900'
                            }`}
                          >
                            {displayStock}
                            <span className="text-xs font-normal text-slate-500 ml-1">Bxs</span>
                          </span>
                        </div>
                      </div>

                      {/* Stock breakdown pill bar */}
                      <div className="bg-slate-50 rounded-lg p-2.5 text-[11px] grid grid-cols-3 gap-1 border border-slate-100">
                        <div>
                          <span className="text-slate-400 block">Master Box</span>
                          <span className="font-bold text-slate-800">{prod.boxQty} Pcs</span>
                        </div>
                        <div>
                          <span className="text-slate-400 block">Strip / Ladi</span>
                          <span className="font-bold text-slate-800">{prod.stripQty} Pcs</span>
                        </div>
                        <div>
                          <span className="text-slate-400 block">Wholesale Rate</span>
                          <span className="font-bold text-emerald-700">₹{boxValueRupees}/Bx</span>
                        </div>
                      </div>

                      {/* Batch & Reorder warning */}
                      <div className="flex items-center justify-between text-[11px] text-slate-500 pt-1">
                        <span>Batch: <strong className="text-slate-700">{prod.batchNumber}</strong></span>
                        {isLow ? (
                          <span className="text-rose-600 font-bold flex items-center gap-1">
                            <AlertTriangle className="w-3 h-3" /> Reorder Level ({prod.reorderLevelBoxes})
                          </span>
                        ) : (
                          <span className="text-emerald-600 font-medium">Safe Stock</span>
                        )}
                      </div>

                      {/* Action buttons */}
                      <div className="pt-2 border-t border-slate-100 flex items-center gap-2">
                        <button
                          onClick={() => {
                            setInwardSku(prod.id);
                            handleTabClick('inward');
                          }}
                          className="flex-1 py-1.5 bg-blue-50 hover:bg-blue-100 text-blue-700 text-xs font-bold rounded-lg transition text-center cursor-pointer"
                        >
                          + Inward
                        </button>
                        <button
                          onClick={() => {
                            setTransferSku(prod.id);
                            handleTabClick('load_van');
                          }}
                          className="flex-1 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-lg transition text-center cursor-pointer"
                        >
                          Transfer to Van
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {/* TAB 2: MANUAL INWARD RECEIPT (GRN) */}
      {subTab === 'inward' && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs">
            <div className="max-w-2xl">
              <div className="flex items-center gap-2 text-xs font-bold text-blue-600 uppercase tracking-wider mb-1">
                <Layers className="w-4 h-4" />
                <span>Central Godown Stock Receipt</span>
              </div>
              <h3 className="text-lg font-black text-slate-900">
                Manual Inward Entry (माल आवक रसीद)
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Record incoming truck shipments of master boxes directly into Central Godown stock.
              </p>
            </div>

            <form
              onSubmit={(e) => {
                e.preventDefault();
                setShowInwardConfirmDialog(true);
              }}
              className="mt-5 space-y-4 max-w-2xl"
            >
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Truck / Vehicle Plate No. *
                  </label>
                  <input
                    type="text"
                    required
                    value={inwardTruck}
                    onChange={(e) => setInwardTruck(e.target.value)}
                    placeholder="e.g. RJ-19-GA-1102"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-semibold"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Challan / Bilty Number *
                  </label>
                  <input
                    type="text"
                    required
                    value={inwardChallan}
                    onChange={(e) => setInwardChallan(e.target.value)}
                    placeholder="e.g. CH-2026-8820"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-semibold"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Supplier / Factory Source *
                </label>
                <input
                  type="text"
                  required
                  value={inwardSupplier}
                  onChange={(e) => setInwardSupplier(e.target.value)}
                  placeholder="e.g. PepsiCo India Holdings Pvt Ltd"
                  className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-semibold"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Product SKU *
                  </label>
                  <select
                    value={inwardSku}
                    onChange={(e) => setInwardSku(e.target.value)}
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-semibold"
                  >
                    {products.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} ({p.id}) - Current: {p.godownStockBoxes} Bxs
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Boxes Received (+ Godown Stock) *
                  </label>
                  <input
                    type="number"
                    min="1"
                    required
                    value={inwardBoxes}
                    onChange={(e) => setInwardBoxes(e.target.value)}
                    placeholder="e.g. 50"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-bold text-blue-700"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Batch / Lot Number *
                  </label>
                  <input
                    type="text"
                    required
                    value={inwardBatch}
                    onChange={(e) => setInwardBatch(e.target.value)}
                    placeholder="e.g. LOT-2026-KM02"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-semibold"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Expiry Date *
                  </label>
                  <input
                    type="date"
                    required
                    value={inwardExpiry}
                    onChange={(e) => setInwardExpiry(e.target.value)}
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-semibold"
                  />
                </div>
              </div>

              <button
                type="submit"
                className="w-full py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-xs font-bold shadow-sm transition flex items-center justify-center gap-2 cursor-pointer"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>Review & Post to Central Godown</span>
              </button>
            </form>
          </div>

          {/* Recent Inward Receipts Table */}
          <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs">
            <h4 className="text-sm font-bold text-slate-900 mb-3">
              Recent Inward Receipts Log (GRN History)
            </h4>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-slate-200 text-slate-400 font-semibold">
                    <th className="pb-2.5">Challan No</th>
                    <th className="pb-2.5">Truck Plate</th>
                    <th className="pb-2.5">Product</th>
                    <th className="pb-2.5">Inward Boxes</th>
                    <th className="pb-2.5">Batch</th>
                    <th className="pb-2.5">Date & Time</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {inwardReceipts.map((rec) => (
                    <tr key={rec.id} className="hover:bg-slate-50 transition">
                      <td className="py-2.5 font-bold text-blue-600">{rec.challanNumber}</td>
                      <td className="py-2.5 text-slate-700 font-medium">{rec.truckPlate}</td>
                      <td className="py-2.5 font-bold text-slate-900">{rec.productName}</td>
                      <td className="py-2.5 font-black text-emerald-600">+{rec.boxesReceived} Bxs</td>
                      <td className="py-2.5 text-slate-500">{rec.batchNumber}</td>
                      <td className="py-2.5 text-slate-400">{rec.timestamp}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* TAB 3: PICK & PACK ORDERS */}
      {subTab === 'pick_pack' && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-lg font-black text-slate-900">
                  Pick & Pack Queue (ऑर्डर पैकिंग सूची)
                </h3>
                <p className="text-xs text-slate-500">
                  Orders submitted by Sales Executives. Pack line items and assign to delivery trucks.
                </p>
              </div>

              <span className="text-xs font-bold px-2.5 py-1 rounded-full bg-blue-50 text-blue-700">
                {orders.filter((o) => o.status === 'APPROVED' || o.status === 'PICKING').length} Orders Pending Packing
              </span>
            </div>

            <div className="space-y-3">
              {orders
                .filter((o) => o.status === 'APPROVED' || o.status === 'PICKING' || o.status === 'PACKED')
                .map((order) => {
                  const isPacked = order.status === 'PACKED';

                  return (
                    <div
                      key={order.id}
                      className={`border rounded-xl p-4 transition ${
                        isPacked ? 'bg-slate-50 border-slate-200 opacity-80' : 'bg-white border-blue-200 shadow-2xs'
                      }`}
                    >
                      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-3">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-xs font-extrabold text-blue-700 bg-blue-100 px-2 py-0.5 rounded">
                              {order.orderCode}
                            </span>
                            <span
                              className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                                isPacked
                                  ? 'bg-emerald-100 text-emerald-800'
                                  : 'bg-amber-100 text-amber-800'
                              }`}
                            >
                              {order.status}
                            </span>
                          </div>
                          <h4 className="text-sm font-bold text-slate-900 mt-1">{order.retailerName}</h4>
                          <p className="text-xs text-slate-500">{order.retailerAddress}</p>
                        </div>

                        <div className="text-right">
                          <span className="text-xs text-slate-400">Total Invoice</span>
                          <span className="text-base font-extrabold text-slate-900 block">
                            ₹{order.totalAmountRupees.toFixed(2)}
                          </span>
                        </div>
                      </div>

                      {/* Items to Pick */}
                      <div className="bg-slate-50 rounded-xl p-3 space-y-1.5 border border-slate-100 mb-3 text-xs">
                        <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">
                          Items to Pick & Pack:
                        </span>
                        {order.items.map((item, idx) => (
                          <div key={idx} className="flex items-center justify-between py-1">
                            <span className="font-medium text-slate-800">
                              {item.productName}
                            </span>
                            <span className="font-extrabold text-blue-700 bg-white px-2 py-0.5 rounded border border-slate-200">
                              {item.quantity} {item.unit}
                            </span>
                          </div>
                        ))}
                      </div>

                      {/* Action buttons */}
                      <div className="flex items-center justify-between gap-2 pt-2 border-t border-slate-100">
                        <span className="text-xs text-slate-500">
                          Assigned Truck: <strong className="text-slate-800">{order.assignedTruckPlate || 'Unassigned'}</strong>
                        </span>

                        {!isPacked ? (
                          <button
                            onClick={() => handlePackOrder(order.id, fleet[0]?.plateNumber || 'RJ-19-GA-1102')}
                            className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 cursor-pointer"
                          >
                            <Check className="w-4 h-4" />
                            <span>Mark Packed & Ready</span>
                          </button>
                        ) : (
                          <span className="text-xs font-bold text-emerald-700 flex items-center gap-1">
                            <CheckCircle2 className="w-4 h-4" /> Ready for Van Dispatch
                          </span>
                        )}
                      </div>
                    </div>
                  );
                })}
            </div>
          </div>
        </div>
      )}

      {/* TAB 4: LOAD VAN / MULTI-TRUCK TRANSFER */}
      {subTab === 'load_van' && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs">
            <div className="max-w-2xl">
              <div className="flex items-center gap-2 text-xs font-bold text-amber-600 uppercase tracking-wider mb-1">
                <Truck className="w-4 h-4" />
                <span>Godown to Truck Loading</span>
              </div>
              <h3 className="text-lg font-black text-slate-900">
                Load Van / Truck Fleet Stock Transfer
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Transfers inventory from Central Godown into delivery trucks (- Godown boxes, + Truck boxes).
              </p>
            </div>

            <form onSubmit={handleExecuteTransfer} className="mt-5 space-y-4 max-w-2xl">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Select Delivery Truck *
                  </label>
                  <select
                    value={selectedTransferTruck}
                    onChange={(e) => setSelectedTransferTruck(e.target.value)}
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-semibold"
                  >
                    {fleet.map((t) => (
                      <option key={t.plateNumber} value={t.plateNumber}>
                        {t.plateNumber} - {t.driverName} ({t.loadedBoxes}/{t.capacityBoxes} Bxs)
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">
                    Select Product SKU *
                  </label>
                  <select
                    value={transferSku}
                    onChange={(e) => setTransferSku(e.target.value)}
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-semibold"
                  >
                    {products.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} (Godown: {p.godownStockBoxes} Bxs)
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Transfer Quantity (Boxes) *
                </label>
                <input
                  type="number"
                  min="1"
                  required
                  value={transferBoxes}
                  onChange={(e) => setTransferBoxes(e.target.value)}
                  placeholder="e.g. 10"
                  className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 font-bold text-amber-700"
                />
              </div>

              <button
                type="submit"
                className="w-full py-3 bg-amber-600 hover:bg-amber-700 text-white rounded-xl text-xs font-bold shadow-sm transition flex items-center justify-center gap-2 cursor-pointer"
              >
                <Truck className="w-4 h-4" />
                <span>Transfer to Truck (- Godown, + Truck)</span>
              </button>
            </form>
          </div>

          {/* Current Truck Fleet Manifest */}
          <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs">
            <h4 className="text-sm font-bold text-slate-900 mb-3">
              Live Truck Fleet Manifest
            </h4>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              {fleet.map((trk) => (
                <div key={trk.plateNumber} className="border border-slate-200 rounded-xl p-4 bg-slate-50 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-extrabold text-blue-700 bg-white px-2 py-0.5 rounded border border-slate-200">
                      {trk.plateNumber}
                    </span>
                    <span className="text-xs font-bold text-slate-800">
                      {trk.loadedBoxes} / {trk.capacityBoxes} Bxs
                    </span>
                  </div>
                  <p className="text-xs text-slate-600 font-medium">Driver: {trk.driverName}</p>
                  <p className="text-[11px] text-slate-400">{trk.model}</p>

                  <div className="pt-2 border-t border-slate-200 text-[11px] space-y-1">
                    <span className="font-bold text-slate-600 block">Loaded SKUs:</span>
                    {Object.entries(trk.stockMap).map(([sku, bxs]) => (
                      <div key={sku} className="flex justify-between text-slate-700">
                        <span>{sku}</span>
                        <span className="font-bold">{bxs} Bxs</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* MODAL: ADD NEW SKU */}
      {showAddSkuModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-5 sm:p-6 shadow-xl border border-slate-200 animate-in zoom-in-95">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-base font-bold text-slate-900">Add New SKU to Central Godown</h3>
                <p className="text-xs text-slate-500">Configure master box, strips, rates, and batch</p>
              </div>
              <button
                onClick={() => setShowAddSkuModal(false)}
                className="text-slate-400 hover:text-slate-600 text-sm font-bold p-1 cursor-pointer"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateSku} className="space-y-3 text-xs">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">SKU Code *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. KURK-03"
                    value={newSku.id}
                    onChange={(e) => setNewSku({ ...newSku, id: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Category *</label>
                  <input
                    type="text"
                    required
                    value={newSku.category}
                    onChange={(e) => setNewSku({ ...newSku, category: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                  />
                </div>
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Product Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Kurkure Green Chutney"
                  value={newSku.name}
                  onChange={(e) => setNewSku({ ...newSku, name: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Hindi Display Name</label>
                <input
                  type="text"
                  placeholder="कुरकुरे ग्रीन चटनी (₹10 पैक)"
                  value={newSku.hindiName}
                  onChange={(e) => setNewSku({ ...newSku, hindiName: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                />
              </div>

              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">MRP (₹)</label>
                  <input
                    type="number"
                    value={newSku.mrpRupees}
                    onChange={(e) => setNewSku({ ...newSku, mrpRupees: e.target.value })}
                    className="w-full px-2.5 py-1.5 bg-slate-50 border border-slate-200 rounded-xl"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Pcs/Box</label>
                  <input
                    type="number"
                    value={newSku.boxQty}
                    onChange={(e) => setNewSku({ ...newSku, boxQty: e.target.value })}
                    className="w-full px-2.5 py-1.5 bg-slate-50 border border-slate-200 rounded-xl"
                  />
                </div>
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Initial Bxs</label>
                  <input
                    type="number"
                    value={newSku.initialGodownStock}
                    onChange={(e) => setNewSku({ ...newSku, initialGodownStock: e.target.value })}
                    className="w-full px-2.5 py-1.5 bg-slate-50 border border-slate-200 rounded-xl font-bold text-blue-600"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowAddSkuModal(false)}
                  className="px-4 py-2 text-slate-600 hover:bg-slate-100 rounded-xl font-bold cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold shadow-xs cursor-pointer"
                >
                  Create SKU
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CONFIRMATION DIALOG: INWARD RECEIPT */}
      {showInwardConfirmDialog && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 animate-in zoom-in-95">
            <div className="flex items-center gap-2 text-blue-600 mb-2">
              <ShieldCheck className="w-5 h-5" />
              <h3 className="text-base font-bold text-slate-900">Reconfirm Inward Receipt</h3>
            </div>
            <p className="text-xs text-slate-500 mb-4">
              Please verify incoming shipment details before posting to Central Godown ledger:
            </p>

            <div className="bg-slate-50 rounded-xl p-3.5 space-y-2 text-xs border border-slate-200 mb-5">
              <div className="flex justify-between">
                <span className="text-slate-500">Product:</span>
                <span className="font-bold text-slate-900">
                  {products.find((p) => p.id === inwardSku)?.name || inwardSku}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Inward Quantity:</span>
                <span className="font-black text-emerald-600">+{inwardBoxes} Boxes</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Current Godown Stock:</span>
                <span className="font-semibold text-slate-800">
                  {products.find((p) => p.id === inwardSku)?.godownStockBoxes || 0} Boxes
                </span>
              </div>
              <div className="flex justify-between border-t border-slate-200 pt-1.5">
                <span className="text-slate-700 font-bold">New Projected Stock:</span>
                <span className="font-black text-blue-700">
                  {(products.find((p) => p.id === inwardSku)?.godownStockBoxes || 0) +
                    (parseInt(inwardBoxes) || 0)}{' '}
                  Boxes
                </span>
              </div>
              <div className="flex justify-between text-[11px] text-slate-400">
                <span>Truck Plate:</span>
                <span>{inwardTruck}</span>
              </div>
              <div className="flex justify-between text-[11px] text-slate-400">
                <span>Challan:</span>
                <span>{inwardChallan}</span>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => setShowInwardConfirmDialog(false)}
                className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl cursor-pointer"
              >
                Back / Edit
              </button>
              <button
                type="button"
                onClick={handleExecuteInward}
                className="px-5 py-2 text-xs font-bold bg-blue-600 hover:bg-blue-700 text-white rounded-xl shadow-xs cursor-pointer flex items-center gap-1.5"
              >
                <Check className="w-4 h-4" />
                <span>Confirm & Post Stock</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
