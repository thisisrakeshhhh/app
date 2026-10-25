'use client';

import React, { useEffect, useRef, useState, useMemo } from 'react';
import {
  MapPin,
  Navigation,
  ZoomIn,
  ZoomOut,
  Layers,
  Search,
  ShoppingCart,
  ArrowRight,
  TrendingUp,
  AlertTriangle,
  Truck,
  CheckCircle2,
  Store,
  RefreshCw,
} from 'lucide-react';

export interface WebMapRetailer {
  id: string;
  name: string;
  beat_id?: string;
  beatId?: string;
  address?: string;
  contact_number?: string;
  contactNumber?: string;
  latitude?: number | null;
  longitude?: number | null;
  credit_limit_paise?: number;
  creditLimitPaise?: number;
  outstanding_amount_paise?: number;
  outstandingAmountPaise?: number;
}

export interface WebMapOrder {
  id: string;
  retailer_id: string;
  retailer_name?: string;
  total_amount_paise?: number;
  total_amount?: number;
  status: string;
}

interface RouteFlowWebMapProps {
  retailers: WebMapRetailer[];
  orders?: WebMapOrder[];
  onSelectRetailer?: (retailer: WebMapRetailer) => void;
  onBookOrder?: (retailer: WebMapRetailer) => void;
  onView360?: (retailerId: string) => void;
  lang?: 'en' | 'hi';
  className?: string;
  height?: string;
}

// Tricity sensible reference coordinates for unanchored demo stores
const TRICITY_FALLBACK_COORDINATES = [
  { lat: 30.7398, lng: 76.7827, area: 'Sector 17-C, Chandigarh' },
  { lat: 30.7352, lng: 76.7725, area: 'Sector 22-D, Chandigarh' },
  { lat: 30.7046, lng: 76.7179, area: 'Phase 7, Mohali' },
  { lat: 30.7225, lng: 76.7680, area: 'Sector 35-C, Chandigarh' },
  { lat: 30.6942, lng: 76.8606, area: 'Sector 5, Panchkula' },
  { lat: 30.7120, lng: 76.7230, area: 'Phase 5 Ind. Area, Mohali' },
  { lat: 30.7480, lng: 76.8040, area: 'Madhya Marg, Chandigarh' },
  { lat: 30.6815, lng: 76.7285, area: 'Aerocity, Mohali' },
];

