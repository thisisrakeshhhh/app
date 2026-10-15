'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, getStoredUser, clearSession, User, API_BASE, getStoredToken } from '@/lib/api';
import {
  Truck,
  Package,
  Store,
  Users,
  CheckCircle,
  Clock,
  ArrowUpRight,
  LogOut,
  RefreshCw,
  Wallet,
  Building,
  RotateCcw,
  Plus,
  MapPin,
  Phone,
  X,
  AlertTriangle,
  FileText,
  ShoppingBag,
  DollarSign,
  Printer,
  Receipt,
  CreditCard,
  Smartphone,
  Barcode,
  MessageSquare,
  CheckCircle2,
  ChevronRight,
  TrendingUp,
  Globe,
  ArrowLeft,
  ShoppingCart,
  Minus,
  MoreHorizontal,
  Key,
  Check,
  ShieldCheck,
  Sparkles
} from 'lucide-react';

interface OverviewMetrics {
  pendingApprovals: number;
  lowStockItems: number;
  deliveredSalesToday: number;
  retailerOutstanding: number;
  pickingPacking: number;
  outForDelivery: number;
  exceptions: number;
}

interface Order {
  id: string;
  retailer_id: string;
  retailer_name?: string;
  total_amount_paise: number;
  status: string;
  created_at: number;
  items_count?: number;
}

interface CashHandover {
  id: string;
  user_id: string;
  driver_name?: string;
  amount_paise: number;
  status: string;
  submitted_at: number;
}

function formatStatusLabel(status: string | undefined): string {
  if (!status) return 'Unknown';
  switch (status.toUpperCase()) {
    case 'ACCEPTED': return 'Accepted / Settled';
    case 'PENDING': return 'Pending Verification';
    case 'APPROVED': return 'Approved';
    case 'PENDING_APPROVAL': return 'Approval Pending';
    case 'PICKING': return 'Picking in Progress';
    case 'PACKED': return 'Packed';
    case 'OUT_FOR_DELIVERY': return 'Out for Delivery';
    case 'DELIVERED': return 'Delivered';
    case 'DELIVERY_FAILED': return 'Delivery Failed';
    case 'PARTIALLY_DELIVERED': return 'Partially Delivered';
    case 'REJECTED': return 'Rejected';
    default: return status.replace(/_/g, ' ');
  }
}

