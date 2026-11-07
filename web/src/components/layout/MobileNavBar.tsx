'use client';

import { CanonicalRole } from '@/lib/types';
import {
  Warehouse,
  Layers,
  Package,
  Truck,
  TrendingUp,
  ShoppingCart,
  Store,
  MapPin,
  Wallet,
  ShieldCheck,
  Building,
  RotateCcw
} from 'lucide-react';

interface MobileNavBarProps {
  currentRole: CanonicalRole;
  activeSubTab: string;
  onSelectSubTab: (subTab: string) => void;
  onOpenRoleSwitch: () => void;
}

export default function MobileNavBar({
  currentRole,
  activeSubTab,
  onSelectSubTab,
  onOpenRoleSwitch,
}: MobileNavBarProps) {
  // Navigation tabs definition per role
  const getNavItems = () => {
    switch (currentRole) {
      case 'WAREHOUSE':
        return [
          { id: 'godown', label: 'Godown', icon: Warehouse },
          { id: 'inward', label: 'Inward', icon: Layers },
          { id: 'pick_pack', label: 'Pick & Pack', icon: Package },
          { id: 'load_van', label: 'Load Van', icon: Truck },
        ];
      case 'SALES':
        return [
          { id: 'dash', label: 'Sales Home', icon: TrendingUp },
          { id: 'new_order', label: 'Naya Order', icon: ShoppingCart },
          { id: 'retailers', label: 'Retailers', icon: Store },
          { id: 'products', label: 'Items', icon: Package },
        ];
      case 'DELIVERY':
        return [
          { id: 'stops', label: 'Stops', icon: MapPin },
          { id: 'trips', label: 'Trip', icon: Truck },
          { id: 'collections', label: 'Collections', icon: Wallet },
          { id: 'handover', label: 'Handover', icon: ShieldCheck },
        ];
      case 'OWNER':
      case 'ADMIN':
      default:
        return [
          { id: 'pulse', label: 'Pulse', icon: Building },
          { id: 'approvals', label: 'Approvals', icon: ShieldCheck },
          { id: 'handovers', label: 'Cash', icon: Wallet },
          { id: 'reports', label: 'Khata', icon: TrendingUp },
        ];
    }
  };

  const navItems = getNavItems();

  const getThemeColor = () => {
    switch (currentRole) {
      case 'WAREHOUSE': return 'text-blue-600';
      case 'SALES': return 'text-rose-600';
      case 'DELIVERY': return 'text-emerald-600';
      default: return 'text-purple-600';
    }
  };

  const activeColor = getThemeColor();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-slate-200 shadow-lg px-2 py-1.5 flex items-center justify-around">
      {navItems.map((item) => {
        const isSelected = activeSubTab === item.id;
        const Icon = item.icon;

        return (
          <button
            key={item.id}
            onClick={() => onSelectSubTab(item.id)}
            className={`flex flex-col items-center justify-center py-1 px-2 rounded-xl transition cursor-pointer ${
              isSelected ? activeColor : 'text-slate-400 hover:text-slate-600'
            }`}
          >
            <Icon className="w-5 h-5" />
            <span className="text-[10px] font-bold mt-0.5 tracking-tight">{item.label}</span>
          </button>
        );
      })}

      {/* 5th Button: Quick Role Switcher */}
      <button
        onClick={onOpenRoleSwitch}
        className="flex flex-col items-center justify-center py-1 px-2 rounded-xl text-slate-500 hover:text-slate-800 transition cursor-pointer"
      >
        <RotateCcw className="w-5 h-5 text-slate-600" />
        <span className="text-[10px] font-extrabold mt-0.5 tracking-tight text-slate-700">Role</span>
      </button>
    </nav>
  );
}
