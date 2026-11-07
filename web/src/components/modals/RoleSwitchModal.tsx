'use client';

import { CanonicalRole } from '@/lib/types';
import {
  Warehouse,
  TrendingUp,
  Truck,
  Building,
  CheckCircle2,
  X,
  ArrowRight
} from 'lucide-react';

interface RoleSwitchModalProps {
  isOpen: boolean;
  onClose: () => void;
  currentRole: CanonicalRole;
  onSelectRole: (role: CanonicalRole) => void;
}

export default function RoleSwitchModal({
  isOpen,
  onClose,
  currentRole,
  onSelectRole,
}: RoleSwitchModalProps) {
  if (!isOpen) return null;

  const roles = [
    {
      role: 'WAREHOUSE' as CanonicalRole,
      title: 'Warehouse & Godown Inventory',
      hindi: 'गोदाम एवं इन्वेंटरी प्रबंधन',
      subtitle: 'Manual Inward, SKU CRUD, Godown & Truck Stock, Pick & Pack',
      icon: Warehouse,
      color: 'bg-blue-600',
      textColor: 'text-blue-600',
      lightBg: 'bg-blue-50',
      border: 'border-blue-200',
    },
    {
      role: 'SALES' as CanonicalRole,
      title: 'Sales Person (Field Beat)',
      hindi: 'फील्ड सेल्समैन एवं ऑर्डर बुकिंग',
      subtitle: 'Retailer visits, order booking, real-time Godown stock check',
      icon: TrendingUp,
      color: 'bg-rose-600',
      textColor: 'text-rose-600',
      lightBg: 'bg-rose-50',
      border: 'border-rose-200',
    },
    {
      role: 'DELIVERY' as CanonicalRole,
      title: 'Delivery Logistics & Van',
      hindi: 'डिलीवरी वाहन एवं लॉजिस्टिक्स',
      subtitle: 'Trip dispatch, OTP delivery verification, and cash collection',
      icon: Truck,
      color: 'bg-emerald-600',
      textColor: 'text-emerald-600',
      lightBg: 'bg-emerald-50',
      border: 'border-emerald-200',
    },
    {
      role: 'OWNER' as CanonicalRole,
      title: 'Distributor Admin / Owner',
      hindi: 'वितरक मालिक एवं नियंत्रण कक्ष',
      subtitle: 'Sovereign operations pulse, order approvals, and settlements',
      icon: Building,
      color: 'bg-purple-600',
      textColor: 'text-purple-600',
      lightBg: 'bg-purple-50',
      border: 'border-purple-200',
    },
  ];

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-end sm:items-center justify-center p-0 sm:p-4 animate-in fade-in">
      <div className="bg-white rounded-t-3xl sm:rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 animate-in slide-in-from-bottom-8 sm:slide-in-from-bottom-0 sm:zoom-in-95">
        <div className="flex items-center justify-between pb-3 border-b border-slate-100">
          <div>
            <h3 className="text-base font-black text-slate-900">
              Switch Active Role (भूमिका बदलें)
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              Instantly toggle between distributor operations roles:
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="space-y-2.5 mt-4">
          {roles.map((r) => {
            const isSelected = currentRole === r.role;
            const Icon = r.icon;

            return (
              <button
                key={r.role}
                onClick={() => {
                  onSelectRole(r.role);
                  onClose();
                }}
                className={`w-full p-3.5 rounded-xl border text-left transition flex items-start gap-3 cursor-pointer ${
                  isSelected
                    ? `${r.lightBg} ${r.border} shadow-2xs`
                    : 'bg-white border-slate-200 hover:bg-slate-50'
                }`}
              >
                <div
                  className={`w-10 h-10 rounded-xl ${r.lightBg} ${r.textColor} flex items-center justify-center shrink-0 border ${r.border}`}
                >
                  <Icon className="w-5 h-5" />
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-slate-900 truncate">
                      {r.title}
                    </span>
                    {isSelected && (
                      <CheckCircle2 className={`w-4 h-4 ${r.textColor} shrink-0`} />
                    )}
                  </div>
                  <span className="text-[11px] font-semibold text-slate-500 block">
                    {r.hindi}
                  </span>
                  <p className="text-[10px] text-slate-400 mt-0.5 leading-snug line-clamp-2">
                    {r.subtitle}
                  </p>
                </div>
              </button>
            );
          })}
        </div>

        <div className="mt-5 pt-3 border-t border-slate-100">
          <button
            onClick={onClose}
            className="w-full py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition cursor-pointer"
          >
            Close / Return to Operations
          </button>
        </div>
      </div>
    </div>
  );
}