export default function RouteFlowWebMap({
  retailers = [],
  orders = [],
  onSelectRetailer,
  onBookOrder,
  onView360,
  lang = 'en',
  className = '',
  height = '600px',
}: RouteFlowWebMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<any>(null);
  const markersLayerGroupRef = useRef<any>(null);
  const polylinesLayerGroupRef = useRef<any>(null);

  const [isClient, setIsClient] = useState(false);
  const [filterMode, setFilterMode] = useState<'all' | 'delivery' | 'overdue'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedRetailer, setSelectedRetailer] = useState<WebMapRetailer | null>(null);

  useEffect(() => {
    setIsClient(true);
  }, []);

  // Compute geocoded retailer items
  const geocodedRetailers = useMemo(() => {
    return retailers.map((r, index) => {
      const explicitLat = r.latitude != null && !isNaN(r.latitude) && r.latitude !== 0 ? r.latitude : null;
      const explicitLng = r.longitude != null && !isNaN(r.longitude) && r.longitude !== 0 ? r.longitude : null;

      if (explicitLat != null && explicitLng != null) {
        return { ...r, finalLat: explicitLat, finalLng: explicitLng, isEstimate: false };
      }

      // Hash-based deterministic distribution over Tricity
      const fallback = TRICITY_FALLBACK_COORDINATES[index % TRICITY_FALLBACK_COORDINATES.length];
      return {
        ...r,
        finalLat: fallback.lat + ((index % 3) - 1) * 0.003,
        finalLng: fallback.lng + (((index + 1) % 3) - 1) * 0.003,
        isEstimate: true,
      };
    });
  }, [retailers]);

  // Delivery stops from active out-for-delivery orders
  const activeDeliveryStops = useMemo(() => {
    const deliveryOrders = orders.filter(
      (o) => o.status === 'OUT_FOR_DELIVERY' || o.status === 'ASSIGNED_TO_TRIP' || o.status === 'PACKED'
    );
    return deliveryOrders.map((order, idx) => {
      const match = geocodedRetailers.find((r) => r.id === order.retailer_id);
      return {
        order,
        retailer: match,
        stopSequence: idx + 1,
        lat: match ? match.finalLat : 30.7333,
        lng: match ? match.finalLng : 76.7794,
      };
    });
  }, [orders, geocodedRetailers]);

  // Filtered retailers based on tab and search
  const filteredRetailers = useMemo(() => {
    return geocodedRetailers.filter((r) => {
      const matchesSearch =
        searchQuery.trim() === '' ||
        r.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (r.address && r.address.toLowerCase().includes(searchQuery.toLowerCase())) ||
        (r.beat_id && r.beat_id.toLowerCase().includes(searchQuery.toLowerCase()));

      if (!matchesSearch) return false;

      const outstanding = r.outstanding_amount_paise ?? r.outstandingAmountPaise ?? 0;
      const creditLimit = r.credit_limit_paise ?? r.creditLimitPaise ?? 0;

      if (filterMode === 'overdue') {
        return outstanding > 0 && (creditLimit > 0 ? outstanding > creditLimit : true);
      }
      if (filterMode === 'delivery') {
        return activeDeliveryStops.some((s) => s.retailer?.id === r.id);
      }
      return true;
    });
  }, [geocodedRetailers, searchQuery, filterMode, activeDeliveryStops]);

  // Initialize Leaflet Map
  useEffect(() => {
    if (!isClient || !mapContainerRef.current) return;

    let isMounted = true;

    async function initMap() {
      const L = (await import('leaflet')).default;
      // Inject Leaflet CSS dynamically if not present
      if (!document.getElementById('leaflet-css')) {
        const link = document.createElement('link');
        link.id = 'leaflet-css';
        link.rel = 'stylesheet';
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
        document.head.appendChild(link);
      }

      if (!isMounted || !mapContainerRef.current) return;

      // Clean up previous instance if any
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }

      // Initial center at Chandigarh Tricity
      const defaultCenter: [number, number] = [30.7333, 76.7794];
      const map = L.map(mapContainerRef.current, {
        center: defaultCenter,
        zoom: 13,
        zoomControl: false,
      });

      // High-performance OpenStreetMap raster street tiles
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        maxZoom: 19,
      }).addTo(map);

      // Create Layer Groups
      const polylinesGroup = L.layerGroup().addTo(map);
      const markersGroup = L.layerGroup().addTo(map);

      mapInstanceRef.current = map;
      markersLayerGroupRef.current = markersGroup;
      polylinesLayerGroupRef.current = polylinesGroup;

      renderLayers(L);
    }

    initMap();

    return () => {
      isMounted = false;
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, [isClient]);

  // Update markers and polylines when data or filters change
  useEffect(() => {
    if (!mapInstanceRef.current || !isClient) return;

    async function updateLayers() {
      const L = (await import('leaflet')).default;
      renderLayers(L);
    }

    updateLayers();
  }, [filteredRetailers, activeDeliveryStops, filterMode]);

  const renderLayers = (L: any) => {
    const map = mapInstanceRef.current;
    const markersGroup = markersLayerGroupRef.current;
    const polylinesGroup = polylinesLayerGroupRef.current;

    if (!map || !markersGroup || !polylinesGroup) return;

    markersGroup.clearLayers();
    polylinesGroup.clearLayers();

    const bounds: [number, number][] = [];

    // 1. Draw Route Polylines for Active Delivery Stops
    if (activeDeliveryStops.length > 1) {
      const linePoints: [number, number][] = activeDeliveryStops.map((s) => [s.lat, s.lng]);
      const routePolyline = L.polyline(linePoints, {
        color: '#2563EB',
        weight: 4,
        opacity: 0.8,
        dashArray: '8, 8',
      });
      polylinesGroup.addLayer(routePolyline);
    }

    // 2. Render Delivery Stop Pins (with Stop Numbers)
    activeDeliveryStops.forEach((stop) => {
      bounds.push([stop.lat, stop.lng]);
      const stopHtml = `
        <div style="cursor: pointer; display: flex; flex-direction: column; align-items: center; transform: translate(-50%, -100%);">
          <div style="background: #1E293B; color: #FFFFFF; font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 6px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.2); white-space: nowrap; margin-bottom: 3px; border: 1px solid #334155;">
            Stop #${stop.stopSequence} • ${stop.retailer?.name || 'Shop'}
          </div>
          <div style="width: 28px; height: 28px; background: #2563EB; border: 2.5px solid #FFFFFF; border-radius: 50%; box-shadow: 0 4px 10px rgba(37,99,235,0.5); display: flex; align-items: center; justify-content: center; color: white; font-size: 13px; font-weight: 800;">
            ${stop.stopSequence}
          </div>
        </div>
      `;

      const stopIcon = L.divIcon({
        className: 'routeflow-delivery-pin',
        html: stopHtml,
        iconSize: [0, 0],
      });

      const marker = L.marker([stop.lat, stop.lng], { icon: stopIcon });
      marker.on('click', () => {
        if (stop.retailer) {
          setSelectedRetailer(stop.retailer);
          if (onSelectRetailer) onSelectRetailer(stop.retailer);
        }
      });
      markersGroup.addLayer(marker);
    });

    // 3. Render Retailer Pins
    filteredRetailers.forEach((retailer) => {
      // If already shown as active delivery stop, skip duplicating base pin
      if (activeDeliveryStops.some((s) => s.retailer?.id === retailer.id)) {
        return;
      }

      bounds.push([retailer.finalLat, retailer.finalLng]);

      const outstanding = retailer.outstanding_amount_paise ?? retailer.outstandingAmountPaise ?? 0;
      const creditLimit = retailer.credit_limit_paise ?? retailer.creditLimitPaise ?? 0;
      const isOverdue = outstanding > 0 && creditLimit > 0 && outstanding > creditLimit;

      const pinBg = isOverdue ? '#DC2626' : outstanding > 0 ? '#F59E0B' : '#059669';

      const retailerHtml = `
        <div style="cursor: pointer; display: flex; flex-direction: column; align-items: center; transform: translate(-50%, -100%);">
          <div style="background: #FFFFFF; color: #0F172A; font-size: 11px; font-weight: 700; padding: 2px 7px; border-radius: 6px; box-shadow: 0 3px 8px rgba(0,0,0,0.15); white-space: nowrap; margin-bottom: 3px; border: 1px solid #E2E8F0;">
            ${retailer.name}
          </div>
          <div style="width: 24px; height: 24px; background: ${pinBg}; border: 2px solid #FFFFFF; border-radius: 50%; box-shadow: 0 3px 8px rgba(0,0,0,0.25); display: flex; align-items: center; justify-content: center; color: white; font-size: 11px;">
            🏪
          </div>
        </div>
      `;

      const retailerIcon = L.divIcon({
        className: 'routeflow-retailer-pin',
        html: retailerHtml,
        iconSize: [0, 0],
      });

      const marker = L.marker([retailer.finalLat, retailer.finalLng], { icon: retailerIcon });
      marker.on('click', () => {
        setSelectedRetailer(retailer);
        if (onSelectRetailer) onSelectRetailer(retailer);
      });
      markersGroup.addLayer(marker);
    });

    // Fit bounds if markers exist
    if (bounds.length > 0) {
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 15 });
    }
  };

  const handleZoomIn = () => {
    if (mapInstanceRef.current) mapInstanceRef.current.zoomIn();
  };

  const handleZoomOut = () => {
    if (mapInstanceRef.current) mapInstanceRef.current.zoomOut();
  };

  const handleRecenter = () => {
    if (mapInstanceRef.current) {
      mapInstanceRef.current.setView([30.7333, 76.7794], 13);
    }
  };

  return (
    <div className={`relative w-full rounded-2xl overflow-hidden border border-slate-200 shadow-sm bg-slate-50 flex flex-col ${className}`} style={{ height }}>
      {/* Top Map Action Deck */}
      <div className="absolute top-3 left-3 right-3 z-[1000] flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-2.5 pointer-events-none">
        {/* Search Input */}
        <div className="relative flex-1 max-w-sm pointer-events-auto">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder={lang === 'hi' ? 'दुकान या क्षेत्र खोजें...' : 'Search shop or area...'}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-2 bg-white/95 backdrop-blur-md border border-slate-200/90 rounded-xl text-xs font-medium text-slate-900 shadow-md focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
          />
        </div>

        {/* Filter Pills */}
        <div className="flex items-center gap-1.5 bg-white/95 backdrop-blur-md p-1 rounded-xl border border-slate-200/90 shadow-md pointer-events-auto overflow-x-auto">
          <button
            onClick={() => setFilterMode('all')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition cursor-pointer flex items-center gap-1.5 ${
              filterMode === 'all'
                ? 'bg-blue-600 text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <Store className="w-3.5 h-3.5" />
            <span>{lang === 'hi' ? 'सभी दुकानें' : 'All Shops'} ({filteredRetailers.length})</span>
          </button>

          <button
            onClick={() => setFilterMode('delivery')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition cursor-pointer flex items-center gap-1.5 ${
              filterMode === 'delivery'
                ? 'bg-blue-600 text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <Truck className="w-3.5 h-3.5" />
            <span>{lang === 'hi' ? 'सक्रिय डिलीवरी' : 'Deliveries'} ({activeDeliveryStops.length})</span>
          </button>

          <button
            onClick={() => setFilterMode('overdue')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition cursor-pointer flex items-center gap-1.5 ${
              filterMode === 'overdue'
                ? 'bg-red-600 text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>{lang === 'hi' ? 'उधार सतर्कता' : 'Overdue'}</span>
          </button>
        </div>
      </div>

      {/* Map Canvas */}
      <div ref={mapContainerRef} className="w-full h-full z-0" />

      {/* Floating Tactical Controls */}
      <div className="absolute right-3 bottom-6 z-[1000] flex flex-col items-center gap-1.5">
        <button
          onClick={handleRecenter}
          title={lang === 'hi' ? 'पुनः केंद्रित करें' : 'Recenter to Tricity'}
          className="w-9 h-9 bg-white text-slate-700 hover:text-blue-600 hover:bg-slate-50 border border-slate-200 rounded-xl shadow-md flex items-center justify-center transition cursor-pointer"
        >
          <Navigation className="w-4 h-4 text-blue-600" />
        </button>
        <button
          onClick={handleZoomIn}
          title="Zoom In"
          className="w-9 h-9 bg-white text-slate-700 hover:text-blue-600 hover:bg-slate-50 border border-slate-200 rounded-xl shadow-md flex items-center justify-center transition cursor-pointer"
        >
          <ZoomIn className="w-4 h-4" />
        </button>
        <button
          onClick={handleZoomOut}
          title="Zoom Out"
          className="w-9 h-9 bg-white text-slate-700 hover:text-blue-600 hover:bg-slate-50 border border-slate-200 rounded-xl shadow-md flex items-center justify-center transition cursor-pointer"
        >
          <ZoomOut className="w-4 h-4" />
        </button>
      </div>

      {/* Selected Marker Detail Card */}
      {selectedRetailer && (
        <div className="absolute left-3 bottom-6 z-[1000] max-w-sm w-[calc(100%-4rem)] sm:w-80 bg-white/98 backdrop-blur-md border border-slate-200/90 rounded-2xl p-4 shadow-xl space-y-3 animate-in fade-in slide-in-from-bottom-2 duration-150">
          <div className="flex items-start justify-between">
            <div>
              <div className="text-sm font-bold text-slate-900">{selectedRetailer.name}</div>
              <div className="text-xs text-slate-500 mt-0.5">
                {selectedRetailer.beat_id || selectedRetailer.beatId || 'Territory Shop'} • {selectedRetailer.contact_number || selectedRetailer.contactNumber || 'No phone'}
              </div>
            </div>
            <button
              onClick={() => setSelectedRetailer(null)}
              className="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 transition cursor-pointer"
            >
              ✕
            </button>
          </div>

          {selectedRetailer.address && (
            <div className="text-xs text-slate-600 flex items-start gap-1.5 bg-slate-50 p-2 rounded-lg border border-slate-100">
              <MapPin className="w-3.5 h-3.5 text-blue-600 shrink-0 mt-0.5" />
              <span>{selectedRetailer.address}</span>
            </div>
          )}

          <div className="grid grid-cols-2 gap-2 text-xs pt-1 border-t border-slate-100">
            <div>
              <div className="text-slate-400">Outstanding Balance</div>
              <div className="text-sm font-bold text-slate-900 mt-0.5">
                ₹{(((selectedRetailer.outstanding_amount_paise ?? selectedRetailer.outstandingAmountPaise ?? 0)) / 100).toLocaleString('en-IN')}
              </div>
            </div>
            <div>
              <div className="text-slate-400">Credit Limit</div>
              <div className="text-sm font-bold text-slate-900 mt-0.5">
                ₹{(((selectedRetailer.credit_limit_paise ?? selectedRetailer.creditLimitPaise ?? 0)) / 100).toLocaleString('en-IN')}
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2 pt-2 border-t border-slate-100">
            {onBookOrder && (
              <button
                onClick={() => onBookOrder(selectedRetailer)}
                className="flex-1 py-1.5 px-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold text-xs rounded-xl shadow-xs transition flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <ShoppingCart className="w-3.5 h-3.5" />
                <span>{lang === 'hi' ? 'ऑर्डर बुक करें' : 'Book Order'}</span>
              </button>
            )}
            {onView360 && (
              <button
                onClick={() => onView360(selectedRetailer.id)}
                className="py-1.5 px-3 bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold text-xs rounded-xl transition flex items-center justify-center gap-1 cursor-pointer"
              >
                <span>360°</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        </div>
      )}

      {/* Territory Legend Attribution Badge */}
      <div className="absolute left-3 bottom-1.5 z-[999] text-[10px] text-slate-500 bg-white/80 backdrop-blur-xs px-2 py-0.5 rounded-md border border-slate-200/60 pointer-events-none">
        OpenStreetMap &copy; &bull; RouteFlow Logistics
      </div>
    </div>
  );
}
