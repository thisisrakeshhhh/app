export type CanonicalRole = 'WAREHOUSE' | 'SALES' | 'DELIVERY' | 'OWNER' | 'ADMIN';

export type PackagingUnit = 'BOX' | 'STRIP' | 'PCS';

export interface ProductItem {
  id: string;
  name: string;
  hindiName: string;
  category: string;
  mrpRupees: number;
  piecePricePaise: number;
  stripQty: number; // e.g. 12 pieces in 1 strip / ladi
  boxQty: number; // e.g. 96 pieces in 1 master box
  gstRate: number;
  godownStockBoxes: number;
  carStockBoxes: number;
  badge?: string;
  batchNumber: string;
  expiryDate: string; // YYYY-MM-DD
  reorderLevelBoxes: number;
}

export interface RetailerItem {
  id: string;
  name: string;
  ownerName: string;
  phone: string;
  address: string;
  beat: string;
  outstandingBalanceRupees: number;
  creditLimitRupees: number;
  lastVisitDate?: string;
  visitStatus?: 'PENDING' | 'VISITED' | 'ORDERED';
  lastOrderAmountRupees?: number;
  latitude?: number;
  longitude?: number;
}

export interface OrderLineItem {
  productId: string;
  productName: string;
  unit: PackagingUnit;
  quantity: number;
  boxEquivalent: number;
  unitPriceRupees: number;
  totalPriceRupees: number;
}

export type OrderStatus =
  | 'SUBMITTED'
  | 'APPROVED'
  | 'PICKING'
  | 'PACKED'
  | 'OUT_FOR_DELIVERY'
  | 'DELIVERED'
  | 'REJECTED';

export interface OrderItem {
  id: string;
  orderCode: string;
  retailerId: string;
  retailerName: string;
  retailerPhone: string;
  retailerAddress: string;
  status: OrderStatus;
  totalAmountRupees: number;
  items: OrderLineItem[];
  assignedTruckPlate?: string;
  deliveryOtp?: string;
  createdAt: string;
}

export interface InwardReceipt {
  id: string;
  challanNumber: string;
  truckPlate: string;
  supplierName: string;
  productId: string;
  productName: string;
  boxesReceived: number;
  batchNumber: string;
  expiryDate: string;
  timestamp: string;
}

export interface TruckFleet {
  plateNumber: string;
  driverName: string;
  model: string;
  capacityBoxes: number;
  loadedBoxes: number;
  stockMap: Record<string, number>; // productId -> boxes loaded
}

export interface CashHandoverItem {
  id: string;
  driverName: string;
  truckPlate: string;
  collectedRupees: number;
  submittedRupees: number;
  status: 'PENDING' | 'ACCEPTED' | 'REJECTED';
  timestamp: string;
}