export default function DashboardPage() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [activeTab, setActiveTab] = useState<'overview' | 'control_room' | 'exceptions' | 'cash_control' | 'reports' | 'orders' | 'handovers' | 'products' | 'retailers'>('overview');
  const [lang, setLang] = useState<'en' | 'hi'>('en');

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('routeflow_lang');
      if (saved === 'hi' || saved === 'en') setLang(saved);
    }
  }, []);

  const toggleLanguage = () => {
    const next = lang === 'en' ? 'hi' : 'en';
    setLang(next);
    if (typeof window !== 'undefined') {
      localStorage.setItem('routeflow_lang', next);
    }
  };
  
  // Operating System State
  const [controlRoomData, setControlRoomData] = useState<any | null>(null);
  const [exceptionsList, setExceptionsList] = useState<any[]>([]);
  const [dayBookData, setDayBookData] = useState<any | null>(null);
  const [purchaseList, setPurchaseList] = useState<any[]>([]);
  const [cashBookData, setCashBookData] = useState<any | null>(null);
  const [selectedRetailer360, setSelectedRetailer360] = useState<any | null>(null);
  const [retailer360Loading, setRetailer360Loading] = useState(false);
  
  const [metrics, setMetrics] = useState<OverviewMetrics>({
    pendingApprovals: 0,
    lowStockItems: 0,
    deliveredSalesToday: 0,
    retailerOutstanding: 0,
    pickingPacking: 0,
    outForDelivery: 0,
    exceptions: 0,
  });

  const [orders, setOrders] = useState<Order[]>([]);
  const [handovers, setHandovers] = useState<CashHandover[]>([]);
  const [products, setProducts] = useState<any[]>([]);
  const [retailers, setRetailers] = useState<any[]>([]);
  const [orderFilter, setOrderFilter] = useState<'ALL' | 'PENDING' | 'APPROVED' | 'DISPATCHED' | 'DELIVERED'>('ALL');
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  // Add Retailer Modal State
  const [showAddRetailerModal, setShowAddRetailerModal] = useState(false);
  const [newRetailer, setNewRetailer] = useState({
    name: '',
    contactNumber: '',
    address: '',
    creditLimitRupees: '5000',
    beatId: 'BEAT-04',
    latitude: '',
    longitude: ''
  });
  const [detectingLocation, setDetectingLocation] = useState(false);
  const [creatingRetailer, setCreatingRetailer] = useState(false);

  // Add Product Modal State
  const [showAddProductModal, setShowAddProductModal] = useState(false);
  const [newProduct, setNewProduct] = useState({
    name: '',
    category: 'General',
    priceRupees: '100',
    unit: 'Pack',
    stockQuantity: '50'
  });
  const [creatingProduct, setCreatingProduct] = useState(false);

  // Delivery Assignment State
  const [deliveryExecutives, setDeliveryExecutives] = useState<any[]>([]);
  const [assignModalOrder, setAssignModalOrder] = useState<any | null>(null);
  const [selectedDriverId, setSelectedDriverId] = useState<string>('');
  const [assigningLoading, setAssigningLoading] = useState(false);

  // Reports Tab State
  const [selectedReportRetailerId, setSelectedReportRetailerId] = useState<string>('');

  // Mobile App-Like & Field Operations State
  const [orderBookingRetailer, setOrderBookingRetailer] = useState<any | null>(null);
  const [orderCart, setOrderCart] = useState<{ [productId: string]: number }>({});
  const [submittingOrder, setSubmittingOrder] = useState(false);

  const [otpModalOrder, setOtpModalOrder] = useState<any | null>(null);
  const [otpInput, setOtpInput] = useState('');
  const [recipientNameInput, setRecipientNameInput] = useState('');
  const [otpPaymentMethod, setOtpPaymentMethod] = useState<'CASH' | 'CREDIT'>('CASH');
  const [otpRequesting, setOtpRequesting] = useState(false);
  const [otpVerifying, setOtpVerifying] = useState(false);
  const [otpStatusNote, setOtpStatusNote] = useState<string | null>(null);

  const [showNewHandoverModal, setShowNewHandoverModal] = useState(false);
  const [handoverAmountRupees, setHandoverAmountRupees] = useState('');
  const [handoverNotes, setHandoverNotes] = useState('');
  const [submittingHandover, setSubmittingHandover] = useState(false);

  const [showMoreMobileMenu, setShowMoreMobileMenu] = useState(false);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.push('/login');
      return;
    }
    setUser(u);
    const r = u.role?.toUpperCase();
    if (r === 'SALESPERSON' || r === 'SALES') {
      setActiveTab('retailers');
    } else if (r === 'WAREHOUSE_MANAGER' || r === 'WAREHOUSE') {
      setActiveTab('products');
    } else if (r === 'DELIVERY_EXECUTIVE' || r === 'DELIVERY') {
      setActiveTab('orders');
    } else {
      setActiveTab('overview');
    }
    loadAllData(false);

    // Real-time Auto-Refresh: Sync operational state across roles every 10 seconds
    const interval = setInterval(() => {
      loadAllData(true);
    }, 10000);

    return () => clearInterval(interval);
  }, [router]);

  const loadAllData = async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      // 1. Fetch Orders
      const ordersRes = await apiFetch<any>('/orders').catch(() => ({ orders: [] }));
      const orderList = ordersRes.orders || ordersRes || [];
      setOrders(Array.isArray(orderList) ? orderList : []);

      // 2. Fetch Cash Handovers
      const handoversRes = await apiFetch<any>('/cash-handovers').catch(() => ({ handovers: [] }));
      const handoverList = handoversRes.handovers || handoversRes || [];
      setHandovers(Array.isArray(handoverList) ? handoverList : []);

      // 3. Fetch Products
      const prodRes = await apiFetch<any>('/products').catch(() => ({ products: [] }));
      setProducts(Array.isArray(prodRes) ? prodRes : prodRes.products || []);

      // 4. Fetch Retailers
      const retRes = await apiFetch<any>('/retailers').catch(() => ({ retailers: [] }));
      const retList = Array.isArray(retRes) ? retRes : retRes.retailers || [];
      setRetailers(retList);
      if (retList.length > 0 && !selectedReportRetailerId) {
        setSelectedReportRetailerId(retList[0].id);
      }

      // 5. Fetch Delivery Executives
      const devRes = await apiFetch<any>('/delivery-executives').catch(() => []);
      const devList = Array.isArray(devRes) ? devRes : devRes.executives || [];
      setDeliveryExecutives(devList);
      if (devList.length > 0 && !selectedDriverId) {
        setSelectedDriverId(devList[0].id);
      }

      // 6. Fetch Operating System Modules (Owner Control Room, Exceptions, Day Book, Purchase, Cash Control)
      const [pulseRes, excRes, dayRes, purRes, cashRes] = await Promise.all([
        apiFetch<any>('/control-room/pulse').catch(() => null),
        apiFetch<any>('/exceptions/feed').catch(() => ({ exceptions: [] })),
        apiFetch<any>('/day-book/today').catch(() => null),
        apiFetch<any>('/purchase-planning/suggestions').catch(() => ({ purchaseList: [] })),
        apiFetch<any>('/cash-control/daily-book').catch(() => null)
      ]);
      setControlRoomData(pulseRes);
      setExceptionsList(excRes?.exceptions || []);
      setDayBookData(dayRes);
      setPurchaseList(purRes?.purchaseList || []);
      setCashBookData(cashRes);

      // Compute overview stats with genuine defaults (0 for empty company)
      const pendingOrders = orderList.filter((o: any) => o.status === 'PENDING_APPROVAL' || o.status === 'PENDING').length;
      const picking = orderList.filter((o: any) => o.status === 'APPROVED' || o.status === 'PICKING' || o.status === 'PACKED').length;
      const outForDelivery = orderList.filter((o: any) => o.status === 'OUT_FOR_DELIVERY').length;
      const deliveredToday = orderList
        .filter((o: any) => o.status === 'DELIVERED')
        .reduce((sum: number, o: any) => sum + (o.total_amount_paise || (o.total_amount ? o.total_amount * 100 : 0)), 0);

      setMetrics({
        pendingApprovals: pendingOrders,
        lowStockItems: pulseRes?.inventory?.lowStockCount || 0,
        deliveredSalesToday: pulseRes?.todaySales?.deliveredPaise ?? deliveredToday ?? 0,
        retailerOutstanding: pulseRes?.todayCollections?.netCashInHandPaise ?? 0,
        pickingPacking: picking,
        outForDelivery: outForDelivery,
        exceptions: excRes?.exceptions?.length || 0,
      });
    } catch (err: any) {
      console.error(err);
    } finally {
      if (!silent) setLoading(false);
    }
  };

  const handleApproveOrder = async (orderId: string) => {
    setActionLoading(orderId);
    try {
      await apiFetch(`/orders/${orderId}/approve`, { method: 'POST' });
      setMessage(`Order ${orderId} approved successfully`);
      await loadAllData();
    } catch (err: any) {
      alert(`Approval error: ${err.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const handleAcceptHandover = async (handoverId: string, amountPaise: number) => {
    setActionLoading(handoverId);
    try {
      await apiFetch(`/cash-handovers/${handoverId}/acknowledge`, {
        method: 'POST',
        body: JSON.stringify({
          status: 'ACCEPTED',
          receivedAmountPaise: amountPaise,
        }),
      });
      setMessage(`Handover reconciled and settled`);
      await loadAllData();
    } catch (err: any) {
      alert(`Handover reconciliation error: ${err.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const handleOpenRetailer360 = async (retailerId: string) => {
    setRetailer360Loading(true);
    try {
      const res = await apiFetch<any>(`/retailers/${retailerId}/360`);
      setSelectedRetailer360(res);
    } catch (err: any) {
      alert(`Failed to load Retailer 360 profile: ${err.message}`);
    } finally {
      setRetailer360Loading(false);
    }
  };

  const handleDetectLocation = () => {
    if (typeof window === 'undefined' || !navigator.geolocation) {
      alert('Geolocation is not supported by your browser');
      return;
    }
    setDetectingLocation(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setNewRetailer((prev) => ({
          ...prev,
          latitude: pos.coords.latitude.toFixed(6),
          longitude: pos.coords.longitude.toFixed(6),
        }));
        setDetectingLocation(false);
      },
      (err) => {
        alert('Could not retrieve location: ' + err.message);
        setDetectingLocation(false);
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  };

  const handleCreateRetailer = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRetailer.name.trim()) return;
    setCreatingRetailer(true);
    try {
      const creditPaise = Math.round((parseFloat(newRetailer.creditLimitRupees) || 0) * 100);
      await apiFetch('/retailers', {
        method: 'POST',
        body: JSON.stringify({
          name: newRetailer.name.trim(),
          contactNumber: newRetailer.contactNumber.trim(),
          address: newRetailer.address.trim(),
          creditLimitPaise: creditPaise,
          beatId: newRetailer.beatId || 'BEAT-04',
          latitude: newRetailer.latitude ? parseFloat(newRetailer.latitude) : undefined,
          longitude: newRetailer.longitude ? parseFloat(newRetailer.longitude) : undefined,
        }),
      });
      setMessage('Shop / Retailer added successfully!');
      setShowAddRetailerModal(false);
      setNewRetailer({
        name: '',
        contactNumber: '',
        address: '',
        creditLimitRupees: '5000',
        beatId: 'BEAT-04',
        latitude: '',
        longitude: ''
      });
      await loadAllData();
      setTimeout(() => setMessage(null), 3000);
    } catch (err: any) {
      alert(err.message || 'Failed to create retailer');
    } finally {
      setCreatingRetailer(false);
    }
  };

  const handleCreateProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newProduct.name.trim()) return;
    setCreatingProduct(true);
    try {
      const pricePaise = Math.round((parseFloat(newProduct.priceRupees) || 0) * 100);
      const stock = parseInt(newProduct.stockQuantity) || 0;
      await apiFetch('/products', {
        method: 'POST',
        body: JSON.stringify({
          name: newProduct.name.trim(),
          category: newProduct.category.trim() || 'General',
          pricePaise,
          unit: newProduct.unit.trim() || 'Unit',
          stockQuantity: stock,
        }),
      });
      setMessage('Product added to catalog successfully!');
      setShowAddProductModal(false);
      setNewProduct({
        name: '',
        category: 'General',
        priceRupees: '100',
        unit: 'Pack',
        stockQuantity: '50'
      });
      await loadAllData();
      setTimeout(() => setMessage(null), 3000);
    } catch (err: any) {
      alert(err.message || 'Failed to create product');
    } finally {
      setCreatingProduct(false);
    }
  };

  const handleAssignDelivery = async () => {
    if (!assignModalOrder || !selectedDriverId) return;
    setAssigningLoading(true);
    try {
      const orderId = assignModalOrder.id;
      // If order is APPROVED or PICKING, mark items picked and pack it first so dispatch trigger succeeds
      if (assignModalOrder.status === 'APPROVED' || assignModalOrder.status === 'PICKING') {
        const details = await apiFetch<any>(`/orders/${orderId}`).catch(() => null);
        const itemsList = details?.items || [];
        for (const it of itemsList) {
          const pid = it.productId || it.product_id;
          if (!it.isPicked && pid) {
            await apiFetch(`/orders/${orderId}/pick-item`, {
              method: 'POST',
              body: JSON.stringify({ productId: pid, isPicked: true })
            }).catch(() => {});
          }
        }
        await apiFetch(`/orders/${orderId}/pack`, {
          method: 'POST',
          body: JSON.stringify({ boxCount: 1 })
        });
      }

      await apiFetch(`/orders/${orderId}/dispatch`, {
        method: 'POST',
        body: JSON.stringify({ deliveryEmployeeId: selectedDriverId }),
      });

      setMessage(`Order ${orderId} assigned to delivery driver & dispatched!`);
      setAssignModalOrder(null);
      await loadAllData();
      setTimeout(() => setMessage(null), 3000);
    } catch (err: any) {
      alert(`Assignment failed: ${err.message}`);
    } finally {
      setAssigningLoading(false);
    }
  };

  const handleOpenOrderBooking = (retailer: any) => {
    setOrderBookingRetailer(retailer);
    // Initialize demo items: 10 Tea, 5 Biscuits, 2 Oil (or first 3 products)
    const initialCart: { [id: string]: number } = {};
    products.forEach((p) => {
      const name = (p.name || '').toLowerCase();
      if (name.includes('tea') || name.includes('chai')) initialCart[p.id] = 10;
      else if (name.includes('biscuit') || name.includes('parle') || name.includes('cookie')) initialCart[p.id] = 5;
      else if (name.includes('oil') || name.includes('mustard') || name.includes('refined')) initialCart[p.id] = 2;
    });
    if (Object.keys(initialCart).length === 0 && products.length > 0) {
      if (products[0]) initialCart[products[0].id] = 10;
      if (products[1]) initialCart[products[1].id] = 5;
      if (products[2]) initialCart[products[2].id] = 2;
    }
    setOrderCart(initialCart);
  };

  const handleQuickFillDemoOrder = () => {
    const demoCart: { [id: string]: number } = {};
    products.forEach((p) => {
      const name = (p.name || '').toLowerCase();
      if (name.includes('tea') || name.includes('chai')) demoCart[p.id] = 10;
      else if (name.includes('biscuit') || name.includes('parle') || name.includes('cookie')) demoCart[p.id] = 5;
      else if (name.includes('oil') || name.includes('mustard') || name.includes('refined')) demoCart[p.id] = 2;
    });
    if (Object.keys(demoCart).length === 0 && products.length > 0) {
      if (products[0]) demoCart[products[0].id] = 10;
      if (products[1]) demoCart[products[1].id] = 5;
      if (products[2]) demoCart[products[2].id] = 2;
    }
    setOrderCart(demoCart);
  };

  const handleUpdateCartQuantity = (productId: string, delta: number) => {
    setOrderCart((prev) => {
      const current = prev[productId] || 0;
      const next = Math.max(0, current + delta);
      if (next === 0) {
        const copy = { ...prev };
        delete copy[productId];
        return copy;
      }
      return { ...prev, [productId]: next };
    });
  };

  const calculateCartTotalPaise = () => {
    let sum = 0;
    for (const [prodId, qty] of Object.entries(orderCart)) {
      const prod = products.find((p) => p.id === prodId);
      const pricePaise = prod ? (prod.price_paise || Math.round((prod.price || 0) * 100)) : 0;
      sum += pricePaise * qty;
    }
    return sum;
  };

  const handleSubmitOrder = async () => {
    if (!orderBookingRetailer) return;
    const items = Object.entries(orderCart)
      .filter(([_, qty]) => qty > 0)
      .map(([productId, quantity]) => {
        const prod = products.find((p) => p.id === productId);
        const unitPricePaise = prod ? (prod.price_paise || Math.round((prod.price || 0) * 100)) : 10000;
        return {
          productId,
          quantity,
          unitPricePaise,
          subtotalPaise: unitPricePaise * quantity,
        };
      });

    if (items.length === 0) {
      alert(lang === 'hi' ? 'कृपया कम से कम एक उत्पाद चुनें।' : 'Please select at least one product.');
      return;
    }

    setSubmittingOrder(true);
    try {
      const totalAmountPaise = items.reduce((acc, it) => acc + it.subtotalPaise, 0);
      const orderId = `ord_${Date.now()}`;
      await apiFetch('/orders', {
        method: 'POST',
        body: JSON.stringify({
          order: {
            id: orderId,
            retailerId: orderBookingRetailer.id,
            totalAmountPaise,
            paymentTerms: 'CASH',
            notes: 'Booked via Web Console',
          },
          items,
          idempotencyKey: `idemp_${orderId}`,
        }),
      });

      setMessage(
        lang === 'hi'
          ? `ऑर्डर ₹${(totalAmountPaise / 100).toFixed(2)} सफलतापूर्वक बुक किया गया! मालिक अनुमोदन लंबित।`
          : `Order ₹${(totalAmountPaise / 100).toFixed(2)} booked successfully! Awaiting owner approval.`
      );
      setOrderBookingRetailer(null);
      setOrderCart({});
      await loadAllData();
      setActiveTab('orders');
      setTimeout(() => setMessage(null), 3500);
    } catch (err: any) {
      alert(err.message || 'Order booking failed');
    } finally {
      setSubmittingOrder(false);
    }
  };

  const handleQuickPickAndPack = async (orderId: string) => {
    setActionLoading(orderId);
    try {
      const details = await apiFetch<any>(`/orders/${orderId}`).catch(() => null);
      const itemsList = details?.items || [];
      for (const it of itemsList) {
        const pid = it.productId || it.product_id;
        if (!it.isPicked && pid) {
          await apiFetch(`/orders/${orderId}/pick-item`, {
            method: 'POST',
            body: JSON.stringify({ productId: pid, isPicked: true }),
          }).catch(() => {});
        }
      }
      await apiFetch(`/orders/${orderId}/pack`, {
        method: 'POST',
        body: JSON.stringify({ boxCount: 1 })
      });
      setMessage(lang === 'hi' ? `ऑर्डर ${orderId} पैक हो गया और डिलीवरी के लिए तैयार है!` : `Order ${orderId} packed and ready for dispatch!`);
      await loadAllData();
      setTimeout(() => setMessage(null), 3000);
    } catch (err: any) {
      alert(`Packing error: ${err.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const handleOpenOtpModal = (order: any) => {
    setOtpModalOrder(order);
    setOtpInput('');
    setRecipientNameInput(order.retailer_name || 'Sharma General Store');
    setOtpPaymentMethod('CASH');
    setOtpStatusNote(null);
  };

  const handleRequestOtp = async (orderId: string) => {
    setOtpRequesting(true);
    try {
      const res = await apiFetch<any>(`/orders/${orderId}/request-otp`, { method: 'POST' });
      setOtpStatusNote(res.message || 'OTP sent to retailer mobile');
    } catch (err: any) {
      setOtpStatusNote(`Error: ${err.message}`);
    } finally {
      setOtpRequesting(false);
    }
  };

  const handleConfirmDeliveryWithOtp = async () => {
    if (!otpModalOrder) return;
    if (!otpInput.trim() || otpInput.trim().length !== 6) {
      alert(lang === 'hi' ? 'कृपया 6 अंकों का मान्य OTP दर्ज करें।' : 'Please enter a valid 6-digit OTP.');
      return;
    }
    setOtpVerifying(true);
    try {
      await apiFetch(`/orders/${otpModalOrder.id}/deliver`, {
        method: 'POST',
        body: JSON.stringify({
          otp: otpInput.trim(),
          recipientName: recipientNameInput.trim() || 'Store Owner',
          paymentMethod: otpPaymentMethod,
        }),
      });
      setMessage(
        lang === 'hi'
          ? `ऑर्डर डिलीवर हुआ! COD कैश ₹${((otpModalOrder.total_amount_paise || (otpModalOrder as any).total_amount * 100 || 0) / 100).toFixed(2)} कलेक्ट किया गया।`
          : `Order delivered successfully! Collected ₹${((otpModalOrder.total_amount_paise || (otpModalOrder as any).total_amount * 100 || 0) / 100).toFixed(2)} Cash.`
      );
      setOtpModalOrder(null);
      await loadAllData();
      setTimeout(() => setMessage(null), 3500);
    } catch (err: any) {
      alert(`Delivery OTP verification failed: ${err.message}`);
    } finally {
      setOtpVerifying(false);
    }
  };

  const handleSubmitCashHandover = async (e: React.FormEvent) => {
    e.preventDefault();
    const amountPaise = Math.round((parseFloat(handoverAmountRupees) || 0) * 100);
    if (amountPaise <= 0) {
      alert(lang === 'hi' ? 'अमान्य राशि' : 'Invalid amount');
      return;
    }
    setSubmittingHandover(true);
    try {
      await apiFetch('/cash-handovers', {
        method: 'POST',
        body: JSON.stringify({
          amountPaise,
          notes: handoverNotes.trim() || 'Cash depot handover',
        }),
      });
      setMessage(
        lang === 'hi'
          ? `₹${(amountPaise / 100).toFixed(2)} का कैश हैंडओवर जमा किया गया। मालिक अनुमोदन लंबित।`
          : `Cash handover of ₹${(amountPaise / 100).toFixed(2)} submitted! Awaiting owner acknowledgement.`
      );
      setShowNewHandoverModal(false);
      await loadAllData();
      setTimeout(() => setMessage(null), 3500);
    } catch (err: any) {
      alert(err.message || 'Handover submission failed');
    } finally {
      setSubmittingHandover(false);
    }
  };

  const handleLogout = () => {
    clearSession();
    router.push('/login');
  };

  const filteredOrders = orders.filter((o) => {
    if (orderFilter === 'ALL') return true;
    if (orderFilter === 'PENDING') return o.status === 'PENDING_APPROVAL' || o.status === 'PENDING';
    if (orderFilter === 'APPROVED') return o.status === 'APPROVED' || o.status === 'PICKING' || o.status === 'PACKED';
    if (orderFilter === 'DISPATCHED') return o.status === 'OUT_FOR_DELIVERY';
    if (orderFilter === 'DELIVERED') return o.status === 'DELIVERED';
    return true;
  });

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col">
      {/* Top Navigation */}
      <header className="bg-white/95 backdrop-blur-md border-b border-slate-200/80 sticky top-0 z-30 shadow-xs">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-gradient-to-tr from-blue-700 to-blue-600 rounded-xl shadow-md shadow-blue-500/20 text-white">
              <Truck className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="font-extrabold text-base sm:text-lg text-slate-900 tracking-tight">RouteFlow</span>
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                  {user?.role || 'Executive'}
                </span>
              </div>
              <p className="text-[11px] text-slate-400 font-medium hidden sm:block">Wholesale Fleet & Godown Operations</p>
            </div>
          </div>

          <div className="flex items-center gap-2 sm:gap-3">
            {/* Live Status Pill */}
            <div className="hidden lg:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-50 border border-slate-200 text-slate-600 text-xs">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              <span className="font-medium text-slate-700 text-[11px]">Jaipur Hub Live</span>
            </div>

            {/* User Profile Card */}
            <div className="flex items-center gap-2 pl-2 border-l border-slate-200">
              <div className="w-8 h-8 rounded-full bg-blue-100 border border-blue-200 flex items-center justify-center text-blue-700 font-bold text-xs uppercase">
                {user?.name ? user.name.charAt(0) : 'U'}
              </div>
              <div className="hidden md:block text-left">
                <p className="text-xs font-semibold text-slate-800 leading-tight">{user?.name || 'Administrator'}</p>
                <p className="text-[10px] text-slate-400 capitalize">{user?.role?.toLowerCase().replace(/_/g, ' ')}</p>
              </div>
            </div>

            {/* Language Switcher */}
            <button
              onClick={toggleLanguage}
              className="flex items-center gap-1.5 text-xs font-bold py-1.5 px-2.5 sm:px-3 rounded-xl bg-blue-50 hover:bg-blue-100 text-blue-700 border border-blue-200 transition cursor-pointer min-h-[38px]"
              title="Switch Language / भाषा बदलें"
            >
              <Globe className="w-3.5 h-3.5 text-blue-600" />
              <span>{lang === 'en' ? 'हिन्दी' : 'English'}</span>
            </button>

            <button
              onClick={() => loadAllData(false)}
              disabled={loading}
              className="p-2 text-slate-500 hover:text-slate-800 rounded-xl hover:bg-slate-100 transition cursor-pointer min-h-[38px] min-w-[38px] flex items-center justify-center border border-transparent hover:border-slate-200"
              title="Refresh Data"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-blue-600' : ''}`} />
            </button>
            <button
              onClick={handleLogout}
              className="flex items-center gap-1.5 text-xs font-semibold py-1.5 px-3 rounded-xl bg-slate-50 hover:bg-red-50 text-slate-700 hover:text-red-700 border border-slate-200 hover:border-red-200 transition cursor-pointer min-h-[38px]"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">{lang === 'hi' ? 'लॉगआउट' : 'Logout'}</span>
            </button>
          </div>
        </div>

        {/* Navigation Tabs - Responsive Scrollable Bar */}
        {(() => {
          const role = user?.role?.toUpperCase() || 'OWNER';
          const isOwnerOrAdmin = role === 'OWNER' || role === 'ADMIN';
          const isWarehouse = role === 'WAREHOUSE_MANAGER' || role === 'WAREHOUSE';
          const isDelivery = role === 'DELIVERY_EXECUTIVE' || role === 'DELIVERY';
          const isSales = role === 'SALESPERSON' || role === 'SALES';

          const visibleTabs = [
            ...(isOwnerOrAdmin || isWarehouse ? [{ id: 'overview', label: lang === 'hi' ? 'अवलोकन' : 'Overview', icon: Building, badge: null, badgeColor: '' }] : []),
            ...(isOwnerOrAdmin ? [{ id: 'control_room', label: lang === 'hi' ? 'कंट्रोल रूम' : 'Control Room', icon: DollarSign, badge: null, badgeColor: '' }] : []),
            ...(isOwnerOrAdmin ? [{
              id: 'exceptions',
              label: lang === 'hi' ? 'समस्याएं' : 'Exceptions',
              icon: AlertTriangle,
              badge: exceptionsList.length > 0 ? exceptionsList.length : null,
              badgeColor: exceptionsList.length > 0 ? 'bg-rose-500 text-white' : ''
            }] : []),
            ...(isOwnerOrAdmin ? [{ id: 'cash_control', label: lang === 'hi' ? 'कैश कंट्रोल' : 'Cash Control', icon: CreditCard, badge: null, badgeColor: '' }] : []),
            ...(isOwnerOrAdmin ? [{ id: 'reports', label: lang === 'hi' ? 'रिपोर्ट्स' : 'Reports', icon: FileText, badge: null, badgeColor: '' }] : []),
            {
              id: 'orders',
              label: lang === 'hi' ? 'ऑर्डर्स' : 'Orders',
              icon: Package,
              badge: orders.length,
              badgeColor: 'bg-slate-200 text-slate-700'
            },
            ...(isOwnerOrAdmin || isDelivery ? [{
              id: 'handovers',
              label: lang === 'hi' ? 'कैश हैंडओवर' : 'Cash Handover',
              icon: Wallet,
              badge: handovers.filter(h => h.status === 'PENDING').length > 0 ? handovers.filter(h => h.status === 'PENDING').length : null,
              badgeColor: 'bg-amber-500 text-white'
            }] : []),
            ...(isOwnerOrAdmin || isWarehouse || isSales ? [{
              id: 'products',
              label: lang === 'hi' ? 'गोदाम स्टॉक' : 'Products',
              icon: Truck,
              badge: products.length,
              badgeColor: 'bg-slate-200 text-slate-700'
            }] : []),
            ...(isOwnerOrAdmin || isSales ? [{
              id: 'retailers',
              label: lang === 'hi' ? 'दुकानें' : 'Retailers',
              icon: Store,
              badge: retailers.length,
              badgeColor: 'bg-slate-200 text-slate-700'
            }] : []),
          ];

          return (
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex gap-1.5 sm:gap-2 overflow-x-auto border-t border-slate-100 py-2 scrollbar-none">
              {visibleTabs.map((tab) => {
                const Icon = tab.icon;
                const isSelected = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id as any)}
                    className={`flex items-center gap-1.5 sm:gap-2 px-3 sm:px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition cursor-pointer min-h-[36px] ${
                      isSelected
                        ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/25'
                        : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100/80 border border-transparent hover:border-slate-200/60'
                    }`}
                  >
                    <Icon className="w-3.5 h-3.5" />
                    <span>{tab.label}</span>
                    {tab.badge !== null && (
                      <span className={`px-1.5 py-0.2 rounded-full text-[10px] font-bold ${
                        isSelected ? 'bg-white/20 text-white' : tab.badgeColor || 'bg-slate-100 text-slate-600'
                      }`}>
                        {tab.badge}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          );
        })()}
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-3.5 sm:px-6 lg:px-8 py-4 sm:py-8 pb-28 md:pb-8 flex-1 w-full">
        {/* Role Banner for Field Roles */}
        {(() => {
          const role = user?.role?.toUpperCase() || 'OWNER';
          const isOwnerOrAdmin = role === 'OWNER' || role === 'ADMIN';
          const isWarehouse = role === 'WAREHOUSE_MANAGER' || role === 'WAREHOUSE';
          const isDelivery = role === 'DELIVERY_EXECUTIVE' || role === 'DELIVERY';
          const isSales = role === 'SALESPERSON' || role === 'SALES';

          if (isOwnerOrAdmin) return null;

          return (
            <div className="mb-4 sm:mb-6 p-4 bg-gradient-to-r from-blue-50/80 via-indigo-50/50 to-slate-50 border border-blue-200/80 rounded-2xl text-blue-900 text-xs sm:text-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-xs">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-blue-100/80 text-blue-700 rounded-xl shrink-0">
                  <Smartphone className="w-5 h-5" />
                </div>
                <div>
                  <p className="font-bold text-slate-900">Mobile App Recommended for Field Roles</p>
                  <p className="text-slate-600 text-xs mt-0.5">
                    {isSales && 'Live shop onboarding with GPS, catalog ordering, and cash collections are built for the RouteFlow Android phone app.'}
                    {isWarehouse && 'Real-time picking, packing, and godown scanner operations are optimized for the RouteFlow Android phone app.'}
                    {isDelivery && 'Turn-by-turn route delivery, customer OTP proof, and cash handovers are handled via the RouteFlow Android phone app.'}
                    {' This web console provides fallback office & emergency desktop access.'}
                  </p>
                </div>
              </div>
              <span className="px-3 py-1 bg-white border border-blue-200 text-blue-700 rounded-lg font-semibold text-[11px] whitespace-nowrap self-start sm:self-center shadow-xs">
                Web Fallback Mode
              </span>
            </div>
          );
        })()}

        {message && (
          <div className="mb-4 sm:mb-6 p-3.5 bg-emerald-50 border border-emerald-200 rounded-2xl text-emerald-800 text-xs sm:text-sm flex items-center justify-between shadow-xs">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
              <span>{message}</span>
            </div>
            <button onClick={() => setMessage(null)} className="text-emerald-600 hover:text-emerald-800 ml-4 cursor-pointer p-1 rounded-lg hover:bg-emerald-100/50 transition">
              <X className="w-4 h-4" />
            </button>
          </div>
        )}

        {/* 1. OVERVIEW TAB */}
        {activeTab === 'overview' && (
          <div className="space-y-4 sm:space-y-6">
            <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Business Overview</h1>

            {/* Fresh Company Onboarding Checklist */}
            {(products.length === 0 || retailers.length === 0 || orders.length === 0) && (
              <div className="bg-gradient-to-r from-blue-50/90 via-indigo-50/50 to-white border border-blue-200/90 rounded-2xl p-4 sm:p-6 shadow-xs">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-4">
                  <div>
                    <h2 className="text-base sm:text-lg font-bold text-slate-900 flex items-center gap-2">
                      <span className="p-1.5 bg-blue-600 text-white rounded-lg"><Sparkles className="w-4 h-4" /></span>
                      Getting Started: Company Launch Checklist
                    </h2>
                    <p className="text-xs text-slate-600 mt-0.5">Complete these 5 operational steps to run your wholesale distribution cycle in real time.</p>
                  </div>
                  <span className="px-2.5 py-1 bg-blue-100 text-blue-800 rounded-full font-bold text-xs self-start sm:self-center">
                    {[products.length > 0, retailers.length > 0, deliveryExecutives.length > 0, orders.length > 0, orders.some(o => o.status === 'DELIVERED')].filter(Boolean).length}/5 Completed
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
                  {/* Step 1: Add Products */}
                  <div className={`p-3.5 rounded-xl border transition ${products.length > 0 ? 'bg-emerald-50/60 border-emerald-200' : 'bg-white border-slate-200'}`}>
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Step 1</span>
                      {products.length > 0 ? (
                        <span className="flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-100/80 px-2 py-0.5 rounded-full">
                          <Check className="w-3 h-3" /> {products.length} Added
                        </span>
                      ) : (
                        <span className="text-[11px] font-bold text-amber-700 bg-amber-100/80 px-2 py-0.5 rounded-full">Pending</span>
                      )}
                    </div>
                    <p className="text-xs font-bold text-slate-800">Godown Catalog</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Add products with opening stock & prices</p>
                    <button
                      onClick={() => { setActiveTab('products'); setShowAddProductModal(true); }}
                      className="mt-3 w-full py-1.5 px-2 bg-white hover:bg-slate-50 border border-slate-200 text-blue-600 hover:text-blue-700 font-semibold text-xs rounded-lg transition shadow-2xs cursor-pointer"
                    >
                      + Add Product
                    </button>
                  </div>

                  {/* Step 2: Add Retailers */}
                  <div className={`p-3.5 rounded-xl border transition ${retailers.length > 0 ? 'bg-emerald-50/60 border-emerald-200' : 'bg-white border-slate-200'}`}>
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Step 2</span>
                      {retailers.length > 0 ? (
                        <span className="flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-100/80 px-2 py-0.5 rounded-full">
                          <Check className="w-3 h-3" /> {retailers.length} Added
                        </span>
                      ) : (
                        <span className="text-[11px] font-bold text-amber-700 bg-amber-100/80 px-2 py-0.5 rounded-full">Pending</span>
                      )}
                    </div>
                    <p className="text-xs font-bold text-slate-800">Retail Shops</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Onboard Kirana stores with credit limits</p>
                    <button
                      onClick={() => { setActiveTab('retailers'); setShowAddRetailerModal(true); }}
                      className="mt-3 w-full py-1.5 px-2 bg-white hover:bg-slate-50 border border-slate-200 text-blue-600 hover:text-blue-700 font-semibold text-xs rounded-lg transition shadow-2xs cursor-pointer"
                    >
                      + Add Retailer
                    </button>
                  </div>

                  {/* Step 3: Staff & Fleet */}
                  <div className={`p-3.5 rounded-xl border transition ${deliveryExecutives.length > 0 ? 'bg-emerald-50/60 border-emerald-200' : 'bg-white border-slate-200'}`}>
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Step 3</span>
                      {deliveryExecutives.length > 0 ? (
                        <span className="flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-100/80 px-2 py-0.5 rounded-full">
                          <Check className="w-3 h-3" /> {deliveryExecutives.length} Active
                        </span>
                      ) : (
                        <span className="text-[11px] font-bold text-amber-700 bg-amber-100/80 px-2 py-0.5 rounded-full">Pending</span>
                      )}
                    </div>
                    <p className="text-xs font-bold text-slate-800">Field & Van Team</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Assign delivery drivers & sales staff</p>
                    <button
                      onClick={() => setActiveTab('control_room')}
                      className="mt-3 w-full py-1.5 px-2 bg-white hover:bg-slate-50 border border-slate-200 text-blue-600 hover:text-blue-700 font-semibold text-xs rounded-lg transition shadow-2xs cursor-pointer"
                    >
                      View Control Room
                    </button>
                  </div>

                  {/* Step 4: Book Order */}
                  <div className={`p-3.5 rounded-xl border transition ${orders.length > 0 ? 'bg-emerald-50/60 border-emerald-200' : 'bg-white border-slate-200'}`}>
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Step 4</span>
                      {orders.length > 0 ? (
                        <span className="flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-100/80 px-2 py-0.5 rounded-full">
                          <Check className="w-3 h-3" /> {orders.length} Booked
                        </span>
                      ) : (
                        <span className="text-[11px] font-bold text-amber-700 bg-amber-100/80 px-2 py-0.5 rounded-full">Pending</span>
                      )}
                    </div>
                    <p className="text-xs font-bold text-slate-800">Sales Order</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Book order via sales app or web fallback</p>
                    <button
                      onClick={() => setActiveTab('retailers')}
                      className="mt-3 w-full py-1.5 px-2 bg-white hover:bg-slate-50 border border-slate-200 text-blue-600 hover:text-blue-700 font-semibold text-xs rounded-lg transition shadow-2xs cursor-pointer"
                    >
                      Book Order
                    </button>
                  </div>

                  {/* Step 5: Deliver & Settle */}
                  <div className={`p-3.5 rounded-xl border transition ${orders.some(o => o.status === 'DELIVERED') ? 'bg-emerald-50/60 border-emerald-200' : 'bg-white border-slate-200'}`}>
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Step 5</span>
                      {orders.some(o => o.status === 'DELIVERED') ? (
                        <span className="flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-100/80 px-2 py-0.5 rounded-full">
                          <Check className="w-3 h-3" /> Settled
                        </span>
                      ) : (
                        <span className="text-[11px] font-bold text-amber-700 bg-amber-100/80 px-2 py-0.5 rounded-full">Pending</span>
                      )}
                    </div>
                    <p className="text-xs font-bold text-slate-800">Fulfill & Settle</p>
                    <p className="text-[11px] text-slate-500 mt-0.5">Pick, pack, OTP deliver & settle cash</p>
                    <button
                      onClick={() => setActiveTab('orders')}
                      className="mt-3 w-full py-1.5 px-2 bg-white hover:bg-slate-50 border border-slate-200 text-blue-600 hover:text-blue-700 font-semibold text-xs rounded-lg transition shadow-2xs cursor-pointer"
                    >
                      Track Orders
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* KPI Cards - 2 Columns on Phone, 4 on Desktop */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Pending Approvals</span>
                <div className="mt-1.5 sm:mt-2 text-2xl sm:text-3xl font-extrabold text-blue-600">{metrics.pendingApprovals}</div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-400">Awaiting owner action</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Delivered Sales Today</span>
                <div className="mt-1.5 sm:mt-2 text-xl sm:text-3xl font-extrabold text-emerald-600 truncate">
                  ₹{(metrics.deliveredSalesToday / 100).toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-400">Settled via OTP & Cash</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Picking / Packing</span>
                <div className="mt-1.5 sm:mt-2 text-2xl sm:text-3xl font-extrabold text-amber-600">{metrics.pickingPacking}</div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-400">Active in warehouse</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] sm:text-xs font-semibold text-slate-500 uppercase tracking-wider">Retailer Outstanding</span>
                <div className="mt-1.5 sm:mt-2 text-xl sm:text-3xl font-extrabold text-slate-900 truncate">
                  ₹{(metrics.retailerOutstanding / 100).toLocaleString('en-IN')}
                </div>
                <p className="mt-1 text-[11px] sm:text-xs text-slate-400">Total ledger balance</p>
              </div>
            </div>

            {/* Quick Actions Panel */}
            <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-6 shadow-xs">
              <h2 className="text-sm sm:text-base font-semibold text-slate-900 mb-3 sm:mb-4">Operations Status</h2>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
                <div className="flex items-center gap-3 p-3.5 sm:p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-2.5 sm:p-3 bg-blue-50 text-blue-600 rounded-lg shrink-0">
                    <Truck className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{metrics.outForDelivery} Orders</div>
                    <div className="text-xs text-slate-500">Currently out for delivery</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3.5 sm:p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-2.5 sm:p-3 bg-emerald-50 text-emerald-600 rounded-lg shrink-0">
                    <CheckCircle className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{products.length} Products Active</div>
                    <div className="text-xs text-slate-500">In warehouse inventory catalog</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3.5 sm:p-4 bg-slate-50 rounded-xl border border-slate-200/80">
                  <div className="p-2.5 sm:p-3 bg-purple-50 text-purple-600 rounded-lg shrink-0">
                    <Store className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{retailers.length} Retailers</div>
                    <div className="text-xs text-slate-500">Assigned across sales beats</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 1.1 OWNER CONTROL ROOM TAB */}
        {activeTab === 'control_room' && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Owner Control Room</h1>
                <p className="text-xs sm:text-sm text-slate-500">Live operational command center for daily wholesale & cash flow control</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    const token = getStoredToken();
                    const url = `${API_BASE}/reports/printable/daily-closing${token ? `?token=${token}` : ''}`;
                    window.open(url, '_blank');
                  }}
                  className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold text-xs rounded-xl shadow-xs transition flex items-center gap-1.5 cursor-pointer"
                >
                  <FileText className="w-3.5 h-3.5" />
                  Print Daily Closing Slip
                </button>
              </div>
            </div>

            {/* Live Financial & Ops Grid */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Booked Sales Today</span>
                <div className="mt-1.5 text-2xl font-extrabold text-blue-600">
                  ₹{((controlRoomData?.todaySales?.bookedPaise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-xs text-slate-400">{controlRoomData?.todaySales?.totalOrders || 0} Total Orders Booked</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Cash Collected</span>
                <div className="mt-1.5 text-2xl font-extrabold text-emerald-600">
                  ₹{((controlRoomData?.todayCollections?.cashCollectedPaise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-xs text-slate-400">Net in Hand: ₹{((controlRoomData?.todayCollections?.netCashInHandPaise || 0) / 100).toLocaleString('en-IN')}</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Pending Approvals</span>
                <div className="mt-1.5 text-2xl font-extrabold text-amber-600">
                  {controlRoomData?.todaySales?.pendingApprovals || 0}
                </div>
                <p className="mt-1 text-xs text-slate-400">Awaiting owner sign-off</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Critical Low Stock</span>
                <div className="mt-1.5 text-2xl font-extrabold text-rose-600">
                  {controlRoomData?.inventory?.lowStockCount || 0} SKUs
                </div>
                <p className="mt-1 text-xs text-slate-400">{controlRoomData?.inventory?.outOfStockCount || 0} Out of Stock</p>
              </div>
            </div>

            {/* Split Sections: Top Overdue Retailers & Tomorrow Purchase Suggestions */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {/* Overdue Retailers Card */}
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="font-bold text-slate-900 text-sm sm:text-base flex items-center gap-2">
                    <Store className="w-4 h-4 text-purple-600" />
                    Top Overdue Retailers
                  </h3>
                  <span className="text-xs text-slate-400">Credit Risk Watch</span>
                </div>
                <div className="divide-y divide-slate-100">
                  {controlRoomData?.topOverdueRetailers?.length === 0 ? (
                    <p className="py-4 text-center text-xs text-slate-400">No overdue balances recorded</p>
                  ) : (
                    controlRoomData?.topOverdueRetailers?.map((r: any) => (
                      <div key={r.id} className="py-2.5 flex items-center justify-between text-xs">
                        <div>
                          <p className="font-bold text-slate-800">{r.name}</p>
                          <p className="text-slate-400 text-[11px]">{r.contact_number || 'No phone'} • Beat: {r.beat_id}</p>
                        </div>
                        <div className="text-right">
                          <p className="font-bold text-rose-600">₹{(r.outstanding_amount_paise / 100).toFixed(2)}</p>
                          <p className="text-slate-400 text-[10px]">Limit: ₹{(r.credit_limit_paise / 100).toFixed(0)}</p>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Tomorrow Purchase Suggestions */}
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="font-bold text-slate-900 text-sm sm:text-base flex items-center gap-2">
                    <ShoppingBag className="w-4 h-4 text-emerald-600" />
                    Tomorrow Purchase Suggestions
                  </h3>
                  <span className="text-xs text-slate-400">Inventory Reorder</span>
                </div>
                <div className="divide-y divide-slate-100">
                  {controlRoomData?.tomorrowPurchaseSuggestions?.length === 0 ? (
                    <p className="py-4 text-center text-xs text-slate-400">Inventory levels are healthy</p>
                  ) : (
                    controlRoomData?.tomorrowPurchaseSuggestions?.map((p: any) => (
                      <div key={p.id} className="py-2.5 flex items-center justify-between text-xs">
                        <div>
                          <p className="font-bold text-slate-800">{p.name}</p>
                          <p className="text-slate-400 text-[11px]">SKU: {p.sku} • Stock: <span className="font-semibold text-amber-600">{p.stock_quantity} {p.unit}</span></p>
                        </div>
                        <div className="text-right">
                          <span className="px-2 py-0.5 bg-emerald-50 text-emerald-700 font-bold text-[11px] rounded-md border border-emerald-200">
                            Reorder {p.stock_quantity <= 10 ? 50 : 30} {p.unit}
                          </span>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 1.2 EXCEPTION CENTER TAB */}
        {activeTab === 'exceptions' && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Central Exception Center</h1>
                <p className="text-xs sm:text-sm text-slate-500">Live operational issues requiring manager/owner intervention</p>
              </div>
              <span className="px-3 py-1 bg-rose-50 text-rose-700 border border-rose-200 font-bold text-xs rounded-xl self-start">
                {exceptionsList.length} Active Problems
              </span>
            </div>

            <div className="space-y-3">
              {exceptionsList.length === 0 ? (
                <div className="bg-white border border-slate-200/80 rounded-2xl p-12 text-center shadow-xs">
                  <div className="w-12 h-12 rounded-2xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-600 mx-auto mb-3">
                    <CheckCircle2 className="w-6 h-6" />
                  </div>
                  <h3 className="font-bold text-slate-800 text-sm">Zero Operational Exceptions</h3>
                  <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                    All deliveries, godown picklists, and cash reconciliations are operating within normal tolerances.
                  </p>
                </div>
              ) : (
                exceptionsList.map((exc, idx) => (
                  <div key={idx} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs flex items-start gap-3.5">
                    <div className={`p-2.5 rounded-xl shrink-0 ${exc.severity === 'HIGH' ? 'bg-rose-50 text-rose-600' : 'bg-amber-50 text-amber-600'}`}>
                      <AlertTriangle className="w-5 h-5" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-2">
                        <p className="font-bold text-slate-900 text-sm">{exc.title}</p>
                        <span className={`px-2 py-0.5 text-[10px] font-bold rounded-md ${exc.severity === 'HIGH' ? 'bg-rose-100 text-rose-800' : 'bg-amber-100 text-amber-800'}`}>
                          {exc.severity}
                        </span>
                      </div>
                      <p className="text-slate-600 text-xs mt-1">{exc.description}</p>
                      <p className="text-slate-400 text-[10px] mt-1.5 font-mono">Alert Type: {exc.type}</p>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        )}

        {/* 1.3 CASH CONTROL TAB */}
        {activeTab === 'cash_control' && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Daily Cash Book & Handover Control</h1>
                <p className="text-xs sm:text-sm text-slate-500">Real-time reconciliation of cash collected, delivery handovers, and operating expenses</p>
              </div>
            </div>

            {/* Cash Flow Summary Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Settled Cash In</span>
                <div className="mt-1.5 text-2xl font-extrabold text-emerald-600">
                  ₹{((cashBookData?.summary?.cashInPaise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-xs text-slate-400">Total settled collections today</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Operating Expenses</span>
                <div className="mt-1.5 text-2xl font-extrabold text-rose-600">
                  ₹{((cashBookData?.summary?.expensesPaise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-xs text-slate-400">Fuel, loading & petty cash spent</p>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs">
                <span className="text-[11px] font-semibold text-slate-500 uppercase">Net Cash in Hand</span>
                <div className="mt-1.5 text-2xl font-extrabold text-blue-600">
                  ₹{((cashBookData?.summary?.netCashInHandPaise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
                <p className="mt-1 text-xs text-slate-400">Physical cash awaiting safe deposit</p>
              </div>
            </div>

            {/* Recent Cash Handovers & Expenses Split */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="font-bold text-slate-900 text-sm sm:text-base flex items-center gap-2">
                    <Wallet className="w-4 h-4 text-emerald-600" />
                    Delivery Driver Handovers
                  </h3>
                  <span className="text-xs text-slate-400">{cashBookData?.handovers?.length || 0} Records</span>
                </div>
                <div className="divide-y divide-slate-100">
                  {!cashBookData?.handovers || cashBookData.handovers.length === 0 ? (
                    <p className="py-6 text-center text-xs text-slate-400">No driver cash submissions today</p>
                  ) : (
                    cashBookData.handovers.map((h: any) => (
                      <div key={h.id} className="py-2.5 flex items-center justify-between text-xs">
                        <div>
                          <p className="font-bold text-slate-800">{h.driver_name || 'Driver'}</p>
                          <p className="text-slate-400 text-[11px]">{new Date(h.submitted_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}</p>
                        </div>
                        <div className="text-right">
                          <p className="font-bold text-slate-900">₹{(h.amount_paise / 100).toFixed(2)}</p>
                          <span className={`inline-block px-2 py-0.5 rounded-full text-[10px] font-semibold ${
                            h.status === 'ACCEPTED' ? 'bg-emerald-50 text-emerald-700' : 'bg-amber-50 text-amber-700'
                          }`}>
                            {formatStatusLabel(h.status)}
                          </span>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 shadow-xs space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="font-bold text-slate-900 text-sm sm:text-base flex items-center gap-2">
                    <Receipt className="w-4 h-4 text-rose-600" />
                    Today Business Expenses
                  </h3>
                  <span className="text-xs text-slate-400">{cashBookData?.expenses?.length || 0} Entries</span>
                </div>
                <div className="divide-y divide-slate-100">
                  {!cashBookData?.expenses || cashBookData.expenses.length === 0 ? (
                    <p className="py-6 text-center text-xs text-slate-400">No expenses recorded today</p>
                  ) : (
                    cashBookData.expenses.map((e: any) => (
                      <div key={e.id} className="py-2.5 flex items-center justify-between text-xs">
                        <div>
                          <p className="font-bold text-slate-800">{e.category}: {e.description || 'Expense'}</p>
                          <p className="text-slate-400 text-[11px]">{e.paid_by_name || 'Owner'} • {e.payment_mode}</p>
                        </div>
                        <div className="text-right">
                          <p className="font-bold text-rose-600">-₹{(e.amount_paise / 100).toFixed(2)}</p>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 1.4 REPORTS TAB */}
        {activeTab === 'reports' && (
          <div className="space-y-6">
            <div>
              <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Printable Reports & Statements</h1>
              <p className="text-xs sm:text-sm text-slate-500">Download and print audit-ready business slips, daily closing reports, and retailer ledgers</p>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs space-y-3 flex flex-col justify-between">
                <div>
                  <div className="p-3 bg-blue-50 text-blue-600 rounded-xl w-fit mb-3">
                    <Printer className="w-5 h-5" />
                  </div>
                  <h3 className="font-bold text-slate-900 text-sm">Daily Business Closing Slip</h3>
                  <p className="text-xs text-slate-500 mt-1">Official end-of-day summary with booked sales, cash/UPI collections, expenses and stock deductions.</p>
                </div>
                <button
                  onClick={() => {
                    const token = getStoredToken();
                    const url = `${API_BASE}/reports/printable/daily-closing${token ? `?token=${token}` : ''}`;
                    window.open(url, '_blank');
                  }}
                  className="mt-4 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-semibold text-xs rounded-xl text-center shadow-xs transition cursor-pointer"
                >
                  View & Print Closing Slip
                </button>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs space-y-3 flex flex-col justify-between">
                <div>
                  <div className="p-3 bg-purple-50 text-purple-600 rounded-xl w-fit mb-3">
                    <Store className="w-5 h-5" />
                  </div>
                  <h3 className="font-bold text-slate-900 text-sm">Retailer Ledger Statement</h3>
                  <p className="text-xs text-slate-500 mt-1">Full statement showing invoices, payments, returns, and outstanding credit balance for kirana shops.</p>
                  
                  <div className="mt-3">
                    <label className="block text-[11px] font-semibold text-slate-600 uppercase mb-1">Select Retailer:</label>
                    <select
                      value={selectedReportRetailerId}
                      onChange={(e) => setSelectedReportRetailerId(e.target.value)}
                      className="w-full px-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-purple-500 transition cursor-pointer"
                    >
                      {retailers.length === 0 ? (
                        <option value="">No retailers available</option>
                      ) : (
                        retailers.map((r) => (
                          <option key={r.id} value={r.id}>
                            {r.name} ({r.contact_number || r.beat_id || 'Shop'})
                          </option>
                        ))
                      )}
                    </select>
                  </div>
                </div>
                <button
                  onClick={() => {
                    if (!selectedReportRetailerId) {
                      alert('Please select a retailer first');
                      return;
                    }
                    const token = getStoredToken();
                    const url = `${API_BASE}/reports/printable/retailer-ledger?id=${selectedReportRetailerId}${token ? `&token=${token}` : ''}`;
                    window.open(url, '_blank');
                  }}
                  disabled={!selectedReportRetailerId}
                  className="mt-4 px-4 py-2 bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white font-semibold text-xs rounded-xl text-center shadow-xs transition cursor-pointer"
                >
                  View Retailer Statement
                </button>
              </div>

              <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs space-y-3 flex flex-col justify-between">
                <div>
                  <div className="p-3 bg-emerald-50 text-emerald-600 rounded-xl w-fit mb-3">
                    <Package className="w-5 h-5" />
                  </div>
                  <h3 className="font-bold text-slate-900 text-sm">Inventory Movement Ledger</h3>
                  <p className="text-xs text-slate-500 mt-1">Godown stock ledger tracking supplier inward GRNs, delivery dispatch deductions, and audit corrections.</p>
                </div>
                <button
                  onClick={() => setActiveTab('products')}
                  className="mt-4 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs rounded-xl text-center shadow-xs transition cursor-pointer"
                >
                  View Godown Movement
                </button>
              </div>
            </div>
          </div>
        )}

        {/* 2. ORDERS TAB */}
        {activeTab === 'orders' && (
          <div className="space-y-4 sm:space-y-6">
            <button
              onClick={() => setActiveTab('overview')}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white border border-slate-200 text-slate-700 hover:text-blue-600 hover:border-blue-200 text-xs font-semibold shadow-xs transition cursor-pointer"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>{lang === 'hi' ? 'वापस अवलोकन' : 'Back to Overview'}</span>
            </button>
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
                  {lang === 'hi' ? 'ऑर्डर्स और स्वीकृतियां' : 'Orders & Approvals'}
                </h1>
                <p className="text-xs sm:text-sm text-slate-500">
                  {lang === 'hi' ? 'बुकिंग से डिलीवरी तक ऑर्डर की स्थिति प्रबंधन' : 'Live order state management from booking to delivery'}
                </p>
              </div>

              {/* Status Filter Chips */}
              <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 scrollbar-none">
                {[
                  { id: 'ALL', label: `All (${orders.length})` },
                  { id: 'PENDING', label: `Pending (${orders.filter(o => o.status === 'PENDING_APPROVAL' || o.status === 'PENDING').length})` },
                  { id: 'APPROVED', label: `Warehouse (${orders.filter(o => o.status === 'APPROVED' || o.status === 'PICKING' || o.status === 'PACKED').length})` },
                  { id: 'DISPATCHED', label: `Dispatched (${orders.filter(o => o.status === 'OUT_FOR_DELIVERY').length})` },
                  { id: 'DELIVERED', label: `Delivered (${orders.filter(o => o.status === 'DELIVERED').length})` },
                ].map((f) => (
                  <button
                    key={f.id}
                    onClick={() => setOrderFilter(f.id as any)}
                    className={`px-2.5 py-1 text-xs font-semibold rounded-lg whitespace-nowrap transition cursor-pointer ${
                      orderFilter === f.id
                        ? 'bg-blue-600 text-white shadow-xs'
                        : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    {f.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Mobile Cards (Visible on screens < 768px) */}
            <div className="md:hidden space-y-3">
              {filteredOrders.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center text-slate-400 text-sm">
                  No orders match this filter
                </div>
              ) : (
                filteredOrders.map((o) => (
                  <div key={o.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-xs font-semibold text-slate-900">{o.id}</span>
                      <span
                        className={`inline-flex px-2 py-0.5 rounded-full text-[11px] font-semibold ${
                          o.status === 'DELIVERED'
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : o.status === 'OUT_FOR_DELIVERY'
                            ? 'bg-blue-50 text-blue-700 border border-blue-200'
                            : o.status === 'APPROVED' || o.status === 'PACKED'
                            ? 'bg-amber-50 text-amber-700 border border-amber-200'
                            : 'bg-slate-100 text-slate-700 border border-slate-200'
                        }`}
                      >
                        {formatStatusLabel(o.status)}
                      </span>
                    </div>

                    <div className="flex items-baseline justify-between border-t border-slate-100 pt-2">
                      <div>
                        <div className="text-sm font-semibold text-slate-800">{o.retailer_name || o.retailer_id}</div>
                        <div className="text-xs text-slate-400">Order #{o.id.slice(-6)}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-base font-extrabold text-slate-900">
                          ₹{((o.total_amount_paise || (o as any).total_amount * 100 || 0) / 100).toFixed(2)}
                        </div>
                      </div>
                    </div>

                    {(o.status === 'PENDING_APPROVAL' || o.status === 'PENDING') && (
                      <button
                        onClick={() => handleApproveOrder(o.id)}
                        disabled={actionLoading === o.id}
                        className="w-full flex items-center justify-center py-2.5 px-4 text-xs font-semibold rounded-xl bg-blue-600 hover:bg-blue-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer min-h-[44px]"
                      >
                        <CheckCircle2 className="w-4 h-4 mr-1.5" />
                        {actionLoading === o.id ? (lang === 'hi' ? 'अनुमोदन जारी...' : 'Approving...') : (lang === 'hi' ? 'ऑर्डर स्वीकृत करें' : 'Approve Order')}
                      </button>
                    )}
                    {o.status === 'APPROVED' && (
                      <div className="grid grid-cols-2 gap-2">
                        <button
                          onClick={() => handleQuickPickAndPack(o.id)}
                          disabled={actionLoading === o.id}
                          className="flex items-center justify-center py-2.5 px-3 text-xs font-semibold rounded-xl bg-amber-600 hover:bg-amber-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer min-h-[44px]"
                        >
                          <Package className="w-4 h-4 mr-1.5" />
                          {actionLoading === o.id ? 'Packing...' : (lang === 'hi' ? 'पैक करें' : 'Pick & Pack')}
                        </button>
                        <button
                          onClick={() => setAssignModalOrder(o)}
                          className="flex items-center justify-center py-2.5 px-3 text-xs font-semibold rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white shadow-xs transition cursor-pointer min-h-[44px]"
                        >
                          <Truck className="w-4 h-4 mr-1.5" />
                          {lang === 'hi' ? 'डिस्पैच करें' : 'Assign Delivery'}
                        </button>
                      </div>
                    )}
                    {o.status === 'PACKED' && (
                      <button
                        onClick={() => setAssignModalOrder(o)}
                        className="w-full flex items-center justify-center py-2.5 px-4 text-xs font-semibold rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white shadow-xs transition cursor-pointer min-h-[44px]"
                      >
                        <Truck className="w-4 h-4 mr-1.5" />
                        {lang === 'hi' ? 'डिलीवरी हेतु डिस्पैच' : 'Assign Delivery'}
                      </button>
                    )}
                    {o.status === 'OUT_FOR_DELIVERY' && (
                      <button
                        onClick={() => handleOpenOtpModal(o)}
                        className="w-full flex items-center justify-center py-2.5 px-4 text-xs font-semibold rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs transition cursor-pointer min-h-[44px]"
                      >
                        <Key className="w-4 h-4 mr-1.5" />
                        {lang === 'hi' ? 'OTP सत्यापन व डिलीवरी' : 'Verify OTP & Deliver'}
                      </button>
                    )}
                    {o.status === 'DELIVERED' && (
                      <div className="flex items-center justify-center gap-1.5 text-xs text-emerald-700 bg-emerald-50 py-2 rounded-xl border border-emerald-200 font-semibold">
                        <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                        <span>{lang === 'hi' ? 'डिलीवर व भुगतान प्राप्त' : 'Delivered & COD Collected'}</span>
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>

            {/* Desktop Table (Visible on screens >= 768px) */}
            <div className="hidden md:block bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-700">
                  <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Order ID</th>
                      <th className="px-6 py-4">Retailer</th>
                      <th className="px-6 py-4">Amount</th>
                      <th className="px-6 py-4">Status</th>
                      <th className="px-6 py-4">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredOrders.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="px-6 py-8 text-center text-slate-400">
                          No orders match this filter
                        </td>
                      </tr>
                    ) : (
                      filteredOrders.map((o) => (
                        <tr key={o.id} className="hover:bg-slate-50/80 transition">
                          <td className="px-6 py-4 font-mono font-medium text-slate-900">{o.id}</td>
                          <td className="px-6 py-4 font-medium text-slate-800">{o.retailer_name || o.retailer_id}</td>
                          <td className="px-6 py-4 font-semibold text-slate-900">
                            ₹{((o.total_amount_paise || (o as any).total_amount * 100 || 0) / 100).toFixed(2)}
                          </td>
                          <td className="px-6 py-4">
                            <span
                              className={`inline-flex px-2.5 py-1 rounded-full text-xs font-semibold ${
                                o.status === 'DELIVERED'
                                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                  : o.status === 'OUT_FOR_DELIVERY'
                                  ? 'bg-blue-50 text-blue-700 border border-blue-200'
                                  : o.status === 'APPROVED' || o.status === 'PACKED'
                                  ? 'bg-amber-50 text-amber-700 border border-amber-200'
                                  : 'bg-slate-100 text-slate-700 border border-slate-200'
                              }`}
                            >
                              {formatStatusLabel(o.status)}
                            </span>
                          </td>
                          <td className="px-6 py-4">
                            {o.status === 'PENDING_APPROVAL' || o.status === 'PENDING' ? (
                              <button
                                onClick={() => handleApproveOrder(o.id)}
                                disabled={actionLoading === o.id}
                                className="px-3.5 py-1.5 text-xs font-semibold rounded-lg bg-blue-600 hover:bg-blue-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer"
                              >
                                {actionLoading === o.id ? 'Approving...' : (lang === 'hi' ? 'स्वीकृत करें' : 'Approve')}
                              </button>
                            ) : o.status === 'APPROVED' ? (
                              <div className="flex items-center gap-1.5">
                                <button
                                  onClick={() => handleQuickPickAndPack(o.id)}
                                  disabled={actionLoading === o.id}
                                  className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-amber-600 hover:bg-amber-700 text-white shadow-xs transition cursor-pointer"
                                >
                                  {lang === 'hi' ? 'पैक करें' : 'Pick & Pack'}
                                </button>
                                <button
                                  onClick={() => setAssignModalOrder(o)}
                                  className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white shadow-xs transition cursor-pointer"
                                >
                                  {lang === 'hi' ? 'डिस्पैच' : 'Assign'}
                                </button>
                              </div>
                            ) : o.status === 'PACKED' ? (
                              <button
                                onClick={() => setAssignModalOrder(o)}
                                className="px-3.5 py-1.5 text-xs font-semibold rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white shadow-xs transition cursor-pointer"
                              >
                                {lang === 'hi' ? 'डिस्पैच करें' : 'Assign Delivery'}
                              </button>
                            ) : o.status === 'OUT_FOR_DELIVERY' ? (
                              <button
                                onClick={() => handleOpenOtpModal(o)}
                                className="px-3 py-1.5 text-xs font-semibold rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs transition cursor-pointer flex items-center gap-1"
                              >
                                <Key className="w-3.5 h-3.5" />
                                <span>{lang === 'hi' ? 'OTP डिलीवरी' : 'Verify OTP'}</span>
                              </button>
                            ) : o.status === 'DELIVERED' ? (
                              <span className="text-xs text-emerald-600 font-semibold inline-flex items-center gap-1">
                                <CheckCircle2 className="w-3.5 h-3.5" />
                                <span>{lang === 'hi' ? 'निपटाया गया' : 'Settled'}</span>
                              </span>
                            ) : (
                              <span className="text-xs text-slate-400">—</span>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* 3. CASH HANDOVERS TAB */}
        {activeTab === 'handovers' && (
          <div className="space-y-4 sm:space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
                  {lang === 'hi' ? 'कैश हैंडओवर समाधान' : 'Cash Handover Reconciliation'}
                </h1>
                <p className="text-xs sm:text-sm text-slate-500">
                  {lang === 'hi' ? 'डिलीवरी स्टाफ से भौतिक नकद संग्रह और डिपो समाधान' : 'Acknowledge physical cash collections from delivery executives'}
                </p>
              </div>
              {(user?.role === 'DELIVERY_EXECUTIVE' || user?.role === 'SALESPERSON') && (
                <button
                  onClick={() => setShowNewHandoverModal(true)}
                  className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-xs sm:text-sm font-semibold rounded-xl shadow-xs transition cursor-pointer self-start sm:self-auto min-h-[40px]"
                >
                  <Plus className="w-4 h-4" />
                  <span>{lang === 'hi' ? '+ नया हैंडओवर जमा करें' : '+ Submit Cash Handover'}</span>
                </button>
              )}
            </div>

            {/* Mobile Cards (Visible on screens < 768px) */}
            <div className="md:hidden space-y-3">
              {handovers.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center text-slate-400 text-sm">
                  No cash handovers recorded yet
                </div>
              ) : (
                handovers.map((h) => (
                  <div key={h.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-xs font-semibold text-slate-900">{h.id.slice(0, 14)}...</span>
                      <span
                        className={`inline-flex px-2 py-0.5 rounded-full text-[11px] font-semibold ${
                          h.status === 'ACCEPTED'
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : 'bg-amber-50 text-amber-700 border border-amber-200'
                        }`}
                      >
                        {formatStatusLabel(h.status)}
                      </span>
                    </div>

                    <div className="flex items-baseline justify-between border-t border-slate-100 pt-2">
                      <div>
                        <div className="text-sm font-semibold text-slate-800">{h.driver_name || h.user_id}</div>
                        <div className="text-xs text-slate-400">Delivery Executive</div>
                      </div>
                      <div className="text-right">
                        <div className="text-base font-extrabold text-slate-900">
                          ₹{(h.amount_paise / 100).toFixed(2)}
                        </div>
                      </div>
                    </div>

                    {h.status === 'PENDING' ? (
                      <button
                        onClick={() => handleAcceptHandover(h.id, h.amount_paise)}
                        disabled={actionLoading === h.id}
                        className="w-full flex items-center justify-center py-2.5 px-4 text-xs font-semibold rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer min-h-[40px]"
                      >
                        {actionLoading === h.id ? 'Settling...' : 'Accept Cash'}
                      </button>
                    ) : (
                      <div className="text-center py-1 text-xs text-emerald-600 font-semibold bg-emerald-50 rounded-lg border border-emerald-200">
                        Reconciled & Deposited
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>

            {/* Desktop Table (Visible on screens >= 768px) */}
            <div className="hidden md:block bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-700">
                  <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Handover ID</th>
                      <th className="px-6 py-4">Submitted By</th>
                      <th className="px-6 py-4">Amount</th>
                      <th className="px-6 py-4">Status</th>
                      <th className="px-6 py-4">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {handovers.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="px-6 py-8 text-center text-slate-400">
                          No cash handovers recorded yet
                        </td>
                      </tr>
                    ) : (
                      handovers.map((h) => (
                        <tr key={h.id} className="hover:bg-slate-50/80 transition">
                          <td className="px-6 py-4 font-mono font-medium text-slate-900">{h.id.slice(0, 16)}...</td>
                          <td className="px-6 py-4 font-medium text-slate-800">{h.driver_name || h.user_id}</td>
                          <td className="px-6 py-4 font-bold text-slate-900">
                            ₹{(h.amount_paise / 100).toFixed(2)}
                          </td>
                          <td className="px-6 py-4">
                            <span
                              className={`inline-flex px-2.5 py-1 rounded-full text-xs font-semibold ${
                                h.status === 'ACCEPTED'
                                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                  : 'bg-amber-50 text-amber-700 border border-amber-200'
                              }`}
                            >
                              {formatStatusLabel(h.status)}
                            </span>
                          </td>
                          <td className="px-6 py-4">
                            {h.status === 'PENDING' ? (
                              <button
                                onClick={() => handleAcceptHandover(h.id, h.amount_paise)}
                                disabled={actionLoading === h.id}
                                className="px-3.5 py-1.5 text-xs font-semibold rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs transition disabled:opacity-50 cursor-pointer"
                              >
                                {actionLoading === h.id ? 'Settling...' : 'Accept Cash'}
                              </button>
                            ) : (
                              <span className="text-xs text-emerald-600 font-semibold">Reconciled</span>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* 4. PRODUCTS TAB */}
        {activeTab === 'products' && (
          <div className="space-y-4 sm:space-y-6">
            <button
              onClick={() => setActiveTab('overview')}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white border border-slate-200 text-slate-700 hover:text-blue-600 hover:border-blue-200 text-xs font-semibold shadow-xs transition cursor-pointer"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>{lang === 'hi' ? 'वापस अवलोकन' : 'Back to Overview'}</span>
            </button>
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
                  {lang === 'hi' ? 'मास्टर उत्पाद कैटलॉग (गोदाम स्टॉक)' : 'Master Products Catalog'}
                </h1>
                <p className="text-xs sm:text-sm text-slate-500">
                  {lang === 'hi' ? 'थोक वितरण और गोदाम इन्वेंट्री वस्तुएं' : 'Inventory items available for wholesale distribution'}
                </p>
              </div>
              <button
                onClick={() => setShowAddProductModal(true)}
                className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl shadow-xs transition cursor-pointer self-start sm:self-auto"
              >
                <Plus className="w-4 h-4" />
                <span>Add Product</span>
              </button>
            </div>

            {/* Mobile Cards (Visible on screens < 768px) */}
            <div className="md:hidden space-y-3">
              {products.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center text-slate-400 text-sm">
                  No products found
                </div>
              ) : (
                products.map((p) => (
                  <div key={p.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs flex items-center justify-between">
                    <div>
                      <div className="text-sm font-semibold text-slate-900">{p.name}</div>
                      <div className="text-xs font-mono text-slate-400 mt-0.5">{p.sku || p.id}</div>
                      <div className="text-xs text-slate-500 mt-1">
                        Stock: <span className="font-semibold text-slate-700">{p.stock_quantity ?? p.stock ?? 'In Stock'}</span>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-base font-extrabold text-slate-900">
                        ₹{((p.price_paise || p.price * 100 || 0) / 100).toFixed(2)}
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>

            {/* Desktop Table (Visible on screens >= 768px) */}
            <div className="hidden md:block bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-700">
                  <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Product Name</th>
                      <th className="px-6 py-4">SKU / Barcode</th>
                      <th className="px-6 py-4">Price</th>
                      <th className="px-6 py-4">Stock (Godown)</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {products.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="px-6 py-8 text-center text-slate-400">
                          No products found
                        </td>
                      </tr>
                    ) : (
                      products.map((p) => (
                        <tr key={p.id} className="hover:bg-slate-50/80 transition">
                          <td className="px-6 py-4">
                            <div className="font-semibold text-slate-900">{p.name}</div>
                            {p.hindi_name && <div className="text-xs text-slate-400">{p.hindi_name}</div>}
                          </td>
                          <td className="px-6 py-4">
                            <div className="font-mono text-xs text-slate-600">{p.sku || p.id}</div>
                            {p.barcode && (
                              <div className="text-[11px] font-mono text-blue-600 font-semibold inline-flex items-center gap-1 mt-0.5">
                                <Barcode className="w-3 h-3 text-blue-500" />
                                {p.barcode}
                              </div>
                            )}
                          </td>
                          <td className="px-6 py-4 font-semibold text-slate-900">
                            ₹{((p.price_paise || p.price * 100 || 0) / 100).toFixed(2)}
                          </td>
                          <td className="px-6 py-4">
                            <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${
                              (p.stock_quantity ?? p.stock ?? 0) > 20
                                ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                : 'bg-amber-50 text-amber-700 border border-amber-200'
                            }`}>
                              {p.stock_quantity ?? p.stock ?? '0'} {p.unit || 'units'}
                            </span>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* 5. RETAILERS TAB */}
        {activeTab === 'retailers' && (
          <div className="space-y-4 sm:space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">Retailers & Distribution Network</h1>
                <p className="text-xs sm:text-sm text-slate-500">Registered shops and wholesale distribution accounts</p>
              </div>
              <button
                onClick={() => setShowAddRetailerModal(true)}
                className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl shadow-xs transition cursor-pointer self-start sm:self-auto"
              >
                <Plus className="w-4 h-4" />
                <span>Add Retailer / Shop</span>
              </button>
            </div>

            {/* Mobile Cards (Visible on screens < 768px) */}
            <div className="md:hidden space-y-3">
              {retailers.length === 0 ? (
                <div className="bg-white border border-slate-200 rounded-2xl p-8 text-center text-slate-400 text-sm">
                  No retailers found
                </div>
              ) : (
                retailers.map((r) => (
                  <div key={r.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-xs space-y-2">
                    <div className="flex items-start justify-between">
                      <div>
                        <div className="text-sm font-semibold text-slate-900">{r.name}</div>
                        <div className="text-xs text-slate-500 mt-0.5">{r.contact_number || 'No contact'}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-xs text-slate-400">Credit Limit</div>
                        <div className="text-sm font-extrabold text-slate-900">
                          ₹{((r.credit_limit_paise || 0) / 100).toLocaleString('en-IN')}
                        </div>
                      </div>
                    </div>
                    {r.address && (
                      <div className="text-xs text-slate-400 border-t border-slate-100 pt-2 truncate">
                        {r.address}
                      </div>
                    )}
                    <div className="pt-2 border-t border-slate-100 flex items-center justify-end gap-2">
                      <button
                        onClick={() => handleOpenOrderBooking(r)}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-xl transition cursor-pointer shadow-xs min-h-[38px]"
                      >
                        <ShoppingCart className="w-3.5 h-3.5" />
                        <span>{lang === 'hi' ? 'ऑर्डर बुक करें' : 'Book Order'}</span>
                      </button>
                      <button
                        onClick={() => handleOpenRetailer360(r.id)}
                        className="px-3 py-1.5 text-xs font-semibold text-blue-700 bg-blue-50 hover:bg-blue-100 rounded-xl transition cursor-pointer min-h-[38px]"
                      >
                        {lang === 'hi' ? 'खाता 360 →' : 'Retailer 360 →'}
                      </button>
                    </div>
                  </div>
                ))
              )}
            </div>

            {/* Desktop Table (Visible on screens >= 768px) */}
            <div className="hidden md:block bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-xs">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm text-slate-700">
                  <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Retailer Name</th>
                      <th className="px-6 py-4">Contact</th>
                      <th className="px-6 py-4">Address</th>
                      <th className="px-6 py-4">Credit Limit</th>
                      <th className="px-6 py-4 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {retailers.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="px-6 py-8 text-center text-slate-400">
                          No retailers found
                        </td>
                      </tr>
                    ) : (
                      retailers.map((r) => (
                        <tr key={r.id} className="hover:bg-slate-50/80 transition">
                          <td className="px-6 py-4 font-semibold text-slate-900">{r.name}</td>
                          <td className="px-6 py-4 text-slate-600">{r.contact_number || '—'}</td>
                          <td className="px-6 py-4 text-slate-500">{r.address || '—'}</td>
                          <td className="px-6 py-4 font-semibold text-slate-900">
                            ₹{((r.credit_limit_paise || 0) / 100).toLocaleString('en-IN')}
                          </td>
                          <td className="px-6 py-4 text-right">
                            <div className="inline-flex items-center gap-2">
                              <button
                                onClick={() => handleOpenOrderBooking(r)}
                                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-xs transition cursor-pointer"
                              >
                                <ShoppingCart className="w-3.5 h-3.5" />
                                <span>{lang === 'hi' ? 'ऑर्डर बुक करें' : 'Book Order'}</span>
                              </button>
                              <button
                                onClick={() => handleOpenRetailer360(r.id)}
                                className="px-3 py-1.5 text-xs font-semibold text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition cursor-pointer"
                              >
                                {lang === 'hi' ? 'खाता 360' : 'Retailer 360'}
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* ADD RETAILER MODAL */}
        {showAddRetailerModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
            <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-6 border border-slate-200 max-h-[90vh] overflow-y-auto space-y-5 animate-in fade-in zoom-in-95 duration-150">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div>
                  <h3 className="text-lg font-bold text-slate-900">Add New Shop / Wholesale</h3>
                  <p className="text-xs text-slate-500">Register a new retail or wholesale counter</p>
                </div>
                <button
                  type="button"
                  onClick={() => setShowAddRetailerModal(false)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <form onSubmit={handleCreateRetailer} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    Shop / Wholesale Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Laxmi Wholesale & Retail"
                    value={newRetailer.name}
                    onChange={(e) => setNewRetailer({ ...newRetailer, name: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                  />
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Contact Phone
                    </label>
                    <div className="relative">
                      <Phone className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                      <input
                        type="text"
                        placeholder="e.g. 9876543210"
                        value={newRetailer.contactNumber}
                        onChange={(e) => setNewRetailer({ ...newRetailer, contactNumber: e.target.value })}
                        className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Credit Limit (₹)
                    </label>
                    <input
                      type="number"
                      placeholder="5000"
                      value={newRetailer.creditLimitRupees}
                      onChange={(e) => setNewRetailer({ ...newRetailer, creditLimitRupees: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    Address
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. Shop #14, Main Wholesale Market"
                    value={newRetailer.address}
                    onChange={(e) => setNewRetailer({ ...newRetailer, address: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                  />
                </div>

                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider">
                      Location / GPS Coordinates
                    </label>
                    <button
                      type="button"
                      onClick={handleDetectLocation}
                      disabled={detectingLocation}
                      className="inline-flex items-center gap-1.5 text-xs text-blue-600 hover:text-blue-700 font-semibold cursor-pointer disabled:opacity-50"
                    >
                      <MapPin className="w-3.5 h-3.5" />
                      {detectingLocation ? 'Detecting...' : 'Auto-Detect Location'}
                    </button>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <input
                      type="text"
                      placeholder="Latitude"
                      value={newRetailer.latitude}
                      onChange={(e) => setNewRetailer({ ...newRetailer, latitude: e.target.value })}
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                    <input
                      type="text"
                      placeholder="Longitude"
                      value={newRetailer.longitude}
                      onChange={(e) => setNewRetailer({ ...newRetailer, longitude: e.target.value })}
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>
                </div>

                <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setShowAddRetailerModal(false)}
                    className="px-4 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={creatingRetailer}
                    className="px-5 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-xs transition disabled:opacity-50 cursor-pointer"
                  >
                    {creatingRetailer ? 'Adding...' : 'Add Shop'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ADD PRODUCT MODAL */}
        {showAddProductModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
            <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-6 border border-slate-200 max-h-[90vh] overflow-y-auto space-y-5 animate-in fade-in zoom-in-95 duration-150">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div>
                  <h3 className="text-lg font-bold text-slate-900">Add Product to Catalog</h3>
                  <p className="text-xs text-slate-500">Add an inventory item available for wholesale distribution</p>
                </div>
                <button
                  type="button"
                  onClick={() => setShowAddProductModal(false)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <form onSubmit={handleCreateProduct} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    Product / Item Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Masala Chai 500g Pack"
                    value={newProduct.name}
                    onChange={(e) => setNewProduct({ ...newProduct, name: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Category
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Beverages, Spices"
                      value={newProduct.category}
                      onChange={(e) => setNewProduct({ ...newProduct, category: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Unit
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Pack, Box, Kg"
                      value={newProduct.unit}
                      onChange={(e) => setNewProduct({ ...newProduct, unit: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Price (₹) *
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      required
                      placeholder="100.00"
                      value={newProduct.priceRupees}
                      onChange={(e) => setNewProduct({ ...newProduct, priceRupees: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                      Warehouse Stock *
                    </label>
                    <input
                      type="number"
                      required
                      placeholder="50"
                      value={newProduct.stockQuantity}
                      onChange={(e) => setNewProduct({ ...newProduct, stockQuantity: e.target.value })}
                      className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition"
                    />
                  </div>
                </div>

                <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setShowAddProductModal(false)}
                    className="px-4 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={creatingProduct}
                    className="px-5 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-xs transition disabled:opacity-50 cursor-pointer"
                  >
                    {creatingProduct ? 'Adding...' : 'Add Product'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ASSIGN DELIVERY MODAL */}
        {assignModalOrder && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
            <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-6 border border-slate-200 space-y-5 animate-in fade-in zoom-in-95 duration-150">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div>
                  <h3 className="text-lg font-bold text-slate-900">Assign Goods to Delivery</h3>
                  <p className="text-xs text-slate-500">Dispatch order to designated delivery executive</p>
                </div>
                <button
                  type="button"
                  onClick={() => setAssignModalOrder(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="space-y-4">
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200 text-xs space-y-1.5">
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Order ID:</span>
                    <span className="font-mono font-bold text-slate-900">{assignModalOrder.id}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Retailer / Shop:</span>
                    <span className="font-semibold text-slate-900">{assignModalOrder.retailer_name || assignModalOrder.retailer_id}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Total Value:</span>
                    <span className="font-bold text-slate-900">₹{((assignModalOrder.total_amount_paise || (assignModalOrder as any).total_amount * 100 || 0) / 100).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Status:</span>
                    <span className="font-semibold text-amber-700">{formatStatusLabel(assignModalOrder.status)}</span>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    Select Delivery Executive *
                  </label>
                  {deliveryExecutives.length === 0 ? (
                    <div className="p-3 bg-amber-50 text-amber-800 text-xs rounded-xl border border-amber-200">
                      No active delivery executives found. Please ensure a delivery executive account exists.
                    </div>
                  ) : (
                    <select
                      value={selectedDriverId}
                      onChange={(e) => setSelectedDriverId(e.target.value)}
                      className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:bg-white transition cursor-pointer"
                    >
                      {deliveryExecutives.map((d) => (
                        <option key={d.id} value={d.id}>
                          {d.fullName || d.username} (@{d.username})
                        </option>
                      ))}
                    </select>
                  )}
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setAssignModalOrder(null)}
                  className="px-4 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleAssignDelivery}
                  disabled={assigningLoading || !selectedDriverId}
                  className="px-5 py-2 text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-700 rounded-xl shadow-xs transition disabled:opacity-50 cursor-pointer"
                >
                  {assigningLoading ? 'Assigning...' : 'Assign & Dispatch'}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* RETAILER 360 DOSSIER MODAL */}
        {selectedRetailer360 && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
            <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full p-6 border border-slate-200 max-h-[90vh] overflow-y-auto space-y-5 animate-in fade-in zoom-in-95 duration-150">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 bg-blue-50 text-blue-600 rounded-xl">
                    <Store className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-lg font-bold text-slate-900">{selectedRetailer360.retailer?.name}</h3>
                    <p className="text-xs text-slate-500">Beat: {selectedRetailer360.retailer?.beat_name || selectedRetailer360.retailer?.beat_id} • Phone: {selectedRetailer360.retailer?.contact_number || 'None'}</p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setSelectedRetailer360(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Financial Snapshot */}
              <div className="grid grid-cols-3 gap-3">
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200 text-center">
                  <span className="text-[10px] font-bold text-slate-500 uppercase">Outstanding Credit</span>
                  <div className="text-base font-extrabold text-rose-600 mt-1">
                    ₹{((selectedRetailer360.retailer?.outstanding_amount_paise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                  </div>
                </div>
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200 text-center">
                  <span className="text-[10px] font-bold text-slate-500 uppercase">Credit Limit</span>
                  <div className="text-base font-extrabold text-slate-900 mt-1">
                    ₹{((selectedRetailer360.retailer?.credit_limit_paise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                  </div>
                </div>
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200 text-center">
                  <span className="text-[10px] font-bold text-slate-500 uppercase">Credit Utilization</span>
                  <div className="text-base font-extrabold text-amber-600 mt-1">
                    {selectedRetailer360.retailer?.credit_limit_paise > 0
                      ? `${Math.round(((selectedRetailer360.retailer?.outstanding_amount_paise || 0) / selectedRetailer360.retailer?.credit_limit_paise) * 100)}%`
                      : '0%'}
                  </div>
                </div>
              </div>

              {/* Order History */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider">Recent Orders (Last 5)</h4>
                <div className="border border-slate-200 rounded-xl overflow-hidden divide-y divide-slate-100">
                  {selectedRetailer360.orders?.length === 0 ? (
                    <p className="p-4 text-center text-xs text-slate-400">No orders recorded yet</p>
                  ) : (
                    selectedRetailer360.orders?.map((o: any) => (
                      <div key={o.id} className="p-3 flex items-center justify-between text-xs hover:bg-slate-50">
                        <div>
                          <p className="font-mono font-bold text-slate-900">{o.id.slice(0, 14)}...</p>
                          <p className="text-slate-400 text-[11px]">{new Date(o.created_at).toLocaleDateString('en-IN')} • By {o.booked_by_name || 'Sales'}</p>
                        </div>
                        <div className="text-right">
                          <p className="font-bold text-slate-900">₹{(o.total_amount_paise / 100).toFixed(2)}</p>
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-blue-50 text-blue-700 border border-blue-200">
                            {formatStatusLabel(o.status)}
                          </span>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Actions: WhatsApp Statement Share */}
              <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                {selectedRetailer360.whatsAppShareUrl ? (
                  <a
                    href={selectedRetailer360.whatsAppShareUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold rounded-xl shadow-xs transition"
                  >
                    <MessageSquare className="w-3.5 h-3.5" />
                    <span>Share Statement on WhatsApp</span>
                  </a>
                ) : (
                  <span className="text-xs text-slate-400">No phone for WhatsApp</span>
                )}
                <button
                  type="button"
                  onClick={() => setSelectedRetailer360(null)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        )}

        {/* SALES ORDER BOOKING CART MODAL */}
        {orderBookingRetailer && (
          <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-900/60 backdrop-blur-xs">
            <div className="bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl max-w-lg w-full p-5 sm:p-6 border border-slate-200 max-h-[90vh] overflow-y-auto space-y-4 animate-in slide-in-from-bottom sm:zoom-in-95 duration-200">
              <div className="w-12 h-1.5 bg-slate-300 rounded-full mx-auto mb-1 sm:hidden shrink-0" />
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 bg-blue-50 text-blue-600 rounded-xl">
                    <ShoppingCart className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-base sm:text-lg font-bold text-slate-900">
                      {lang === 'hi' ? 'ऑर्डर बुक करें' : 'Book Field Order'}
                    </h3>
                    <p className="text-xs text-slate-500">
                      {orderBookingRetailer.name} • Beat {orderBookingRetailer.beat_name || orderBookingRetailer.beat_id || 'BEAT-04'}
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setOrderBookingRetailer(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Quick Fill Button */}
              <div className="flex items-center justify-between p-2.5 bg-blue-50/70 border border-blue-200/80 rounded-xl">
                <div className="text-xs text-blue-900 font-medium">
                  {lang === 'hi' ? 'डेमो कैनोनिकल ऑर्डर भरें:' : 'Canonical Demo Preset:'}
                  <span className="font-bold block sm:inline sm:ml-1">10 Tea + 5 Biscuits + 2 Oil = ₹3,450.00</span>
                </div>
                <button
                  type="button"
                  onClick={handleQuickFillDemoOrder}
                  className="px-2.5 py-1 text-xs font-bold bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition cursor-pointer shrink-0"
                >
                  {lang === 'hi' ? 'क्विक-फिल' : 'Quick-Fill'}
                </button>
              </div>

              {/* Products Item List with Stepper */}
              <div className="space-y-2 max-h-[40vh] overflow-y-auto pr-1">
                {products.length === 0 ? (
                  <p className="text-xs text-slate-400 text-center py-4">No products in catalog</p>
                ) : (
                  products.map((p) => {
                    const pricePaise = p.price_paise || Math.round((p.price || 0) * 100);
                    const qty = orderCart[p.id] || 0;
                    return (
                      <div key={p.id} className="p-3 bg-slate-50 rounded-xl border border-slate-200/80 flex items-center justify-between gap-3">
                        <div className="flex-1 min-w-0">
                          <p className="text-xs sm:text-sm font-semibold text-slate-900 truncate">{p.name}</p>
                          <p className="text-[11px] text-slate-500">
                            ₹{(pricePaise / 100).toFixed(2)} / {p.unit || 'unit'} • Stock: {p.stock_quantity ?? p.stock ?? 'Available'}
                          </p>
                        </div>
                        <div className="flex items-center gap-2 shrink-0">
                          <button
                            type="button"
                            onClick={() => handleUpdateCartQuantity(p.id, -1)}
                            disabled={qty === 0}
                            className="w-8 h-8 rounded-lg bg-white border border-slate-300 text-slate-700 hover:bg-slate-100 flex items-center justify-center font-bold disabled:opacity-30 cursor-pointer"
                          >
                            <Minus className="w-3.5 h-3.5" />
                          </button>
                          <span className="w-7 text-center font-bold text-sm text-slate-900">{qty}</span>
                          <button
                            type="button"
                            onClick={() => handleUpdateCartQuantity(p.id, 1)}
                            className="w-8 h-8 rounded-lg bg-blue-600 text-white hover:bg-blue-700 flex items-center justify-center font-bold cursor-pointer"
                          >
                            <Plus className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>

              {/* Cart Summary & Submit */}
              <div className="pt-3 border-t border-slate-100 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-semibold text-slate-600">
                    {lang === 'hi' ? 'कुल राशि (देय):' : 'Total Amount Due:'}
                  </span>
                  <span className="text-lg font-black text-slate-900">
                    ₹{(calculateCartTotalPaise() / 100).toFixed(2)}
                  </span>
                </div>

                <div className="flex items-center justify-end gap-2.5">
                  <button
                    type="button"
                    onClick={() => setOrderBookingRetailer(null)}
                    className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer min-h-[40px]"
                  >
                    {lang === 'hi' ? 'रद्द करें' : 'Cancel'}
                  </button>
                  <button
                    type="button"
                    onClick={handleSubmitOrder}
                    disabled={submittingOrder || calculateCartTotalPaise() === 0}
                    className="px-5 py-2 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-md shadow-blue-500/20 transition disabled:opacity-50 cursor-pointer min-h-[40px] flex items-center gap-1.5"
                  >
                    <CheckCircle2 className="w-4 h-4" />
                    <span>{submittingOrder ? (lang === 'hi' ? 'बुकिंग जारी...' : 'Submitting...') : (lang === 'hi' ? 'ऑर्डर की पुष्टि करें' : 'Confirm Order')}</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* DELIVERY OTP VERIFICATION MODAL */}
        {otpModalOrder && (
          <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-900/60 backdrop-blur-xs">
            <div className="bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl max-w-md w-full p-5 sm:p-6 border border-slate-200 max-h-[90vh] overflow-y-auto space-y-4 animate-in slide-in-from-bottom sm:zoom-in-95 duration-200">
              <div className="w-12 h-1.5 bg-slate-300 rounded-full mx-auto mb-1 sm:hidden shrink-0" />
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 bg-emerald-50 text-emerald-600 rounded-xl">
                    <Key className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-base sm:text-lg font-bold text-slate-900">
                      {lang === 'hi' ? 'डिलीवरी OTP सत्यापन' : 'Verify Delivery OTP'}
                    </h3>
                    <p className="text-xs text-slate-500">
                      Order #{otpModalOrder.id.slice(-6)} • {otpModalOrder.retailer_name || 'Sharma General Store'}
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setOtpModalOrder(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Order Info & COD Amount */}
              <div className="p-3 bg-slate-50 border border-slate-200/80 rounded-xl text-xs space-y-1.5">
                <div className="flex justify-between">
                  <span className="text-slate-500 font-medium">{lang === 'hi' ? 'दुकानदार:' : 'Retailer:'}</span>
                  <span className="font-bold text-slate-900">{otpModalOrder.retailer_name || otpModalOrder.retailer_id}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500 font-medium">{lang === 'hi' ? 'कलेक्ट करने योग्य नकद (COD):' : 'Cash to Collect (COD):'}</span>
                  <span className="font-extrabold text-emerald-700 text-sm">
                    ₹{((otpModalOrder.total_amount_paise || (otpModalOrder as any).total_amount * 100 || 0) / 100).toFixed(2)}
                  </span>
                </div>
              </div>

              {/* Request OTP Button & Status Note */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                    {lang === 'hi' ? '6-अंकीय OTP कोड' : '6-Digit Delivery OTP'}
                  </label>
                  <button
                    type="button"
                    onClick={() => handleRequestOtp(otpModalOrder.id)}
                    disabled={otpRequesting}
                    className="text-xs text-blue-600 hover:text-blue-700 font-semibold cursor-pointer underline disabled:opacity-50"
                  >
                    {otpRequesting ? 'Requesting...' : (lang === 'hi' ? 'ग्राहक को OTP भेजें (SMS)' : 'Request Customer OTP')}
                  </button>
                </div>
                <input
                  type="text"
                  maxLength={6}
                  placeholder="e.g. 123456"
                  value={otpInput}
                  onChange={(e) => setOtpInput(e.target.value)}
                  className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-center text-xl font-mono tracking-widest font-black focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:bg-white transition"
                />
                {otpStatusNote && (
                  <p className="text-[11px] text-blue-700 bg-blue-50 p-2 rounded-lg border border-blue-100">
                    {otpStatusNote}
                  </p>
                )}
              </div>

              {/* Recipient Name Input */}
              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1">
                  {lang === 'hi' ? 'प्राप्तकर्ता का नाम' : 'Recipient Name'}
                </label>
                <input
                  type="text"
                  placeholder="e.g. Ramesh Sharma"
                  value={recipientNameInput}
                  onChange={(e) => setRecipientNameInput(e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:bg-white transition"
                />
              </div>

              {/* Payment Method Selector */}
              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1">
                  {lang === 'hi' ? 'भुगतान का प्रकार' : 'Payment Method'}
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setOtpPaymentMethod('CASH')}
                    className={`py-2 px-3 rounded-xl text-xs font-bold border transition cursor-pointer ${
                      otpPaymentMethod === 'CASH'
                        ? 'bg-emerald-50 border-emerald-400 text-emerald-800'
                        : 'bg-slate-50 border-slate-200 text-slate-600'
                    }`}
                  >
                    Cash (COD)
                  </button>
                  <button
                    type="button"
                    onClick={() => setOtpPaymentMethod('CREDIT')}
                    className={`py-2 px-3 rounded-xl text-xs font-bold border transition cursor-pointer ${
                      otpPaymentMethod === 'CREDIT'
                        ? 'bg-blue-50 border-blue-400 text-blue-800'
                        : 'bg-slate-50 border-slate-200 text-slate-600'
                    }`}
                  >
                    Credit (Udhaar)
                  </button>
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setOtpModalOrder(null)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer min-h-[40px]"
                >
                  {lang === 'hi' ? 'रद्द करें' : 'Cancel'}
                </button>
                <button
                  type="button"
                  onClick={handleConfirmDeliveryWithOtp}
                  disabled={otpVerifying || otpInput.length !== 6}
                  className="px-5 py-2 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl shadow-md shadow-emerald-500/20 transition disabled:opacity-50 cursor-pointer min-h-[40px] flex items-center gap-1.5"
                >
                  <CheckCircle2 className="w-4 h-4" />
                  <span>{otpVerifying ? (lang === 'hi' ? 'सत्यापन जारी...' : 'Verifying...') : (lang === 'hi' ? 'डिलीवरी पूर्ण करें' : 'Confirm Delivery')}</span>
                </button>
              </div>
            </div>
          </div>
        )}

        {/* SUBMIT CASH HANDOVER MODAL */}
        {showNewHandoverModal && (
          <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-900/60 backdrop-blur-xs">
            <div className="bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl max-w-md w-full p-5 sm:p-6 border border-slate-200 max-h-[90vh] overflow-y-auto space-y-4 animate-in slide-in-from-bottom sm:zoom-in-95 duration-200">
              <div className="w-12 h-1.5 bg-slate-300 rounded-full mx-auto mb-1 sm:hidden shrink-0" />
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 bg-emerald-50 text-emerald-600 rounded-xl">
                    <Wallet className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-base sm:text-lg font-bold text-slate-900">
                      {lang === 'hi' ? 'कैश हैंडओवर जमा करें' : 'Submit Cash Handover'}
                    </h3>
                    <p className="text-xs text-slate-500">
                      {lang === 'hi' ? 'कलेक्शन नकद डिपो कैशियर को सौंपें' : 'Hand over collected COD cash to depot manager'}
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setShowNewHandoverModal(false)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <form onSubmit={handleSubmitCashHandover} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    {lang === 'hi' ? 'हैंडओवर राशि (₹) *' : 'Handover Amount (₹) *'}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={handoverAmountRupees}
                    onChange={(e) => setHandoverAmountRupees(e.target.value)}
                    className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-lg font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:bg-white transition"
                    placeholder="3450.00"
                  />
                  <p className="text-[11px] text-slate-400 mt-1">
                    Canonical demo amount: ₹3,450.00 (Sharma General Store settlement)
                  </p>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                    {lang === 'hi' ? 'टिप्पणी / विवरण' : 'Notes / Remarks'}
                  </label>
                  <input
                    type="text"
                    value={handoverNotes}
                    onChange={(e) => setHandoverNotes(e.target.value)}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:bg-white transition"
                    placeholder="e.g. Evening route COD cash"
                  />
                </div>

                <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setShowNewHandoverModal(false)}
                    className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer min-h-[40px]"
                  >
                    {lang === 'hi' ? 'रद्द करें' : 'Cancel'}
                  </button>
                  <button
                    type="submit"
                    disabled={submittingHandover}
                    className="px-5 py-2 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl shadow-md shadow-emerald-500/20 transition disabled:opacity-50 cursor-pointer min-h-[40px]"
                  >
                    {submittingHandover ? (lang === 'hi' ? 'जमा हो रहा है...' : 'Submitting...') : (lang === 'hi' ? 'हैंडओवर जमा करें' : 'Submit Handover')}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* MOBILE MORE MENU DRAWER */}
        {showMoreMobileMenu && (
          <div className="md:hidden fixed inset-0 z-50 flex items-end justify-center bg-slate-900/60 backdrop-blur-xs">
            <div className="bg-white rounded-t-3xl shadow-2xl w-full p-5 border border-slate-200 max-h-[85vh] overflow-y-auto space-y-4 animate-in slide-in-from-bottom duration-200">
              <div className="w-12 h-1.5 bg-slate-300 rounded-full mx-auto mb-1 shrink-0" />
              <div className="flex items-center justify-between pb-2 border-b border-slate-100">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-full bg-blue-100 border border-blue-200 flex items-center justify-center text-blue-700 font-bold text-xs uppercase">
                    {user?.name ? user.name.charAt(0) : 'U'}
                  </div>
                  <div>
                    <p className="text-xs font-bold text-slate-900 leading-tight">{user?.name || 'Administrator'}</p>
                    <p className="text-[10px] text-slate-400 capitalize">{user?.role?.toLowerCase().replace(/_/g, ' ')}</p>
                  </div>
                </div>
                <button
                  onClick={() => setShowMoreMobileMenu(false)}
                  className="p-1 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Quick Navigation Items */}
              <div className="grid grid-cols-2 gap-2 text-xs font-semibold">
                <button
                  onClick={() => { setActiveTab('control_room'); setShowMoreMobileMenu(false); }}
                  className="p-3 bg-slate-50 hover:bg-blue-50 border border-slate-200/80 rounded-xl text-left flex items-center gap-2 text-slate-800 hover:text-blue-700 transition cursor-pointer"
                >
                  <DollarSign className="w-4 h-4 text-blue-600" />
                  <span>{lang === 'hi' ? 'कंट्रोल रूम' : 'Control Room'}</span>
                </button>

                <button
                  onClick={() => { setActiveTab('exceptions'); setShowMoreMobileMenu(false); }}
                  className="p-3 bg-slate-50 hover:bg-rose-50 border border-slate-200/80 rounded-xl text-left flex items-center justify-between text-slate-800 hover:text-rose-700 transition cursor-pointer"
                >
                  <div className="flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4 text-rose-600" />
                    <span>{lang === 'hi' ? 'समस्याएं' : 'Exceptions'}</span>
                  </div>
                  {exceptionsList.length > 0 && (
                    <span className="px-1.5 py-0.2 rounded-full text-[10px] font-bold bg-rose-500 text-white">
                      {exceptionsList.length}
                    </span>
                  )}
                </button>

                <button
                  onClick={() => { setActiveTab('cash_control'); setShowMoreMobileMenu(false); }}
                  className="p-3 bg-slate-50 hover:bg-emerald-50 border border-slate-200/80 rounded-xl text-left flex items-center gap-2 text-slate-800 hover:text-emerald-700 transition cursor-pointer"
                >
                  <CreditCard className="w-4 h-4 text-emerald-600" />
                  <span>{lang === 'hi' ? 'कैश कंट्रोल' : 'Cash Control'}</span>
                </button>

                <button
                  onClick={() => { setActiveTab('reports'); setShowMoreMobileMenu(false); }}
                  className="p-3 bg-slate-50 hover:bg-indigo-50 border border-slate-200/80 rounded-xl text-left flex items-center gap-2 text-slate-800 hover:text-indigo-700 transition cursor-pointer"
                >
                  <FileText className="w-4 h-4 text-indigo-600" />
                  <span>{lang === 'hi' ? 'रिपोर्ट्स' : 'Reports'}</span>
                </button>
              </div>

              {/* Utility Row */}
              <div className="pt-2 border-t border-slate-100 flex items-center justify-between gap-2">
                <button
                  onClick={() => { toggleLanguage(); }}
                  className="flex-1 flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-blue-50 text-blue-700 border border-blue-200 text-xs font-bold transition cursor-pointer min-h-[42px]"
                >
                  <Globe className="w-4 h-4" />
                  <span>{lang === 'en' ? 'हिन्दी में बदलें' : 'Switch to English'}</span>
                </button>

                <button
                  onClick={() => { loadAllData(); setShowMoreMobileMenu(false); }}
                  className="flex items-center justify-center p-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 transition cursor-pointer min-h-[42px] min-w-[42px]"
                  title="Refresh"
                >
                  <RefreshCw className="w-4 h-4" />
                </button>

                <button
                  onClick={() => { handleLogout(); }}
                  className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl bg-red-50 text-red-700 border border-red-200 text-xs font-bold transition cursor-pointer min-h-[42px]"
                >
                  <LogOut className="w-4 h-4" />
                  <span>{lang === 'hi' ? 'लॉगआउट' : 'Logout'}</span>
                </button>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* NATIVE APP STYLE FIXED BOTTOM NAVIGATION BAR (Mobile Only) */}
      <div className="md:hidden fixed bottom-0 inset-x-0 bg-white/95 backdrop-blur-xl border-t border-slate-200/90 z-40 px-2 py-1.5 flex items-center justify-around shadow-lg">
        <button
          onClick={() => setActiveTab('overview')}
          className={`flex flex-col items-center justify-center py-1 px-2 rounded-xl transition cursor-pointer min-w-[56px] ${
            activeTab === 'overview' || activeTab === 'control_room'
              ? 'text-blue-600 font-bold'
              : 'text-slate-500 hover:text-slate-800 font-medium'
          }`}
        >
          <Building className="w-5 h-5 mb-0.5" />
          <span className="text-[10px] leading-tight">{lang === 'hi' ? 'होम' : 'Overview'}</span>
        </button>

        <button
          onClick={() => setActiveTab('orders')}
          className={`relative flex flex-col items-center justify-center py-1 px-2 rounded-xl transition cursor-pointer min-w-[56px] ${
            activeTab === 'orders'
              ? 'text-blue-600 font-bold'
              : 'text-slate-500 hover:text-slate-800 font-medium'
          }`}
        >
          <div className="relative">
            <Package className="w-5 h-5 mb-0.5" />
            {orders.length > 0 && (
              <span className="absolute -top-1 -right-2 px-1 py-0.1 bg-blue-600 text-white text-[9px] font-extrabold rounded-full">
                {orders.length}
              </span>
            )}
          </div>
          <span className="text-[10px] leading-tight">{lang === 'hi' ? 'ऑर्डर्स' : 'Orders'}</span>
        </button>

        <button
          onClick={() => setActiveTab('products')}
          className={`flex flex-col items-center justify-center py-1 px-2 rounded-xl transition cursor-pointer min-w-[56px] ${
            activeTab === 'products'
              ? 'text-blue-600 font-bold'
              : 'text-slate-500 hover:text-slate-800 font-medium'
          }`}
        >
          <Truck className="w-5 h-5 mb-0.5" />
          <span className="text-[10px] leading-tight">{lang === 'hi' ? 'स्टॉक' : 'Stock'}</span>
        </button>

        <button
          onClick={() => setActiveTab('handovers')}
          className={`relative flex flex-col items-center justify-center py-1 px-2 rounded-xl transition cursor-pointer min-w-[56px] ${
            activeTab === 'handovers'
              ? 'text-blue-600 font-bold'
              : 'text-slate-500 hover:text-slate-800 font-medium'
          }`}
        >
          <div className="relative">
            <Wallet className="w-5 h-5 mb-0.5" />
            {handovers.filter(h => h.status === 'PENDING').length > 0 && (
              <span className="absolute -top-1 -right-2 px-1 py-0.1 bg-amber-500 text-white text-[9px] font-extrabold rounded-full">
                {handovers.filter(h => h.status === 'PENDING').length}
              </span>
            )}
          </div>
          <span className="text-[10px] leading-tight">{lang === 'hi' ? 'कैश' : 'Cash'}</span>
        </button>

        <button
          onClick={() => setActiveTab('retailers')}
          className={`flex flex-col items-center justify-center py-1 px-2 rounded-xl transition cursor-pointer min-w-[56px] ${
            activeTab === 'retailers'
              ? 'text-blue-600 font-bold'
              : 'text-slate-500 hover:text-slate-800 font-medium'
          }`}
        >
          <Store className="w-5 h-5 mb-0.5" />
          <span className="text-[10px] leading-tight">{lang === 'hi' ? 'दुकानें' : 'Shops'}</span>
        </button>

        <button
          onClick={() => setShowMoreMobileMenu(true)}
          className={`flex flex-col items-center justify-center py-1 px-2 rounded-xl transition cursor-pointer min-w-[56px] ${
            showMoreMobileMenu
              ? 'text-blue-600 font-bold'
              : 'text-slate-500 hover:text-slate-800 font-medium'
          }`}
        >
          <MoreHorizontal className="w-5 h-5 mb-0.5" />
          <span className="text-[10px] leading-tight">{lang === 'hi' ? 'अधिक' : 'More'}</span>
        </button>
      </div>
    </div>
  );
}
