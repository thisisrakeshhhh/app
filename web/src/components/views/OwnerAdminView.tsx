'use client';

import { useState } from 'react';
import {
  OrderItem,
  RetailerItem,
  ProductItem,
  CashHandoverItem,
  TruckFleet
} from '@/lib/types';
import {
  Building,
  CheckCircle2,
  Clock,
  ShieldCheck,
  TrendingUp,
  AlertTriangle,
  Wallet,
  Check,
  X,
  Store,
  DollarSign
} from 'lucide-react';

interface OwnerAdminViewProps {
  orders: OrderItem[];
  setOrders: React.Dispatch<React.SetStateAction<OrderItem[]>>;
  retailers: RetailerItem[];
  products: ProductItem[];
  handovers: CashHandoverItem[];
  setHandovers: React.Dispatch<React.SetStateAction<CashHandoverItem[]>>;
  fleet: TruckFleet[];
  activeSubTab?: 'pulse' | 'approvals' | 'handovers' | 'reports';
  onSubTabChange?: (tab: 'pulse' | 'approvals' | 'handovers' | 'reports') => void;
}

export default function OwnerAdminView({
  orders,
  setOrders,
  retailers,
  products,
  handovers,
  setHandovers,
  fleet,
  activeSubTab = 'pulse',
  onSubTabChange,
}: OwnerAdminViewProps) {
  const [subTab, setSubTab] = useState<'pulse' | 'approvals' | 'handovers' | 'reports'>(activeSubTab);

  const handleTabClick = (t: 'pulse' | 'approvals' | 'handovers' | 'reports') => {
    setSubTab(t);
    if (onSubTabChange) onSubTabChange(t);
  };

  const pendingApprovals = orders.filter((o) => o.status === 'SUBMITTED');
  const deliveredOrders = orders.filter((o) => o.status === 'DELIVERED');
  const deliveredSalesTotal = deliveredOrders.reduce((sum, o) => sum + o.totalAmountRupees, 0);
  const totalReceivables = retailers.reduce((sum, r) => sum + r.outstandingBalanceRupees, 0);
  const pendingHandovers = handovers.filter((h) => h.status === 'PENDING');

  const handleApproveOrder = (id: string) => {
    setOrders((prev) =>
      prev.map((o) => (o.id === id ? { ...o, status: 'APPROVED' } : o))
    );
    alert(`Order ${id} approved for warehouse picking!`);
  };

  const handleRejectOrder = (id: string) => {
    setOrders((prev) =>
      prev.map((o) => (o.id === id ? { ...o, status: 'REJECTED' } : o))
    );
    alert(`Order ${id} rejected.`);
  };

  const handleAcceptHandover = (id: string) => {
    setHandovers((prev) =>
      prev.map((h) => (h.id === id ? { ...h, status: 'ACCEPTED' } : h))
    );
    alert(`Handover ${id} accepted and settled into cash ledger!`);
  };

  return (
    <div className="space-y-4">
      {/* Subtab Navigation */}
      <div className="bg-white rounded-2xl border border-slate-200 p-1.5 flex items-center gap-1 shadow-xs overflow-x-auto scrollbar-none">
        <button
          onClick={() => handleTabClick('pulse')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'pulse'
              ? 'bg-purple-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Building className="w-4 h-4" />
          <span>Control Room</span>
        </button>

        <button
          onClick={() => handleTabClick('approvals')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'approvals'
              ? 'bg-purple-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <ShieldCheck className="w-4 h-4" />
          <span>Approvals Inbox</span>
          {pendingApprovals.length > 0 && (
            <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-amber-200 text-amber-900 font-extrabold">
              {pendingApprovals.length}
            </span>
          )}
        </button>

        <button
          onClick={() => handleTabClick('handovers')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'handovers'
              ? 'bg-purple-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Wallet className="w-4 h-4" />
          <span>Cash Settlements</span>
          {pendingHandovers.length > 0 && (
            <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-emerald-200 text-emerald-900 font-extrabold">
              {pendingHandovers.length}
            </span>
          )}
        </button>

        <button
          onClick={() => handleTabClick('reports')}
          className={`flex-1 min-w-[120px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'reports'
              ? 'bg-purple-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <TrendingUp className="w-4 h-4" />
          <span>Reports & Khata</span>
        </button>
      </div>

      {/* 1. CONTROL ROOM PULSE */}
      {subTab === 'pulse' && (
        <div className="space-y-4">
          <div className="bg-gradient-to-r from-purple-950 to-slate-900 rounded-2xl p-5 text-white border border-purple-800/60 shadow-sm space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-black uppercase tracking-wider bg-purple-500/20 text-purple-300 px-2 py-0.5 rounded-full border border-purple-400/30">
                Sovereign Owner Control Room
              </span>
              <span className="text-xs text-purple-200">Daily Operations Pulse</span>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-2">
              <div className="bg-white/10 rounded-xl p-3 border border-white/10">
                <span className="text-[11px] text-purple-200 block">Delivered Sales</span>
                <span className="text-lg font-black text-white mt-0.5 block">
                  ₹{deliveredSalesTotal.toFixed(0)}
                </span>
              </div>
              <div className="bg-white/10 rounded-xl p-3 border border-white/10">
                <span className="text-[11px] text-purple-200 block">Pending Approvals</span>
                <span className="text-lg font-black text-amber-300 mt-0.5 block">
                  {pendingApprovals.length}
                </span>
              </div>
              <div className="bg-white/10 rounded-xl p-3 border border-white/10">
                <span className="text-[11px] text-purple-200 block">Retailer Khata</span>
                <span className="text-lg font-black text-rose-300 mt-0.5 block">
                  ₹{totalReceivables.toFixed(0)}
                </span>
              </div>
              <div className="bg-white/10 rounded-xl p-3 border border-white/10">
                <span className="text-[11px] text-purple-200 block">Delivery Trucks</span>
                <span className="text-lg font-black text-emerald-300 mt-0.5 block">
                  {fleet.length} Active
                </span>
              </div>
            </div>
          </div>

          {/* Quick Approvals Card */}
          <div className="bg-white rounded-2xl border border-slate-200 p-4 shadow-xs">
            <h4 className="text-xs font-bold text-slate-900 uppercase tracking-wider mb-3">
              Orders Requiring Authorization ({pendingApprovals.length})
            </h4>

            {pendingApprovals.length === 0 ? (
              <p className="text-xs text-slate-400 py-3 text-center">
                All submitted orders are authorized.
              </p>
            ) : (
              <div className="divide-y divide-slate-100">
                {pendingApprovals.map((o) => (
                  <div key={o.id} className="py-3 flex items-center justify-between text-xs">
                    <div>
                      <span className="font-bold text-slate-900 block">{o.retailerName}</span>
                      <span className="text-slate-400">
                        {o.orderCode} • ₹{o.totalAmountRupees.toFixed(2)}
                      </span>
                    </div>
                    <div className="flex gap-2">
                      <button
                        onClick={() => handleRejectOrder(o.id)}
                        className="px-2.5 py-1 text-rose-600 bg-rose-50 hover:bg-rose-100 rounded-lg font-bold"
                      >
                        Reject
                      </button>
                      <button
                        onClick={() => handleApproveOrder(o.id)}
                        className="px-3 py-1 text-white bg-purple-600 hover:bg-purple-700 rounded-lg font-bold"
                      >
                        Authorize
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* 2. APPROVALS INBOX */}
      {subTab === 'approvals' && (
        <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs space-y-3">
          <h3 className="text-base font-black text-slate-900">Approvals Inbox</h3>
          <div className="space-y-3">
            {orders.map((ord) => (
              <div key={ord.id} className="border border-slate-200 rounded-xl p-3.5 flex items-center justify-between text-xs">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-extrabold text-blue-700">{ord.orderCode}</span>
                    <span className="px-2 py-0.5 rounded-full bg-slate-100 font-bold">{ord.status}</span>
                  </div>
                  <h4 className="font-bold text-slate-900 mt-1">{ord.retailerName}</h4>
                  <span className="text-slate-500">₹{ord.totalAmountRupees.toFixed(2)}</span>
                </div>

                {ord.status === 'SUBMITTED' && (
                  <div className="flex gap-2">
                    <button
                      onClick={() => handleRejectOrder(ord.id)}
                      className="px-3 py-1.5 text-rose-600 bg-rose-50 hover:bg-rose-100 rounded-lg font-bold"
                    >
                      Reject
                    </button>
                    <button
                      onClick={() => handleApproveOrder(ord.id)}
                      className="px-3 py-1.5 text-white bg-purple-600 hover:bg-purple-700 rounded-lg font-bold"
                    >
                      Approve
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 3. CASH SETTLEMENTS */}
      {subTab === 'handovers' && (
        <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs space-y-3">
          <h3 className="text-base font-black text-slate-900">Cash Settlements & Reconciliation</h3>
          <div className="divide-y divide-slate-100 text-xs">
            {handovers.map((h) => (
              <div key={h.id} className="py-3 flex items-center justify-between">
                <div>
                  <span className="font-bold text-slate-900 block">{h.driverName} ({h.truckPlate})</span>
                  <span className="text-slate-400">{h.timestamp}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className="font-black text-emerald-700">₹{h.submittedRupees.toFixed(2)}</span>
                  {h.status === 'PENDING' ? (
                    <button
                      onClick={() => handleAcceptHandover(h.id)}
                      className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg font-bold cursor-pointer"
                    >
                      Accept Cash
                    </button>
                  ) : (
                    <span className="text-emerald-700 font-bold bg-emerald-50 px-2 py-0.5 rounded">
                      Settled
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 4. REPORTS & KHATA */}
      {subTab === 'reports' && (
        <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs space-y-3">
          <h3 className="text-base font-black text-slate-900">Retailer Khata Receivables Ledger</h3>
          <div className="divide-y divide-slate-100 text-xs">
            {retailers.map((r) => (
              <div key={r.id} className="py-2.5 flex items-center justify-between">
                <div>
                  <span className="font-bold text-slate-900 block">{r.name}</span>
                  <span className="text-slate-400">{r.beat}</span>
                </div>
                <div className="text-right">
                  <span className="font-black text-rose-600 block">₹{r.outstandingBalanceRupees.toFixed(2)}</span>
                  <span className="text-[10px] text-slate-400">Limit: ₹{r.creditLimitRupees}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
