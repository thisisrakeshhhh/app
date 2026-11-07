'use client';

import { useState } from 'react';
import {
  OrderItem,
  TruckFleet,
  CashHandoverItem
} from '@/lib/types';
import {
  Truck,
  MapPin,
  CheckCircle2,
  Clock,
  ShieldCheck,
  Phone,
  Wallet,
  AlertTriangle,
  ArrowRight,
  Send,
  Check
} from 'lucide-react';

interface DeliveryViewProps {
  orders: OrderItem[];
  setOrders: React.Dispatch<React.SetStateAction<OrderItem[]>>;
  fleet: TruckFleet[];
  handovers: CashHandoverItem[];
  setHandovers: React.Dispatch<React.SetStateAction<CashHandoverItem[]>>;
  activeSubTab?: 'stops' | 'trips' | 'collections' | 'handover';
  onSubTabChange?: (tab: 'stops' | 'trips' | 'collections' | 'handover') => void;
}

export default function DeliveryView({
  orders,
  setOrders,
  fleet,
  handovers,
  setHandovers,
  activeSubTab = 'stops',
  onSubTabChange,
}: DeliveryViewProps) {
  const [subTab, setSubTab] = useState<'stops' | 'trips' | 'collections' | 'handover'>(activeSubTab);

  const handleTabClick = (t: 'stops' | 'trips' | 'collections' | 'handover') => {
    setSubTab(t);
    if (onSubTabChange) onSubTabChange(t);
  };

  const currentTruck = fleet[0] || {
    plateNumber: 'RJ-19-GA-1102',
    driverName: 'Suresh Yadav',
    model: 'Mahindra Bolero Maxi Truck',
    capacityBoxes: 250,
    loadedBoxes: 110,
    stockMap: {},
  };

  // OTP Modal State
  const [activeOtpOrder, setActiveOtpOrder] = useState<OrderItem | null>(null);
  const [otpInput, setOtpInput] = useState('');
  const [recipientName, setRecipientName] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<'CASH' | 'UPI' | 'CREDIT'>('CASH');
  const [deliverySuccessNote, setDeliverySuccessNote] = useState<string | null>(null);

  // Cash Handover State
  const [handoverAmount, setHandoverAmount] = useState('4950');

  // Computed Collections
  const deliveredOrders = orders.filter((o) => o.status === 'DELIVERED');
  const totalCashCollected = deliveredOrders.reduce((sum, o) => sum + o.totalAmountRupees, 0);

  const handleVerifyOtp = (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeOtpOrder) return;

    if (otpInput.trim() !== (activeOtpOrder.deliveryOtp || '1234') && otpInput.trim() !== '1234') {
      alert(`Invalid OTP! Please enter correct 4-digit OTP from retailer (Demo OTP: ${activeOtpOrder.deliveryOtp || '1234'})`);
      return;
    }

    setOrders((prev) =>
      prev.map((o) => {
        if (o.id === activeOtpOrder.id) {
          return {
            ...o,
            status: 'DELIVERED',
          };
        }
        return o;
      })
    );

    setDeliverySuccessNote(`Order ${activeOtpOrder.orderCode} successfully delivered with OTP verification!`);
    setActiveOtpOrder(null);
    setOtpInput('');
    setRecipientName('');
    setTimeout(() => setDeliverySuccessNote(null), 5000);
  };

  const handleCreateHandover = (e: React.FormEvent) => {
    e.preventDefault();
    const amt = parseFloat(handoverAmount) || 0;
    if (amt <= 0) {
      alert('Handover amount must be > 0');
      return;
    }

    const newHnd: CashHandoverItem = {
      id: `HND-${Date.now().toString().slice(-4)}`,
      driverName: currentTruck.driverName,
      truckPlate: currentTruck.plateNumber,
      collectedRupees: amt,
      submittedRupees: amt,
      status: 'PENDING',
      timestamp: new Date().toISOString().replace('T', ' ').slice(0, 16),
    };

    setHandovers((prev) => [newHnd, ...prev]);
    alert(`Cash handover of ₹${amt} submitted to Owner / Cashier for reconciliation!`);
  };

  return (
    <div className="space-y-4">
      {/* Subtab Navigation */}
      <div className="bg-white rounded-2xl border border-slate-200 p-1.5 flex items-center gap-1 shadow-xs overflow-x-auto scrollbar-none">
        <button
          onClick={() => handleTabClick('stops')}
          className={`flex-1 min-w-[110px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'stops'
              ? 'bg-emerald-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <MapPin className="w-4 h-4" />
          <span>Delivery Stops</span>
        </button>

        <button
          onClick={() => handleTabClick('trips')}
          className={`flex-1 min-w-[110px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'trips'
              ? 'bg-emerald-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Truck className="w-4 h-4" />
          <span>Vehicle & Trip</span>
        </button>

        <button
          onClick={() => handleTabClick('collections')}
          className={`flex-1 min-w-[110px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'collections'
              ? 'bg-emerald-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Wallet className="w-4 h-4" />
          <span>Collections</span>
        </button>

        <button
          onClick={() => handleTabClick('handover')}
          className={`flex-1 min-w-[110px] py-2.5 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 cursor-pointer ${
            subTab === 'handover'
              ? 'bg-emerald-600 text-white shadow-xs'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <ShieldCheck className="w-4 h-4" />
          <span>Cash Handover</span>
        </button>
      </div>

      {deliverySuccessNote && (
        <div className="p-3.5 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-xs font-semibold flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>{deliverySuccessNote}</span>
        </div>
      )}

      {/* 1. DELIVERY STOPS VIEW */}
      {subTab === 'stops' && (
        <div className="space-y-4">
          {/* Active Truck Header Banner */}
          <div className="bg-gradient-to-r from-emerald-900 to-teal-950 rounded-2xl p-4 sm:p-5 text-white border border-emerald-800/60 shadow-sm space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-extrabold uppercase tracking-wide bg-emerald-500/20 text-emerald-300 px-2 py-0.5 rounded-full border border-emerald-400/30">
                Assigned Vehicle: {currentTruck.plateNumber}
              </span>
              <span className="text-xs text-emerald-200">Trip 1 Active</span>
            </div>
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              <div>
                <h3 className="text-lg font-black">{currentTruck.driverName}</h3>
                <p className="text-xs text-emerald-200">{currentTruck.model}</p>
              </div>
              <div className="text-right">
                <span className="text-xs text-emerald-200 block">Cash in Custody</span>
                <span className="text-xl font-black text-amber-300">₹{totalCashCollected.toFixed(2)}</span>
              </div>
            </div>
          </div>

          {/* Stops List */}
          <div className="bg-white rounded-2xl border border-slate-200 p-4 shadow-xs space-y-3">
            <h4 className="text-xs font-bold text-slate-900 uppercase tracking-wider mb-2">
              Assigned Retailer Stops ({orders.length})
            </h4>

            <div className="space-y-3">
              {orders.map((ord, idx) => {
                const isDelivered = ord.status === 'DELIVERED';

                return (
                  <div
                    key={ord.id}
                    className={`border rounded-xl p-4 transition space-y-3 ${
                      isDelivered ? 'bg-emerald-50/40 border-emerald-200' : 'bg-white border-slate-200 shadow-2xs'
                    }`}
                  >
                    <div className="flex items-start justify-between">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <span className="w-5 h-5 rounded-full bg-slate-900 text-white text-[10px] font-bold flex items-center justify-center">
                            {idx + 1}
                          </span>
                          <span className="text-xs font-extrabold text-blue-700 bg-blue-50 px-2 py-0.5 rounded">
                            {ord.orderCode}
                          </span>
                          <span
                            className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                              isDelivered ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
                            }`}
                          >
                            {ord.status}
                          </span>
                        </div>
                        <h4 className="text-sm font-bold text-slate-900">{ord.retailerName}</h4>
                        <p className="text-xs text-slate-500 flex items-center gap-1">
                          <MapPin className="w-3.5 h-3.5" />
                          <span>{ord.retailerAddress}</span>
                        </p>
                      </div>

                      <div className="text-right">
                        <span className="text-[10px] text-slate-400 block">Collect Amount</span>
                        <span className="text-sm font-black text-slate-900">
                          ₹{ord.totalAmountRupees.toFixed(2)}
                        </span>
                      </div>
                    </div>

                    <div className="bg-slate-50 rounded-lg p-2.5 text-xs border border-slate-100 space-y-1">
                      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                        Drop Items:
                      </span>
                      {ord.items.map((i, iIdx) => (
                        <div key={iIdx} className="flex justify-between text-slate-700">
                          <span>{i.productName}</span>
                          <span className="font-bold">{i.quantity} {i.unit}</span>
                        </div>
                      ))}
                    </div>

                    <div className="flex items-center justify-between gap-2 pt-1 border-t border-slate-100">
                      <span className="text-[11px] text-slate-500">
                        Demo OTP: <strong className="text-slate-800">{ord.deliveryOtp || '1234'}</strong>
                      </span>

                      {!isDelivered ? (
                        <button
                          type="button"
                          onClick={() => {
                            setActiveOtpOrder(ord);
                            setOtpInput('');
                          }}
                          className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 cursor-pointer"
                        >
                          <ShieldCheck className="w-4 h-4" />
                          <span>Verify Delivery (OTP)</span>
                        </button>
                      ) : (
                        <span className="text-xs font-bold text-emerald-700 flex items-center gap-1">
                          <CheckCircle2 className="w-4 h-4" /> Delivered & Collected
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

      {/* 2. TRUCK & VEHICLE VIEW */}
      {subTab === 'trips' && (
        <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs space-y-4">
          <h3 className="text-base font-black text-slate-900">Vehicle Manifest & Trip Status</h3>
          <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 space-y-2 text-xs">
            <div className="flex justify-between">
              <span className="text-slate-500">Vehicle Registration:</span>
              <span className="font-bold text-slate-900">{currentTruck.plateNumber}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Model:</span>
              <span className="font-bold text-slate-900">{currentTruck.model}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Assigned Driver:</span>
              <span className="font-bold text-slate-900">{currentTruck.driverName}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Capacity & Loading:</span>
              <span className="font-bold text-emerald-700">
                {currentTruck.loadedBoxes} / {currentTruck.capacityBoxes} Boxes Loaded
              </span>
            </div>
          </div>
        </div>
      )}

      {/* 3. CASH HANDOVER VIEW */}
      {(subTab === 'collections' || subTab === 'handover') && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs">
            <h3 className="text-base font-black text-slate-900 mb-1">
              Driver Cash Handover Settlement
            </h3>
            <p className="text-xs text-slate-500 mb-4">
              Hand over cash collected from retailer shops to the distributor owner/cashier.
            </p>

            <form onSubmit={handleCreateHandover} className="space-y-4 max-w-md">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Cash in Hand to Submit (₹) *
                </label>
                <input
                  type="number"
                  required
                  value={handoverAmount}
                  onChange={(e) => setHandoverAmount(e.target.value)}
                  className="w-full px-3 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl font-black text-emerald-700 focus:bg-white"
                />
              </div>

              <button
                type="submit"
                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold shadow-sm transition flex items-center justify-center gap-2 cursor-pointer"
              >
                <Send className="w-4 h-4" />
                <span>Submit Handover for Settlement</span>
              </button>
            </form>
          </div>

          {/* Past Handovers */}
          <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs">
            <h4 className="text-xs font-bold text-slate-900 uppercase tracking-wider mb-3">
              Handover Submission History
            </h4>
            <div className="divide-y divide-slate-100 text-xs">
              {handovers.map((h) => (
                <div key={h.id} className="py-2.5 flex items-center justify-between">
                  <div>
                    <span className="font-bold text-slate-900 block">{h.truckPlate}</span>
                    <span className="text-[11px] text-slate-400">{h.timestamp}</span>
                  </div>
                  <div className="text-right">
                    <span className="font-black text-slate-900 block">
                      ₹{h.submittedRupees.toFixed(2)}
                    </span>
                    <span
                      className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        h.status === 'ACCEPTED'
                          ? 'bg-emerald-100 text-emerald-800'
                          : 'bg-amber-100 text-amber-800'
                      }`}
                    >
                      {h.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* OTP VERIFICATION MODAL */}
      {activeOtpOrder && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 animate-in zoom-in-95">
            <div className="flex items-center gap-2 text-emerald-600 mb-2">
              <ShieldCheck className="w-5 h-5" />
              <h3 className="text-base font-bold text-slate-900">
                OTP Delivery Verification
              </h3>
            </div>
            <p className="text-xs text-slate-500 mb-4">
              Ask shop owner for 4-digit OTP shown on their SMS / app screen (Demo OTP: <strong className="text-slate-800">{activeOtpOrder.deliveryOtp || '1234'}</strong>):
            </p>

            <form onSubmit={handleVerifyOtp} className="space-y-4 text-xs">
              <div>
                <label className="font-bold text-slate-700 block mb-1">Enter 4-Digit OTP *</label>
                <input
                  type="text"
                  maxLength={6}
                  required
                  placeholder="e.g. 1234"
                  value={otpInput}
                  onChange={(e) => setOtpInput(e.target.value)}
                  className="w-full px-4 py-3 text-center text-xl font-black tracking-widest bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Recipient Name</label>
                <input
                  type="text"
                  placeholder="e.g. Shopkeeper / Staff"
                  value={recipientName}
                  onChange={(e) => setRecipientName(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl"
                />
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1">Payment Method</label>
                <div className="flex gap-2">
                  {(['CASH', 'UPI', 'CREDIT'] as const).map((m) => (
                    <button
                      key={m}
                      type="button"
                      onClick={() => setPaymentMethod(m)}
                      className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition ${
                        paymentMethod === m
                          ? 'bg-emerald-600 text-white'
                          : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      {m}
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setActiveOtpOrder(null)}
                  className="px-4 py-2 font-bold text-slate-600 cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold shadow-xs cursor-pointer flex items-center gap-1.5"
                >
                  <Check className="w-4 h-4" />
                  <span>Verify & Deliver</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
