'use client';

import { CanonicalRole } from '@/lib/types';
import {
  Truck,
  Warehouse,
  TrendingUp,
  Building,
  ChevronDown,
  Globe,
  LogOut,
  Smartphone,
  Monitor,
  RefreshCw,
  Database
} from 'lucide-react';

interface RoleHeaderProps {
  currentRole: CanonicalRole;
  onOpenRoleSwitch: () => void;
  viewMode: 'desktop' | 'phone_shell';
  onToggleViewMode: () => void;
  onLogout: () => void;
  isLiveServer?: boolean;
  serverStats?: { products: number; retailers: number; orders: number };
  onRefreshLive?: () => void;
  isRefreshing?: boolean;
}

export default function RoleHeader({
  currentRole,
  onOpenRoleSwitch,
  viewMode,
  onToggleViewMode,
  onLogout,
  isLiveServer = true,
  serverStats,
  onRefreshLive,
  isRefreshing = false,
}: RoleHeaderProps) {
  const getRoleConfig = (role: CanonicalRole) => {
    switch (role) {
      case 'WAREHOUSE':
        return {
          label: 'WAREHOUSE (गोदाम)',
          icon: Warehouse,
          badgeColor: 'bg-blue-600',
          textColor: 'text-blue-600',
          lightBg: 'bg-blue-50',
          border: 'border-blue-200',
        };
      case 'SALES':
        return {
          label: 'SALES (बिक्री)',
          icon: TrendingUp,
          badgeColor: 'bg-rose-600',
          textColor: 'text-rose-600',
          lightBg: 'bg-rose-50',
          border: 'border-rose-200',
        };
      case 'DELIVERY':
        return {
          label: 'DELIVERY (डिलीवरी)',
          icon: Truck,
          badgeColor: 'bg-emerald-600',
          textColor: 'text-emerald-600',
          lightBg: 'bg-emerald-50',
          border: 'border-emerald-200',
        };
      case 'OWNER':
      case 'ADMIN':
      default:
        return {
          label: 'OWNER (मालिक)',
          icon: Building,
          badgeColor: 'bg-purple-600',
          textColor: 'text-purple-600',
          lightBg: 'bg-purple-50',
          border: 'border-purple-200',
        };
    }
  };

  const config = getRoleConfig(currentRole);
  const Icon = config.icon;

  return (
    <header className="sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-slate-200 shadow-2xs">
      <div className="max-w-7xl mx-auto px-3 sm:px-6 h-14 flex items-center justify-between gap-2">
        {/* Left: Brand & Connection */}
        <div className="flex items-center gap-2 sm:gap-3">
          <div className="w-8 h-8 rounded-xl bg-blue-600 flex items-center justify-center text-white shadow-xs">
            <Truck className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="font-black text-sm tracking-tight text-slate-900">RouteFlow</span>
              <span className="hidden sm:inline-block text-[10px] font-bold px-1.5 py-0.2 rounded bg-slate-100 text-slate-600 border border-slate-200">
                FMCG OS
              </span>
            </div>
            <div className="hidden xs:flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              <span className="text-[10px] font-bold text-emerald-700 flex items-center gap-1">
                <Database className="w-3 h-3" />
                <span>Live Server D1</span>
              </span>
              {serverStats && (
                <span className="text-[10px] text-slate-400 font-medium">
                  ({serverStats.products} SKUs • {serverStats.retailers} Shops • {serverStats.orders} Ords)
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Center: Interactive Role Switcher Pill (Replicates Flutter Top Bar) */}
        <div className="flex items-center gap-2">
          <button
            onClick={onOpenRoleSwitch}
            className={`flex items-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-xl border ${config.border} ${config.lightBg} hover:opacity-90 transition cursor-pointer shadow-2xs`}
          >
            <Icon className={`w-3.5 h-3.5 ${config.textColor}`} />
            <span className={`text-[11px] font-black uppercase tracking-wider ${config.textColor}`}>
              {config.label}
            </span>
            <ChevronDown className={`w-3.5 h-3.5 ${config.textColor} opacity-70`} />
          </button>

          {onRefreshLive && (
            <button
              onClick={onRefreshLive}
              disabled={isRefreshing}
              title="Refresh Live Server Data"
              className="p-1.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-slate-600 transition cursor-pointer flex items-center justify-center"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin text-blue-600' : ''}`} />
            </button>
          )}
        </div>

        {/* Right: View Mode Toggle & Logout */}
        <div className="flex items-center gap-1.5 sm:gap-2">
          {/* Phone Shell / Desktop View Switcher */}
          <button
            onClick={onToggleViewMode}
            title={viewMode === 'desktop' ? 'Switch to Phone View' : 'Switch to Desktop View'}
            className="hidden md:flex items-center gap-1 px-2.5 py-1.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-[11px] font-bold text-slate-700 transition cursor-pointer"
          >
            {viewMode === 'desktop' ? (
              <>
                <Smartphone className="w-3.5 h-3.5 text-blue-600" />
                <span>Phone View</span>
              </>
            ) : (
              <>
                <Monitor className="w-3.5 h-3.5 text-emerald-600" />
                <span>Desktop View</span>
              </>
            )}
          </button>

          <button
            onClick={onLogout}
            title="Sign Out"
            className="p-1.5 sm:px-2.5 sm:py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-rose-50 hover:border-rose-200 text-slate-600 hover:text-rose-600 text-xs font-bold transition flex items-center gap-1 cursor-pointer"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Logout</span>
          </button>
        </div>
      </div>
    </header>
  );
}
